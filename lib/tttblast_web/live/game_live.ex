defmodule TttblastWeb.GameLive do
  use TttblastWeb, :live_view

  alias Tttblast.Game
  alias Tttblast.GameSupervisor

  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      # Ensure game exists
      GameSupervisor.find_or_start_game(game_id)

      # Subscribe to game updates
      Game.subscribe(game_id)

      game_state = Game.get_state(game_id)

      {:ok,
       assign(socket,
         page_title: "Game #{game_id}",
         game_id: game_id,
         player_id: socket.id,
         player_name: nil,
         joined: false,
         player_cell: nil,
         selected_color: nil,
         game_state: game_state.state,
         center_player_id: game_state.center_player_id,
         cells: game_state.cells,
         players: game_state.players,
         countdown: game_state.countdown,
         round: game_state.round,
         round_result: game_state.round_result,
         winner: game_state.winner,
         completed_lines: game_state.completed_lines,
         chat_messages: game_state.chat_messages,
         chat_input: ""
       )}
    else
      # Initial static render before WebSocket connects
      {:ok,
       assign(socket,
         page_title: "Game #{game_id}",
         game_id: game_id,
         player_id: nil,
         player_name: nil,
         joined: false,
         player_cell: nil,
         selected_color: nil,
         game_state: :connecting,
         center_player_id: nil,
         cells: init_cells(),
         players: %{},
         countdown: nil,
         round: 0,
         round_result: nil,
         winner: nil,
         completed_lines: %{red: [], blue: []},
         chat_messages: [],
         chat_input: ""
       )}
    end
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id] && socket.assigns[:game_id] && socket.assigns[:joined] do
      Game.leave(socket.assigns.game_id, socket.assigns.player_id)
    end
  end

  # Handle game state broadcasts from PubSub
  def handle_info({:game_state, state}, socket) do
    # Find current player's data
    my_player = Map.get(state.players, socket.assigns.player_id)

    player_cell =
      case my_player do
        nil -> socket.assigns.player_cell
        player -> player.cell
      end

    # Sync selected_color from player's pick in game state
    selected_color =
      case my_player do
        nil -> socket.assigns.selected_color
        player -> player.pick
      end

    {:noreply,
     assign(socket,
       game_state: state.state,
       center_player_id: state.center_player_id,
       cells: state.cells,
       players: state.players,
       player_cell: player_cell,
       selected_color: selected_color,
       countdown: state.countdown,
       round: state.round,
       round_result: state.round_result,
       winner: state.winner,
       completed_lines: state.completed_lines,
       chat_messages: state.chat_messages
     )}
  end

  # Join the game with a name
  def handle_event("join", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, "Please enter your name")}
    else
      game_id = socket.assigns.game_id
      player_id = socket.assigns.player_id

      case Game.join(game_id, player_id, name) do
        {:ok, cell} ->
          {:noreply,
           assign(socket,
             player_name: name,
             joined: true,
             player_cell: cell
           )}

        {:error, :game_full} ->
          {:noreply,
           socket
           |> put_flash(:error, "Game is full!")
           |> redirect(to: ~p"/")}
      end
    end
  end

  def handle_event("toggle_ready", _params, socket) do
    Game.toggle_ready(socket.assigns.game_id, socket.assigns.player_id)
    {:noreply, socket}
  end

  def handle_event("start_with_bots", _params, socket) do
    Game.start_with_bots(socket.assigns.game_id)
    {:noreply, socket}
  end

  def handle_event("send_chat", %{"message" => message}, socket) do
    Game.send_chat(socket.assigns.game_id, socket.assigns.player_id, message)
    {:noreply, assign(socket, chat_input: "")}
  end

  def handle_event("update_chat_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, chat_input: message)}
  end

  def handle_event("pick_color", %{"color" => color}, socket) do
    color_atom = String.to_existing_atom(color)

    case Game.pick_color(socket.assigns.game_id, socket.assigns.player_id, color_atom) do
      :ok ->
        {:noreply, assign(socket, selected_color: color_atom)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("next_round", _params, socket) do
    Game.next_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  defp init_cells do
    for pos <- 1..9 do
      %{position: pos, player_id: nil, color: nil}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-[80vh] gap-6">
      <!-- Connection Status -->
      <div :if={@game_state == :connecting} class="text-center">
        <span class="loading loading-spinner loading-lg"></span>
        <p class="mt-2">Connecting to game...</p>
      </div>

      <!-- Join Form (before joining) -->
      <div :if={@game_state != :connecting && !@joined} class="card bg-base-200 shadow-xl p-8">
        <h2 class="text-2xl font-bold text-center mb-6">Join Game</h2>
        <form phx-submit="join" class="flex flex-col gap-4">
          <input
            type="text"
            name="name"
            placeholder="Enter your name"
            class="input input-bordered input-lg w-full"
            maxlength="20"
            autofocus
          />
          <button type="submit" class="btn btn-primary btn-lg">
            Join Game
          </button>
        </form>
        <div class="text-center mt-4 text-base-content/70">
          {map_size(@players)}/9 players in lobby
        </div>
      </div>

      <!-- Main Game UI (after joining) -->
      <div :if={@game_state != :connecting && @joined} class="w-full max-w-4xl">
        <!-- Lobby State -->
        <div :if={@game_state == :lobby} class="flex flex-col lg:flex-row gap-8 items-start justify-center">
          <!-- Player List -->
          <div class="card bg-base-200 shadow-xl p-6 w-full lg:w-80">
            <h3 class="text-xl font-bold mb-4 text-center">Lobby</h3>
            <div class="space-y-2">
              <%= for slot <- 1..9 do %>
                <.player_slot
                  slot={slot}
                  player={find_player_by_cell(@players, slot)}
                  is_you={find_player_by_cell(@players, slot) != nil &&
                         elem(find_player_by_cell(@players, slot), 0) == @player_id}
                />
              <% end %>
            </div>

            <!-- Ready Button -->
            <div class="mt-6">
              <% my_player = Map.get(@players, @player_id) %>
              <button
                phx-click="toggle_ready"
                class={[
                  "btn btn-lg w-full",
                  my_player && my_player.ready && "btn-success",
                  my_player && !my_player.ready && "btn-outline"
                ]}
              >
                {if my_player && my_player.ready, do: "READY!", else: "Click when Ready"}
              </button>
            </div>

            <!-- Ready Count -->
            <div class="text-center mt-4 text-base-content/70">
              {count_ready(@players)}/9 players ready
            </div>

            <!-- Start with Bots Button -->
            <div class="mt-4">
              <button
                phx-click="start_with_bots"
                class="btn btn-secondary btn-outline w-full"
              >
                Start with Bots
              </button>
              <div class="text-center mt-2 text-xs text-base-content/50">
                Fill empty slots with AI players
              </div>
            </div>
          </div>

          <!-- Board Preview -->
          <div class="flex flex-col items-center">
            <h3 class="text-xl font-bold mb-4">Your Position</h3>
            <div class="badge badge-primary badge-lg text-lg p-4 mb-4">
              You are Cell {@player_cell}
            </div>
            <div class="grid grid-cols-3 gap-2">
              <%= for cell <- @cells do %>
                <.cell
                  position={cell.position}
                  color={cell.color}
                  is_player_cell={cell.position == @player_cell}
                  has_player={cell.player_id != nil}
                  player_name={get_player_name(@players, cell.player_id)}
                />
              <% end %>
            </div>
          </div>
        </div>

        <!-- Game Playing States (center_pick, choosing, etc.) -->
        <div :if={@game_state != :lobby} class="flex flex-col items-center gap-6">
          <!-- Countdown Timer -->
          <div :if={@game_state == :countdown} class="text-center">
            <div class="text-8xl font-bold text-warning animate-pulse">
              {@countdown}
            </div>
          </div>

          <!-- Reveal Banner -->
          <div :if={@game_state == :reveal} class="text-center animate-bounce">
            <div class="text-6xl font-bold text-primary">
              REVEAL!
            </div>
          </div>

          <!-- Game State Banner -->
          <div :if={@game_state not in [:countdown, :reveal]} class={[
            "alert w-auto",
            @game_state == :center_pick && "alert-warning",
            @game_state == :choosing && "alert-info"
          ]}>
            <span class="text-lg font-bold">
              {game_state_message(@game_state, @center_player_id, @player_id, @players)}
            </span>
          </div>

          <!-- Player Position Indicator -->
          <div class="badge badge-primary badge-lg text-lg p-4">
            You are Cell {@player_cell}
          </div>

          <!-- Game Board -->
          <div class="grid grid-cols-3 gap-2 mb-6">
            <%= for cell <- @cells do %>
              <.cell
                position={cell.position}
                color={visible_color(cell, @game_state, @player_cell, @center_player_id, @players)}
                is_player_cell={cell.position == @player_cell}
                has_player={cell.player_id != nil}
                player_name={get_player_name(@players, cell.player_id)}
                is_revealed={@game_state == :reveal}
              />
            <% end %>
          </div>

          <!-- Color Picker (show in center_pick for center, choosing for others) -->
          <div :if={should_show_color_picker?(@game_state, @center_player_id, @player_id)}>
            <div class="flex gap-4">
              <button
                phx-click="pick_color"
                phx-value-color="red"
                class={[
                  "btn btn-lg min-w-24",
                  @selected_color == :red && "btn-error ring ring-error ring-offset-2",
                  @selected_color != :red && "btn-error btn-outline"
                ]}
              >
                RED
              </button>
              <button
                phx-click="pick_color"
                phx-value-color="blue"
                class={[
                  "btn btn-lg min-w-24",
                  @selected_color == :blue && "btn-info ring ring-info ring-offset-2",
                  @selected_color != :blue && "btn-info btn-outline"
                ]}
              >
                BLUE
              </button>
            </div>
          </div>

          <!-- Status -->
          <div :if={@selected_color && @game_state == :choosing} class="text-center text-base-content/70">
            You picked <span class={[
              "font-bold",
              @selected_color == :red && "text-error",
              @selected_color == :blue && "text-info"
            ]}>{String.upcase(to_string(@selected_color))}</span>
          </div>

          <!-- Pick count during choosing -->
          <div :if={@game_state == :choosing} class="text-center text-base-content/60">
            <% picks = count_picks(@players) %>
            {picks}/9 players have picked
            <span :if={picks == 9} class="text-success font-bold ml-2">All ready!</span>
          </div>

          <!-- Scoring Results -->
          <div :if={@game_state == :scoring && @round_result} class="w-full max-w-md">
            <!-- Winner Banner (if game over) -->
            <div :if={@winner} class="text-center mb-6">
              <div class="text-5xl font-bold text-warning animate-bounce mb-2">
                🎉 BLAST! 🎉
              </div>
              <div class="text-2xl font-bold text-primary">
                {get_player_name(@players, @winner)} WINS!
              </div>
            </div>

            <!-- Round Result Card -->
            <div class="card bg-base-200 shadow-xl p-6 mb-4">
              <h3 class="text-xl font-bold text-center mb-4">Round {@round} Results</h3>

              <!-- Line counts -->
              <div class="flex justify-center gap-8 mb-4">
                <div class="text-center">
                  <div class="text-3xl font-bold text-error">{@round_result.red_lines}</div>
                  <div class="text-sm text-base-content/70">Red Lines</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold text-base-content/50">vs</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold text-info">{@round_result.blue_lines}</div>
                  <div class="text-sm text-base-content/70">Blue Lines</div>
                </div>
              </div>

              <!-- Rule applied -->
              <div class="text-center mb-4">
                <div class={[
                  "badge badge-lg",
                  @round_result.winning_color == :red && "badge-error",
                  @round_result.winning_color == :blue && "badge-info",
                  @round_result.winning_color == nil && "badge-warning"
                ]}>
                  {rule_message(@round_result)}
                </div>
              </div>

              <!-- Pick distribution -->
              <div class="text-center text-sm text-base-content/60 mb-4">
                Red: {@round_result.red_picks} picks | Blue: {@round_result.blue_picks} picks
              </div>
            </div>

            <!-- Scoreboard -->
            <div class="card bg-base-200 shadow-xl p-6 mb-4">
              <h3 class="text-lg font-bold text-center mb-3">Scoreboard</h3>
              <div class="space-y-2">
                <%= for {_id, player} <- Enum.sort_by(@players, fn {_, p} -> -p.score end) do %>
                  <div class={[
                    "flex justify-between items-center p-2 rounded",
                    player.name == get_player_name(@players, @player_id) && "bg-primary/20",
                    Map.get(player, :is_bot) && "opacity-70"
                  ]}>
                    <div class="flex items-center gap-2">
                      <span :if={Map.get(player, :is_bot)} class="badge badge-ghost badge-xs">BOT</span>
                      <span class={[
                        "font-medium",
                        Map.get(player, :is_bot) && "italic"
                      ]}>{player.name}</span>
                      <span :if={player.streak >= 2} class="badge badge-warning badge-sm">
                        🔥 {player.streak}
                      </span>
                    </div>
                    <span class={[
                      "font-bold text-lg",
                      player.score > 0 && "text-success",
                      player.score < 0 && "text-error",
                      player.score == 0 && "text-base-content/70"
                    ]}>
                      {if player.score > 0, do: "+", else: ""}{player.score}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Next Round Button -->
            <div :if={!@winner} class="text-center">
              <button phx-click="next_round" class="btn btn-primary btn-lg">
                Next Round →
              </button>
            </div>
          </div>
        </div>

        <!-- Game State Debug -->
        <div class="mt-6 text-center text-sm text-base-content/50">
          State: {@game_state} | Round: {@round}
        </div>

        <!-- Chat -->
        <div class="mt-6 w-full max-w-md mx-auto">
          <div class="card bg-base-200 shadow-xl">
            <div class="card-body p-4">
              <h3 class="text-sm font-bold mb-2">Chat</h3>
              <!-- Messages -->
              <div class="h-32 overflow-y-auto bg-base-300 rounded p-2 mb-2 text-sm" id="chat-messages">
                <div :for={msg <- Enum.reverse(@chat_messages)} class="mb-1">
                  <span class="font-semibold">{msg.player_name}:</span>
                  <span class="text-base-content/80">{msg.message}</span>
                </div>
                <div :if={@chat_messages == []} class="text-base-content/50 italic">
                  No messages yet
                </div>
              </div>
              <!-- Input -->
              <form phx-submit="send_chat" class="flex gap-2">
                <input
                  type="text"
                  name="message"
                  value={@chat_input}
                  phx-change="update_chat_input"
                  placeholder="Type a message..."
                  class="input input-bordered input-sm flex-1"
                  maxlength="200"
                  autocomplete="off"
                />
                <button type="submit" class="btn btn-primary btn-sm">Send</button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Player slot component for lobby
  attr :slot, :integer, required: true
  attr :player, :any, default: nil
  attr :is_you, :boolean, default: false

  defp player_slot(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between p-3 rounded-lg",
      @player && "bg-base-100",
      !@player && "bg-base-300/50 border border-dashed border-base-300"
    ]}>
      <div class="flex items-center gap-2">
        <span class="badge badge-sm">{@slot}</span>
        <%= if @player do %>
          <% {_id, p} = @player %>
          <span :if={Map.get(p, :is_bot)} class="badge badge-ghost badge-xs">BOT</span>
          <span class={[
            "font-medium",
            @is_you && "text-primary",
            Map.get(p, :is_bot) && "text-base-content/60 italic"
          ]}>
            {p.name}{if @is_you, do: " (you)", else: ""}
          </span>
        <% else %>
          <span class="text-base-content/40 italic">Empty</span>
        <% end %>
      </div>
      <%= if @player do %>
        <% {_id, p} = @player %>
        <span :if={p.ready} class="badge badge-success badge-sm">Ready</span>
        <span :if={!p.ready} class="badge badge-ghost badge-sm">Waiting</span>
      <% end %>
    </div>
    """
  end

  # Cell component
  attr :position, :integer, required: true
  attr :color, :atom, default: nil
  attr :is_player_cell, :boolean, default: false
  attr :has_player, :boolean, default: false
  attr :player_name, :string, default: nil
  attr :is_revealed, :boolean, default: false

  defp cell(assigns) do
    ~H"""
    <div class={[
      "w-24 h-24 flex flex-col items-center justify-center text-2xl font-bold rounded-lg border-2 transition-all duration-300",
      cell_color_class(@color),
      @is_player_cell && @color == nil && "border-primary border-4 bg-primary/10",
      @is_player_cell && @color != nil && "border-4",
      !@is_player_cell && @color == nil && @has_player && "border-base-300 bg-base-100 border-dashed",
      !@is_player_cell && @color == nil && !@has_player && "border-base-300 bg-base-200 opacity-50",
      @is_revealed && @color != nil && "scale-110 shadow-lg"
    ]}>
      <span>{@position}</span>
      <span :if={@player_name} class="text-xs font-normal truncate max-w-20">{@player_name}</span>
    </div>
    """
  end

  defp cell_color_class(nil), do: ""
  defp cell_color_class(:red), do: "bg-error text-error-content border-error"
  defp cell_color_class(:blue), do: "bg-info text-info-content border-info"

  # Determine if a cell's color should be visible
  # - reveal/scoring state: show all colors
  # - countdown state: hide all colors (suspense!)
  # - choosing state: show only your cell and center player's cell
  # - center_pick state: show only center player's cell (public pick)
  defp visible_color(cell, game_state, player_cell, center_player_id, players) do
    cond do
      # Always show on reveal and scoring
      game_state in [:reveal, :scoring] ->
        cell.color

      # Hide all during countdown for suspense
      game_state == :countdown ->
        if cell.position == player_cell, do: cell.color, else: nil

      # During choosing, show your own cell and center's cell
      game_state == :choosing ->
        center_cell = get_player_cell(players, center_player_id)

        if cell.position == player_cell or cell.position == center_cell do
          cell.color
        else
          nil
        end

      # During center_pick, show only center's cell
      game_state == :center_pick ->
        center_cell = get_player_cell(players, center_player_id)
        if cell.position == center_cell, do: cell.color, else: nil

      # Default: show all (lobby, etc.)
      true ->
        cell.color
    end
  end

  defp get_player_cell(players, player_id) do
    case Map.get(players, player_id) do
      nil -> nil
      player -> player.cell
    end
  end

  # Helper functions
  defp find_player_by_cell(players, cell) do
    Enum.find(players, fn {_id, p} -> p.cell == cell end)
  end

  defp get_player_name(_players, nil), do: nil
  defp get_player_name(players, player_id) do
    case Map.get(players, player_id) do
      nil -> nil
      player -> player.name
    end
  end

  defp count_ready(players) do
    Enum.count(players, fn {_id, p} -> p.ready end)
  end

  defp count_picks(players) do
    Enum.count(players, fn {_id, p} -> p.pick != nil end)
  end

  defp game_state_message(:center_pick, center_player_id, player_id, players) do
    if center_player_id == player_id do
      "You are CENTER! Pick your color first."
    else
      center_name = get_player_name(players, center_player_id) || "Center player"
      "#{center_name} is picking first..."
    end
  end

  defp game_state_message(:choosing, _center_player_id, _player_id, _players) do
    "Pick your color secretly!"
  end

  defp game_state_message(:countdown, _center_player_id, _player_id, _players) do
    "Get ready for reveal..."
  end

  defp game_state_message(:reveal, _center_player_id, _player_id, _players) do
    "REVEAL!"
  end

  defp game_state_message(:scoring, _center_player_id, _player_id, _players) do
    "Round Complete!"
  end

  defp game_state_message(state, _center_player_id, _player_id, _players) do
    "Game: #{state}"
  end

  defp rule_message(%{is_sweep: true}) do
    "SWEEP! All scores reset!"
  end

  defp rule_message(%{rule_applied: :net_score, winning_color: color, net: net}) do
    color_name = String.upcase(to_string(color))
    "#{color_name} wins by #{abs(net)} line#{if abs(net) > 1, do: "s", else: ""}!"
  end

  defp rule_message(%{rule_applied: :minority, winning_color: color}) do
    color_name = String.upcase(to_string(color))
    "Tie! #{color_name} minority wins!"
  end

  defp rule_message(_), do: ""

  defp should_show_color_picker?(:center_pick, center_player_id, player_id) do
    center_player_id == player_id
  end

  defp should_show_color_picker?(:choosing, _center_player_id, _player_id) do
    true
  end

  defp should_show_color_picker?(_state, _center_player_id, _player_id) do
    false
  end
end
