defmodule Geomextric.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DNSCluster, query: Application.get_env(:geomextric, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Geomextric.PubSub}
      # Start a worker by calling: Geomextric.Worker.start_link(arg)
      # {Geomextric.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Geomextric.Supervisor)
  end
end
