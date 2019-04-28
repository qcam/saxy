defmodule Saxy.Parser.PartialTest do
  use ExUnit.Case, async: true

  alias Saxy.Parser.Partial

  alias Saxy.TestHandlers.StackHandler

  test "The Partial module is used to parse an XML document binary, line by line" do
    data =
      File.read!("./test/support/fixture/food.xml")
      |> String.split("\n")

    assert {:ok, state_fun} = Partial.init(StackHandler, [])
    fun = Enum.reduce(data,
      state_fun,
      fn(data, fun) -> elem(Partial.parse(data, fun), 1) end)
    assert {:ok, state} = Partial.finish(fun)
    assert length(state) == 74
  end
end
