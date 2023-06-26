defmodule Still.Printer.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    spidev = Keyword.get(opts, :spidev, "spidev0.0")

    children = [
      {Still.Printer, [spidev: spidev]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
