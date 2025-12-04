defmodule TttblastWeb.GameLive do
  use TttblastWeb, :live_view

  alias Tttblast.Game
  alias Tttblast.GameSupervisor

  def mount(%{"id" => game_id}, _session, socket) do
    # Generate a unique player ID for this session
    player_id = socket.id

    if connected?(socket) do
      # Subscribe to game updates
      Game.subscribe(game_id)

      # Ensure game exists and join it
      GameSupervisor.find_or_start_game(game_id)

      case Game.join(game_id, player_id, "Player") do
        {:ok, cell} ->
          game_state = Game.get_state(game_id)

          {:ok,
           assign(socket,
             page_title: "Game #{game_id}",
             game_id: game_id,
             player_id: player_id,
             player_cell: cell,
             selected_color: nil,
             game_state: game_state.state,
             cells: game_state.cells,
             players: game_state.players
           )}

        {:error, :game_full} ->
          {:ok,
           socket
           |> put_flash(:error, "Game is full!")
           |> redirect(to: ~p"/")}
      end
    else
      # Initial static render before WebSocket connects
      {:ok,
       assign(socket,
         page_title: "Game #{game_id}",
         game_id: game_id,
         player_id: nil,
         player_cell: nil,
         selected_color: nil,
         game_state: :connecting,
         cells: init_cells(),
         players: %{}
       )}
    end
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id] && socket.assigns[:game_id] do
      Game.leave(socket.assigns.game_id, socket.assigns.player_id)
    end
  end

  # Handle game state broadcasts from PubSub
  def handle_info({:game_state, state}, socket) do
    # Find current player's cell (may have changed if we rejoined)
    player_cell =
      case Map.get(state.players, socket.assigns.player_id) do
        nil -> socket.assigns.player_cell
        player -> player.cell
      end

    {:noreply,
     assign(socket,
       game_state: state.state,
       cells: state.cells,
       players: state.players,
       player_cell: player_cell
     )}
  end

  def handle_event("pick_color", %{"color" => color}, socket) do
    color_atom = String.to_existing_atom(color)
    player_cell = socket.assigns.player_cell

    # Update the player's cell locally for now (Phase 5 will move this to GenServer)
    cells =
      Enum.map(socket.assigns.cells, fn cell ->
        if cell.position == player_cell do
          %{cell | color: color_atom}
        else
          cell
        end
      end)

    {:noreply, assign(socket, selected_color: color_atom, cells: cells)}
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

      <div :if={@game_state != :connecting}>
        <!-- Player Position Indicator -->
        <div class="badge badge-primary badge-lg text-lg p-4 mb-4">
          You are Cell {@player_cell}
        </div>

        <!-- Player Count -->
        <div class="text-center mb-4 text-base-content/70">
          {map_size(@players)}/9 players
        </div>

        <!-- Game Board -->
        <div class="grid grid-cols-3 gap-2 mb-6">
          <%= for cell <- @cells do %>
            <.cell
              position={cell.position}
              color={cell.color}
              is_player_cell={cell.position == @player_cell}
              has_player={cell.player_id != nil}
            />
          <% end %>
        </div>

        <!-- Color Picker -->
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

        <!-- Status -->
        <div :if={@selected_color} class="text-center text-base-content/70 mt-4">
          You picked <span class={[
            "font-bold",
            @selected_color == :red && "text-error",
            @selected_color == :blue && "text-info"
          ]}>{String.upcase(to_string(@selected_color))}</span>
        </div>

        <!-- Game State Debug -->
        <div class="mt-6 text-sm text-base-content/50">
          State: {@game_state}
        </div>
      </div>
    </div>
    """
  end

  # Cell component
  attr :position, :integer, required: true
  attr :color, :atom, default: nil
  attr :is_player_cell, :boolean, default: false
  attr :has_player, :boolean, default: false

  defp cell(assigns) do
    ~H"""
    <div class={[
      "w-24 h-24 flex items-center justify-center text-2xl font-bold rounded-lg border-2 transition-all duration-200",
      cell_color_class(@color),
      @is_player_cell && @color == nil && "border-primary border-4 bg-primary/10",
      @is_player_cell && @color != nil && "border-4",
      !@is_player_cell && @color == nil && @has_player && "border-base-300 bg-base-100 border-dashed",
      !@is_player_cell && @color == nil && !@has_player && "border-base-300 bg-base-200 opacity-50"
    ]}>
      {@position}
    </div>
    """
  end

  defp cell_color_class(nil), do: ""
  defp cell_color_class(:red), do: "bg-error text-error-content border-error"
  defp cell_color_class(:blue), do: "bg-info text-info-content border-info"
end
