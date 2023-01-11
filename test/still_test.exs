defmodule StillTest do
  use ExUnit.Case
  doctest Still

  test "greets the world" do
    assert Still.hello() == :world
  end
end
