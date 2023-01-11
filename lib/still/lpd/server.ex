defmodule Still.Lpd.Server do
  alias Still.Lpd.Parser
  require Logger

  use Task, restart: :permanent

  def start_link(args \\ []) do
    port = Keyword.get(args, :port, 515)
    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])
    Logger.info("LDP server listening on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Still.Lpd.ClientSupervisor, fn ->
        serve(client)
      end)

    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp serve(client) do
    {:ok, {addr, port}} = :inet.peername(client)
    addr = :inet_parse.ntoa(addr) |> to_string()
    session = Ulidex.generate()
    Logger.metadata(addr: addr, port: port, session: session)
    serve(client, {:init, %{}})
  end

  defp serve(client, state) do
    result =
      case :gen_tcp.recv(client, 0) do
        {:ok, data} -> handle_data(data, client, state)
        {:error, :closed} -> {:close, handle_close(client, state)}
      end

    case result do
      {:continue, state} -> serve(client, state)
      {:close, _state} -> nil
    end
  end

  defp handle_close(_client, state) do
    Logger.info("connection closed")
    state
  end

  defp handle_data(<<2, _rest::binary>> = _data, client, {:init, kek}) do
    Logger.debug("receive job")
    :ok = :gen_tcp.send(client, <<0>>)
    {:continue, {:receive, kek}}
  end

  defp handle_data(<<2, _rest::binary>> = data, client, {:receive, map}) do
    Logger.debug("receive control file")
    {:ok, [size, _, _], _, _, _, _} = Parser.receive_control(data)
    :ok = :gen_tcp.send(client, <<0>>)
    {:ok, control_file} = :gen_tcp.recv(client, size)
    control = parse_control(control_file)
    {:ok, <<0>>} = :gen_tcp.recv(client, 1)
    :ok = :gen_tcp.send(client, <<0>>)
    {:continue, {:receive, Map.put(map, :control, control)}}
  end

  defp handle_data(<<3, _rest::binary>> = data, client, {:receive, map}) do
    Logger.debug("receive data file")

    with {:ok, [size, _, _], _, _, _, _} <- Parser.receive_data(data),
         :ok <- :gen_tcp.send(client, <<0>>),
         {:ok, data_file} <- :gen_tcp.recv(client, size),
         {:ok, <<0>>} <- :gen_tcp.recv(client, 1),
         :ok <- :gen_tcp.send(client, <<0>>) do
      {:continue, {:receive, Map.put(map, :data, data_file)}}
    end
  end

  defp handle_data(<<command, _rest::binary>>, _client, state) do
    Logger.error("unknown command: #{command}")
    {:close, state}
  end

  @spec parse_control(binary()) :: map()
  defp parse_control(control) do
    control
    |> String.split(<<10>>)
    |> Enum.map(&parse_control_line/1)
    |> Enum.reject(&(&1 == nil))
    |> Map.new()
  end

  @spec parse_control_line(binary()) :: {atom(), binary()} | nil
  defp parse_control_line("H" <> host) do
    {:host, take_bytes(host, 31)}
  end

  defp parse_control_line("P" <> user) do
    {:user, take_bytes(user, 31)}
  end

  defp parse_control_line("J" <> job) do
    {:job, take_bytes(job, 99)}
  end

  defp parse_control_line("N" <> file_name) do
    {:file_name, take_bytes(file_name, 131)}
  end

  defp parse_control_line(_), do: nil

  @spec take_bytes(binary(), pos_integer()) :: binary()
  defp take_bytes(binary, bytes) do
    binary |> binary_part(0, min(byte_size(binary), bytes))
  end
end
