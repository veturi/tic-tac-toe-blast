defmodule Tttblast.GameSupervisor do
  @moduledoc """
  DynamicSupervisor for managing Game GenServer processes.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Start a new game with the given ID.
  Returns {:ok, pid} if successful, or {:error, reason} if the game already exists.
  """
  def start_game(game_id) do
    spec = {Tttblast.Game, game_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Find or create a game with the given ID.
  Returns {:ok, pid} in both cases.
  """
  def find_or_start_game(game_id) do
    case start_game(game_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  @doc """
  Stop a game by its ID.
  """
  def stop_game(game_id) do
    case Registry.lookup(Tttblast.GameRegistry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
