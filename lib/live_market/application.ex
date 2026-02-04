defmodule LiveMarket.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveMarketWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:live_market, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveMarket.PubSub},
      # Start a worker by calling: LiveMarket.Worker.start_link(arg)
      # {LiveMarket.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveMarketWeb.Endpoint,
      LiveMarket.FinnhubSocket
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveMarket.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveMarketWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
