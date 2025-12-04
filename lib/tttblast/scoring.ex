defmodule Tttblast.Scoring do
  @moduledoc """
  Scoring logic for TIC TAC TOE, BLAST!

  Lines (8 possible):
  - 3 rows: [1,2,3], [4,5,6], [7,8,9]
  - 3 cols: [1,4,7], [2,5,8], [3,6,9]
  - 2 diags: [1,5,9], [3,5,7]

  Scoring rules:
  1. Count complete lines per color
  2. Net = RedLines - BlueLines
  3. If net ≠ 0: winners +1 per net line, losers -1 each
  4. If net = 0: minority color +1, majority -1
  5. Full sweep (9-0): all scores reset except center keeps theirs

  Streak bonus: +1/+2/+3 for 2/3/4+ consecutive wins
  """

  @lines [
    # Rows
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
    # Columns
    [1, 4, 7],
    [2, 5, 8],
    [3, 6, 9],
    # Diagonals
    [1, 5, 9],
    [3, 5, 7]
  ]

  @doc """
  Count completed lines for each color.
  Returns {red_lines, blue_lines}
  """
  def count_lines(cells) do
    cell_map = Map.new(cells, fn c -> {c.position, c.color} end)

    Enum.reduce(@lines, {0, 0}, fn line, {red, blue} ->
      colors = Enum.map(line, &Map.get(cell_map, &1))

      cond do
        Enum.all?(colors, &(&1 == :red)) -> {red + 1, blue}
        Enum.all?(colors, &(&1 == :blue)) -> {red, blue + 1}
        true -> {red, blue}
      end
    end)
  end

  @doc """
  Count how many players picked each color.
  Returns {red_count, blue_count}
  """
  def count_picks(players) do
    Enum.reduce(players, {0, 0}, fn {_id, player}, {red, blue} ->
      case player.pick do
        :red -> {red + 1, blue}
        :blue -> {red, blue + 1}
        _ -> {red, blue}
      end
    end)
  end

  @doc """
  Calculate round results and return updated player scores.

  Returns:
  - {:normal, updated_players, round_result} for normal scoring
  - {:sweep, updated_players, round_result} for full sweep (9-0)

  round_result contains: %{
    red_lines: int,
    blue_lines: int,
    net: int,
    winning_color: :red | :blue | :tie,
    rule_applied: :net_score | :minority
  }
  """
  def calculate_round(players, cells, center_player_id) do
    {red_lines, blue_lines} = count_lines(cells)
    {red_picks, blue_picks} = count_picks(players)
    net = red_lines - blue_lines

    # Check for full sweep (all 9 one color)
    is_sweep = (red_picks == 9 and red_lines == 8) or (blue_picks == 9 and blue_lines == 8)

    round_result = %{
      red_lines: red_lines,
      blue_lines: blue_lines,
      red_picks: red_picks,
      blue_picks: blue_picks,
      net: net,
      is_sweep: is_sweep
    }

    cond do
      is_sweep ->
        # Full sweep: reset all scores except center
        updated_players =
          Enum.map(players, fn {id, player} ->
            if id == center_player_id do
              {id, player}
            else
              {id, %{player | score: 0, streak: 0}}
            end
          end)
          |> Map.new()

        result = Map.merge(round_result, %{winning_color: nil, rule_applied: :sweep})
        {:sweep, updated_players, result}

      net != 0 ->
        # Net score rule: winners get +1 per line difference, losers get -1
        winning_color = if net > 0, do: :red, else: :blue
        points_to_add = abs(net)

        updated_players = apply_net_scoring(players, winning_color, points_to_add)
        result = Map.merge(round_result, %{winning_color: winning_color, rule_applied: :net_score})
        {:normal, updated_players, result}

      true ->
        # Tie on lines: minority color wins
        {winning_color, _minority_count, _majority_count} =
          if red_picks < blue_picks do
            {:red, red_picks, blue_picks}
          else
            {:blue, blue_picks, red_picks}
          end

        updated_players = apply_minority_scoring(players, winning_color)
        result = Map.merge(round_result, %{winning_color: winning_color, rule_applied: :minority})
        {:normal, updated_players, result}
    end
  end

  defp apply_net_scoring(players, winning_color, points) do
    Enum.map(players, fn {id, player} ->
      if player.pick == winning_color do
        # Winner: +points per net line, update streak
        new_streak = player.streak + 1
        streak_bonus = streak_bonus(new_streak)
        {id, %{player | score: player.score + points + streak_bonus, streak: new_streak}}
      else
        # Loser: -1, reset streak
        {id, %{player | score: player.score - 1, streak: 0}}
      end
    end)
    |> Map.new()
  end

  defp apply_minority_scoring(players, winning_color) do
    Enum.map(players, fn {id, player} ->
      if player.pick == winning_color do
        # Minority winner: +1, update streak
        new_streak = player.streak + 1
        streak_bonus = streak_bonus(new_streak)
        {id, %{player | score: player.score + 1 + streak_bonus, streak: new_streak}}
      else
        # Majority loser: -1, reset streak
        {id, %{player | score: player.score - 1, streak: 0}}
      end
    end)
    |> Map.new()
  end

  @doc """
  Calculate streak bonus: +1/+2/+3 for 2/3/4+ consecutive wins
  """
  def streak_bonus(streak) when streak >= 4, do: 3
  def streak_bonus(3), do: 2
  def streak_bonus(2), do: 1
  def streak_bonus(_), do: 0

  @doc """
  Check BLAST win condition: first player with clear lead.
  Returns {:winner, player_id} or :no_winner
  """
  def check_blast_winner(players) do
    scores =
      players
      |> Enum.map(fn {id, p} -> {id, p.score} end)
      |> Enum.sort_by(fn {_id, score} -> score end, :desc)

    case scores do
      [{leader_id, leader_score}, {_second_id, second_score} | _rest]
      when leader_score > second_score and leader_score > 0 ->
        {:winner, leader_id}

      _ ->
        :no_winner
    end
  end

  @doc """
  Get the 8 possible winning lines (for UI highlighting).
  """
  def winning_lines, do: @lines

  @doc """
  Find which lines are complete for a given color.
  Returns list of line positions, e.g. [[1,2,3], [1,5,9]]
  """
  def completed_lines_for_color(cells, color) do
    cell_map = Map.new(cells, fn c -> {c.position, c.color} end)

    Enum.filter(@lines, fn line ->
      Enum.all?(line, fn pos -> Map.get(cell_map, pos) == color end)
    end)
  end
end
