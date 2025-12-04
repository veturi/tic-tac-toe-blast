defmodule Tttblast.Game do
  @moduledoc """
  GenServer managing game state for TIC TAC TOE, BLAST!

  State machine: lobby → center_pick → choosing → countdown → reveal → scoring → (center_pick | game_over)
  """
  use GenServer

  alias Phoenix.PubSub

  @pubsub Tttblast.PubSub

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
      cells: init_cells()
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
            streak: 0
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
end
