defmodule Saxy.PartialTest do
  use ExUnit.Case, async: true

  alias Saxy.Partial

  alias Saxy.TestHandlers.{
    FastReturnHandler,
    StackHandler
  }

  test "parses XML document partially line by line" do
    data_chunks =
      "./test/support/fixture/food.xml"
      |> File.read!()
      |> String.split("\n")

    assert {:ok, partial} = Partial.new(StackHandler, [])

    partial =
      Enum.reduce(data_chunks, partial, fn data, acc ->
        assert {:cont, partial} = Partial.parse(data, acc)
        partial
      end)

    assert {:ok, state} = Partial.finish(partial)
    assert length(state) == 74
  end

  test "parses XML document partially character by character" do
    data_chunks =
      "./test/support/fixture/food.xml"
      |> File.read!()
      |> String.split("")

    assert {:ok, partial} = Partial.new(StackHandler, [])

    partial =
      Enum.reduce(data_chunks, partial, fn data, acc ->
        assert {:cont, partial} = Partial.parse(data, acc)
        partial
      end)

    assert {:ok, state} = Partial.finish(partial)
    assert length(state) == 74
  end

  test "works with fast return" do
    assert {:ok, partial} = Partial.new(FastReturnHandler, [])
    assert Partial.parse("<xml>", partial) == {:ok, :fast_return}
  end
end
