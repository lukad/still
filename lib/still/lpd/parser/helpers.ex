defmodule Still.Lpd.Parser.Helpers do
  import NimbleParsec

  def command_byte(c \\ empty(), byte) do
    c
    |> label(ignore(ascii_char([byte])), "command prefix #{byte}")
  end

  def space(c \\ empty()) do
    c
    |> label(ignore(ascii_char([32])), "space")
  end

  def job_number(c \\ empty()) do
    c
    |> label(integer(3), "3 digit job number")
  end

  def magic_string(c \\ empty(), string) do
    c
    |> label(ignore(string(string)), "magic string #{string}")
  end

  def lf(c \\ empty()) do
    c
    |> label(ignore(ascii_char([10])), "line feed")
  end
end
