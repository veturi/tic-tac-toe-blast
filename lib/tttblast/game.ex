defmodule Tttblast.Game do
  @moduledoc """
  GenServer managing game state for TIC TAC TOE, BLAST!

  State machine: lobby → center_pick → choosing → countdown → reveal → scoring → (center_pick | game_over)
  """
  use GenServer

  alias Phoenix.PubSub
  alias Tttblast.Scoring

  @pubsub Tttblast.PubSub
  @countdown_seconds 3
  @reveal_duration_ms 3000

  # --- Public API ---

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def join(game_id, player_id, name) do
    GenServer.call(via_tuple(game_id), {:join, player_id, name})
  end

  def leave(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:leave, player_id})
  end

  def toggle_ready(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:toggle_ready, player_id})
  end

  def pick_color(game_id, player_id, color) when color in [:red, :blue] do
    GenServer.call(via_tuple(game_id), {:pick_color, player_id, color})
  end

  def next_round(game_id) do
    GenServer.call(via_tuple(game_id), :next_round)
  end

  def start_with_bots(game_id) do
    GenServer.call(via_tuple(game_id), :start_with_bots)
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  def exists?(game_id) do
    case Registry.lookup(Tttblast.GameRegistry, game_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Tttblast.GameRegistry, game_id}}
  end

  # --- PubSub Helpers ---

  def subscribe(game_id) do
    PubSub.subscribe(@pubsub, topic(game_id))
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp broadcast(game_id, state) do
    PubSub.broadcast(@pubsub, topic(game_id), {:game_state, state})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(game_id) do
    state = %{
      id: game_id,
      state: :lobby,
      round: 0,
      players: %{},
      center_player_id: nil,
      cells: init_cells(),
      countdown: nil,
      round_result: nil,
      winner: nil,
      completed_lines: %{red: [], blue: []}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, player_id, name}, _from, state) do
    case add_player(state, player_id, name) do
      {:ok, cell, new_state} ->
        broadcast(state.id, new_state)
        {:reply, {:ok, cell}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    new_state = remove_player(state, player_id)
    broadcast(state.id, new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:toggle_ready, player_id}, _from, state) do
    case Map.get(state.players, player_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      player ->
        new_ready = not player.ready
        updated_player = %{player | ready: new_ready}
        new_players = Map.put(state.players, player_id, updated_player)
        new_state = %{state | players: new_players}

        # Check if all 9 players are ready to start
        new_state = maybe_start_game(new_state)

        broadcast(state.id, new_state)
        {:reply, {:ok, new_ready}, new_state}
    end
  end

  @impl true
  def handle_call({:pick_color, player_id, color}, _from, state) do
    case do_pick_color(state, player_id, color) do
      {:ok, new_state} ->
        broadcast(state.id, new_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:next_round, _from, %{state: :scoring, winner: nil} = state) do
    new_state = start_next_round(state)
    broadcast(state.id, new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:next_round, _from, state) do
    {:reply, {:error, :invalid_state}, state}
  end

  @impl true
  def handle_call(:start_with_bots, _from, %{state: :lobby} = state) do
    new_state = fill_with_bots_and_start(state)
    broadcast(state.id, new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:start_with_bots, _from, state) do
    {:reply, {:error, :not_in_lobby}, state}
  end

  # --- Private Helpers ---

  defp init_cells do
    for pos <- 1..9 do
      %{position: pos, player_id: nil, color: nil}
    end
  end

  defp add_player(state, player_id, name) do
    # Check if player already joined
    if Map.has_key?(state.players, player_id) do
      cell = state.players[player_id].cell
      {:ok, cell, state}
    else
      # Find available cell
      taken_cells = state.players |> Map.values() |> Enum.map(& &1.cell) |> MapSet.new()
      available_cells = Enum.reject(1..9, &MapSet.member?(taken_cells, &1))

      case available_cells do
        [] ->
          {:error, :game_full}

        cells ->
          cell = Enum.random(cells)

          player = %{
            name: name,
            cell: cell,
            pick: nil,
            score: 0,
            streak: 0,
            ready: false,
            is_bot: false
          }

          new_players = Map.put(state.players, player_id, player)

          # Update the cell to track which player owns it
          new_cells =
            Enum.map(state.cells, fn c ->
              if c.position == cell do
                %{c | player_id: player_id}
              else
                c
              end
            end)

          new_state = %{state | players: new_players, cells: new_cells}
          {:ok, cell, new_state}
      end
    end
  end

  defp remove_player(state, player_id) do
    case Map.get(state.players, player_id) do
      nil ->
        state

      player ->
        # Remove player and free up their cell
        new_players = Map.delete(state.players, player_id)

        new_cells =
          Enum.map(state.cells, fn c ->
            if c.position == player.cell do
              %{c | player_id: nil, color: nil}
            else
              c
            end
          end)

        %{state | players: new_players, cells: new_cells}
    end
  end

  defp maybe_start_game(%{state: :lobby, players: players} = state) do
    player_count = map_size(players)
    all_ready = Enum.all?(players, fn {_id, p} -> p.ready end)

    if player_count == 9 and all_ready do
      start_game(state)
    else
      state
    end
  end

  defp maybe_start_game(state), do: state

  defp fill_with_bots_and_start(state) do
    # Find available cells (not taken by human players)
    taken_cells = state.players |> Map.values() |> Enum.map(& &1.cell) |> MapSet.new()
    available_cells = Enum.reject(1..9, &MapSet.member?(taken_cells, &1))

    # Create bots for empty slots
    {new_players, new_cells, _} =
      Enum.reduce(available_cells, {state.players, state.cells, 1}, fn cell,
                                                                       {players, cells, bot_num} ->
        bot_id = "bot_#{:erlang.unique_integer([:positive])}"

        bot = %{
          name: "Bot #{bot_num}",
          cell: cell,
          pick: nil,
          score: 0,
          streak: 0,
          ready: true,
          is_bot: true
        }

        updated_players = Map.put(players, bot_id, bot)

        updated_cells =
          Enum.map(cells, fn c ->
            if c.position == cell, do: %{c | player_id: bot_id}, else: c
          end)

        {updated_players, updated_cells, bot_num + 1}
      end)

    # Mark all existing human players as ready
    ready_players =
      Enum.map(new_players, fn {id, player} ->
        {id, %{player | ready: true}}
      end)
      |> Map.new()

    # Start the game
    %{state | players: ready_players, cells: new_cells}
    |> start_game()
  end

  defp start_game(state) do
    # Pick random center player
    player_ids = Map.keys(state.players)
    center_player_id = Enum.random(player_ids)

    %{state | state: :center_pick, center_player_id: center_player_id, round: 1}
    |> trigger_bot_picks()
  end

  # Trigger bot picks based on game state
  defp trigger_bot_picks(%{state: :center_pick, center_player_id: center_id} = state) do
    center_player = Map.get(state.players, center_id)

    if center_player && center_player.is_bot do
      # Bot center picks random color
      color = Enum.random([:red, :blue])

      case do_pick_color(state, center_id, color) do
        {:ok, new_state} -> new_state
        {:error, _} -> state
      end
    else
      state
    end
  end

  defp trigger_bot_picks(%{state: :choosing, center_player_id: center_id} = state) do
    # All non-center bots pick
    bot_players =
      state.players
      |> Enum.filter(fn {id, p} -> p.is_bot && id != center_id && p.pick == nil end)

    Enum.reduce(bot_players, state, fn {bot_id, _bot}, acc_state ->
      color = Enum.random([:red, :blue])

      case do_pick_color(acc_state, bot_id, color) do
        {:ok, new_state} -> new_state
        {:error, _} -> acc_state
      end
    end)
  end

  defp trigger_bot_picks(state), do: state

  # Center player picks first (publicly) - then transition to choosing
  defp do_pick_color(%{state: :center_pick, center_player_id: center_id} = state, player_id, color)
       when player_id == center_id do
    new_state =
      state
      |> set_player_pick(player_id, color)
      |> Map.put(:state, :choosing)
      |> trigger_bot_picks()

    {:ok, new_state}
  end

  defp do_pick_color(%{state: :center_pick}, _player_id, _color) do
    {:error, :not_center_player}
  end

  # Non-center players pick secretly during choosing phase
  defp do_pick_color(%{state: :choosing, center_player_id: center_id} = state, player_id, color)
       when player_id != center_id do
    new_state =
      state
      |> set_player_pick(player_id, color)
      |> maybe_start_countdown()

    {:ok, new_state}
  end

  defp do_pick_color(%{state: :choosing}, _player_id, _color) do
    {:error, :center_cannot_pick_again}
  end

  defp do_pick_color(_state, _player_id, _color) do
    {:error, :invalid_state}
  end

  defp set_player_pick(state, player_id, color) do
    # Update player's pick
    player = Map.get(state.players, player_id)
    updated_player = %{player | pick: color}
    new_players = Map.put(state.players, player_id, updated_player)

    # Update cell's color
    new_cells =
      Enum.map(state.cells, fn cell ->
        if cell.player_id == player_id do
          %{cell | color: color}
        else
          cell
        end
      end)

    %{state | players: new_players, cells: new_cells}
  end

  # Check if all players have picked and start countdown
  defp maybe_start_countdown(%{state: :choosing} = state) do
    all_picked = Enum.all?(state.players, fn {_id, p} -> p.pick != nil end)

    if all_picked do
      start_countdown(state)
    else
      state
    end
  end

  defp maybe_start_countdown(state), do: state

  defp start_countdown(state) do
    Process.send_after(self(), :countdown_tick, 1000)
    %{state | state: :countdown, countdown: @countdown_seconds}
  end

  # --- Handle Info for Timer ---

  @impl true
  def handle_info(:countdown_tick, state) do
    new_countdown = state.countdown - 1

    new_state =
      if new_countdown <= 0 do
        # Countdown finished, reveal! Schedule scoring after reveal duration
        Process.send_after(self(), :calculate_scoring, @reveal_duration_ms)
        %{state | state: :reveal, countdown: 0}
      else
        # Continue countdown
        Process.send_after(self(), :countdown_tick, 1000)
        %{state | countdown: new_countdown}
      end

    broadcast(state.id, new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:calculate_scoring, %{state: :reveal} = state) do
    new_state = calculate_and_apply_scoring(state)
    broadcast(state.id, new_state)
    {:noreply, new_state}
  end

  def handle_info(:calculate_scoring, state) do
    {:noreply, state}
  end

  # --- Scoring Logic ---

  defp calculate_and_apply_scoring(state) do
    {result_type, updated_players, round_result} =
      Scoring.calculate_round(state.players, state.cells, state.center_player_id)

    # Get completed lines for highlighting
    red_lines = Scoring.completed_lines_for_color(state.cells, :red)
    blue_lines = Scoring.completed_lines_for_color(state.cells, :blue)

    # Check for BLAST winner
    winner =
      case Scoring.check_blast_winner(updated_players) do
        {:winner, player_id} -> player_id
        :no_winner -> nil
      end

    new_state =
      if result_type == :sweep do
        # On sweep, we still go to scoring but with sweep indicator
        %{state |
          state: :scoring,
          players: updated_players,
          round_result: round_result,
          winner: winner,
          completed_lines: %{red: red_lines, blue: blue_lines}
        }
      else
        %{state |
          state: :scoring,
          players: updated_players,
          round_result: round_result,
          winner: winner,
          completed_lines: %{red: red_lines, blue: blue_lines}
        }
      end

    new_state
  end

  defp start_next_round(state) do
    # Pick new random center player (different from last round if possible)
    player_ids = Map.keys(state.players)
    other_players = Enum.reject(player_ids, &(&1 == state.center_player_id))
    new_center = if other_players == [], do: hd(player_ids), else: Enum.random(other_players)

    # Reset picks and cells for new round
    reset_players =
      Enum.map(state.players, fn {id, player} ->
        {id, %{player | pick: nil}}
      end)
      |> Map.new()

    reset_cells =
      Enum.map(state.cells, fn cell ->
        %{cell | color: nil}
      end)

    %{state |
      state: :center_pick,
      round: state.round + 1,
      center_player_id: new_center,
      players: reset_players,
      cells: reset_cells,
      round_result: nil,
      completed_lines: %{red: [], blue: []}
    }
    |> trigger_bot_picks()
  end
end
