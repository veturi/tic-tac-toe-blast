defmodule TttblastWeb.GameLive do
  use TttblastWeb, :live_view

  def mount(%{"id" => game_id}, _session, socket) do
    # Hardcoded player cell for demo (will be assigned randomly in Phase 4)
    player_cell = 5

    # Initialize 9 cells with no colors
    cells =
      for pos <- 1..9 do
        %{position: pos, color: nil}
      end

    {:ok,
     assign(socket,
       page_title: "Game #{game_id}",
       game_id: game_id,
       player_cell: player_cell,
       selected_color: nil,
       cells: cells
     )}
  end

  def handle_event("pick_color", %{"color" => color}, socket) do
    color_atom = String.to_existing_atom(color)
    player_cell = socket.assigns.player_cell

    # Update the player's cell with the selected color
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

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-[80vh] gap-6">
      <!-- Player Position Indicator -->
      <div class="badge badge-primary badge-lg text-lg p-4">
        You are Cell #{@player_cell}
      </div>

      <!-- Game Board -->
      <div class="grid grid-cols-3 gap-2">
        <%= for cell <- @cells do %>
          <.cell
            position={cell.position}
            color={cell.color}
            is_player_cell={cell.position == @player_cell}
          />
        <% end %>
      </div>

      <!-- Color Picker -->
      <div class="flex gap-4 mt-4">
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
      <div :if={@selected_color} class="text-center text-base-content/70">
        You picked <span class={[
          "font-bold",
          @selected_color == :red && "text-error",
          @selected_color == :blue && "text-info"
        ]}>{String.upcase(to_string(@selected_color))}</span>
      </div>
    </div>
    """
  end

  # Cell component
  attr :position, :integer, required: true
  attr :color, :atom, default: nil
  attr :is_player_cell, :boolean, default: false

  defp cell(assigns) do
    ~H"""
    <div class={[
      "w-24 h-24 flex items-center justify-center text-2xl font-bold rounded-lg border-2 transition-all duration-200",
      cell_color_class(@color),
      @is_player_cell && @color == nil && "border-primary border-4 bg-primary/10",
      @is_player_cell && @color != nil && "border-4",
      !@is_player_cell && @color == nil && "border-base-300 bg-base-200"
    ]}>
      {@position}
    </div>
    """
  end

  defp cell_color_class(nil), do: ""
  defp cell_color_class(:red), do: "bg-error text-error-content border-error"
  defp cell_color_class(:blue), do: "bg-info text-info-content border-info"
end
