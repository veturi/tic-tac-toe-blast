defmodule Tttblast.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TttblastWeb.Telemetry,
      Tttblast.Repo,
      {DNSCluster, query: Application.get_env(:tttblast, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tttblast.PubSub},
      # Game process registry and supervisor
      {Registry, keys: :unique, name: Tttblast.GameRegistry},
      Tttblast.GameSupervisor,
      # Start to serve requests, typically the last entry
      TttblastWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tttblast.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TttblastWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
