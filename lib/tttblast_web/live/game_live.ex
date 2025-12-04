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
         players: game_state.players
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
         players: %{}
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
       selected_color: selected_color
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

  def handle_event("pick_color", %{"color" => color}, socket) do
    color_atom = String.to_existing_atom(color)

    case Game.pick_color(socket.assigns.game_id, socket.assigns.player_id, color_atom) do
      :ok ->
        {:noreply, assign(socket, selected_color: color_atom)}

      {:error, _reason} ->
        {:noreply, socket}
    end
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
          <!-- Game State Banner -->
          <div class={[
            "alert w-auto",
            @game_state == :center_pick && "alert-warning",
            @game_state not in [:lobby, :center_pick] && "alert-info"
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
                color={cell.color}
                is_player_cell={cell.position == @player_cell}
                has_player={cell.player_id != nil}
                player_name={get_player_name(@players, cell.player_id)}
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
          <div :if={@selected_color} class="text-center text-base-content/70">
            You picked <span class={[
              "font-bold",
              @selected_color == :red && "text-error",
              @selected_color == :blue && "text-info"
            ]}>{String.upcase(to_string(@selected_color))}</span>
          </div>
        </div>

        <!-- Game State Debug -->
        <div class="mt-6 text-center text-sm text-base-content/50">
          State: {@game_state} | Round: {Map.get(assigns, :round, 0)}
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
          <span class={["font-medium", @is_you && "text-primary"]}>
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

  defp cell(assigns) do
    ~H"""
    <div class={[
      "w-24 h-24 flex flex-col items-center justify-center text-2xl font-bold rounded-lg border-2 transition-all duration-200",
      cell_color_class(@color),
      @is_player_cell && @color == nil && "border-primary border-4 bg-primary/10",
      @is_player_cell && @color != nil && "border-4",
      !@is_player_cell && @color == nil && @has_player && "border-base-300 bg-base-100 border-dashed",
      !@is_player_cell && @color == nil && !@has_player && "border-base-300 bg-base-200 opacity-50"
    ]}>
      <span>{@position}</span>
      <span :if={@player_name} class="text-xs font-normal truncate max-w-20">{@player_name}</span>
    </div>
    """
  end

  defp cell_color_class(nil), do: ""
  defp cell_color_class(:red), do: "bg-error text-error-content border-error"
  defp cell_color_class(:blue), do: "bg-info text-info-content border-info"

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
    "Calculating scores..."
  end

  defp game_state_message(state, _center_player_id, _player_id, _players) do
    "Game: #{state}"
  end

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
