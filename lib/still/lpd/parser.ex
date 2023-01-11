defmodule Still.Lpd.Parser do
  import NimbleParsec
  import Still.Lpd.Parser.Helpers

  hostname = ignore(string("H")) |> ascii_string([{:not, 10}], max: 31) |> lf()
  user = ignore(string("P")) |> ascii_string([{:not, 10}], max: 31) |> lf()
  job_name = ignore(string("J")) |> ascii_string([{:not, 10}], max: 99) |> lf()

  defparsec(
    :receive_command,
    command_byte(2)
    |> label(choice([ascii_string([{:not, 10}], min: 1), empty() |> replace(nil)]), "queue")
    |> lf()
    |> eos()
  )

  defparsec(
    :receive_control,
    command_byte(2)
    |> integer(min: 1)
    |> space()
    |> magic_string("cfA")
    |> job_number()
    |> ascii_string([{:not, 10}], min: 1)
    |> lf()
    |> eos()
  )

  defparsec(
    :receive_data,
    command_byte(3)
    |> integer(min: 1)
    |> space()
    |> magic_string("dfA")
    |> job_number()
    |> ascii_string([{:not, 10}], min: 1)
    |> lf()
    |> eos()
  )

  defparsec(:control_file, repeat(choice([hostname, user, job_name])) |> lf() |> eos())
end
