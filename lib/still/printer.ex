defmodule Still.Printer do
  use GenServer

  alias Still.Printer.Status
  alias Circuits.SPI

  defmodule State do
    @enforce_keys [:spi, :status]
    defstruct [:spi, :status]

    @type t :: %__MODULE__{
            spi: SPI.spi_bus(),
            status: Status.t() | nil
          }
  end

  @magic <<0x88, 0x33>>
  @max_data_length div(160 * 16, 4)

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    spidev = Keyword.fetch!(opts, :spidev)
    speed_hz = Keyword.get(opts, :speed_hz, 8192)
    delay_us = Keyword.get(opts, :delay_us, 120)
    {:ok, spi} = SPI.open(spidev, speed_hz: speed_hz, mode: 3, delay_us: delay_us)
    Logger.metadata(spidev: spidev)
    Logger.info("SPI bus opened")
    :timer.apply_after(0, __MODULE__, :initialize, [])
    {:ok, %State{spi: spi, status: nil}}
  end

  ## API

  def initialize do
    GenServer.call(__MODULE__, :initialize)
  end

  def read_status do
    GenServer.call(__MODULE__, :read_status)
  end

  def send_data(data) do
    GenServer.call(__MODULE__, {:send_data, data}, 60_000)
  end

  def print(margin \\ 0xFF) do
    GenServer.call(__MODULE__, {:print, margin})
  end

  ## Callbacks

  def handle_call(:initialize, _from, %State{} = state) do
    with {:ok, response} <- SPI.transfer(state.spi, message(:initialize)),
         <<_::binary-size(9), alive, status>> = response,
         %Status{online: true} = status <- Status.parse(alive, status) do
      {:reply, {:ok, status}, state}
    else
      response ->
        Logger.error(inspect(response))
        {:reply, {:err, :not_ready}, state}
    end
  end

  def handle_call(:read_status, _from, %State{} = state) do
    msg = message(:read_status)
    {:ok, response} = SPI.transfer(state.spi, msg)
    <<_::binary-size(byte_size(response) - 2), alive_byte, status_byte>> = response
    status = Status.parse(alive_byte, status_byte)
    {:reply, status, state}
  end

  def handle_call({:send_data, data}, _from, %State{} = state) do
    data
    |> :binary.bin_to_list()
    |> Enum.chunk_every(@max_data_length)
    |> Enum.map(&:binary.list_to_bin/1)
    |> Enum.each(fn chunk ->
      msg = message(:data, chunk)
      {:ok, response} = SPI.transfer(state.spi, msg)
      Logger.info("Fill buffer response: #{inspect(response |> Status.from_response())}")
    end)

    {:ok, response} = SPI.transfer(state.spi, message(:data, <<>>))
    Logger.info("Fill buffer response: #{inspect(response |> Status.from_response())}")

    {:reply, :ok, state}
  end

  def handle_call({:print, margin}, _from, %State{} = state) do
    {:ok, response} = SPI.transfer(state.spi, message(:print, <<0x01, margin, 0xE4, 0x40>>))
    Logger.error("Print response: #{inspect(response)}")
    {:reply, :ok, state}
  end

  @type command() :: :initialize | :data | :print | :read_status

  @spec message(command(), binary()) :: binary()
  defp message(command, data \\ <<0x00>>) do
    command =
      case command do
        :initialize -> <<0x01>>
        :print -> <<0x02>>
        :data -> <<0x04>>
        :read_status -> <<0x0F>>
      end

    header = <<command::binary, 0x00, byte_size(data)::16-little>>
    checksum = <<byte_sum(header <> data)::16-little>>

    @magic <> header <> data <> checksum <> <<0x00, 0x00>>
  end

  def byte_sum(data) do
    data |> :binary.bin_to_list() |> Enum.sum()
  end
end
