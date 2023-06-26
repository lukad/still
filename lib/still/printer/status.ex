defmodule Still.Printer.Status do
  import Bitwise

  @keys [
    :online,
    :checksum_error,
    :printing,
    :image_data_full,
    :unprocessed_data,
    :packet_error,
    :paper_jam,
    :other_error,
    :low_battery
  ]
  @enforce_keys @keys
  defstruct @keys

  @type t :: %__MODULE__{
          checksum_error: boolean(),
          printing: boolean(),
          image_data_full: boolean(),
          unprocessed_data: boolean(),
          packet_error: boolean(),
          paper_jam: boolean(),
          other_error: boolean(),
          low_battery: boolean()
        }

  @checksum_error 1 <<< 0
  @printing 1 <<< 1
  @image_data_full 1 <<< 2
  @unprocessed_data 1 <<< 3
  @packet_error 1 <<< 4
  @paper_jam 1 <<< 5
  @other_error 1 <<< 6
  @low_battery 1 <<< 7

  @spec parse(byte(), byte()) :: t()
  def parse(0x81, status) do
    %__MODULE__{
      online: true,
      checksum_error: band(status, @checksum_error) != 0,
      printing: band(status, @printing) != 0,
      image_data_full: band(status, @image_data_full) != 0,
      unprocessed_data: band(status, @unprocessed_data) != 0,
      packet_error: band(status, @packet_error) != 0,
      paper_jam: band(status, @paper_jam) != 0,
      other_error: band(status, @other_error) != 0,
      low_battery: band(status, @low_battery) != 0
    }
  end

  def parse(_alive, _status) do
    %__MODULE__{
      online: false,
      checksum_error: false,
      printing: false,
      image_data_full: false,
      unprocessed_data: false,
      packet_error: false,
      paper_jam: false,
      other_error: false,
      low_battery: false
    }
  end

  def from_response(response) when is_binary(response) do
    <<_::binary-size(byte_size(response) - 2), alive, status>> = response
    parse(alive, status)
  end
end
