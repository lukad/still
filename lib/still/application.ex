defmodule Still.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Still.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: Still.Worker.start_link(arg)
        # {Still.Worker, arg},
        {Still.Printer.Supervisor, []},
        {Task.Supervisor, name: Still.Lpd.ClientSupervisor},
        {Still.Lpd.Server, port: 515}
        # {ThousandIsland,
        #  port: 515, handler_module: Still.Lpd.Handler, transport_options: [packet: :line]}
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Still.Worker.start_link(arg)
      # {Still.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Still.Worker.start_link(arg)
      # {Still.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:still, :target)
  end
end
