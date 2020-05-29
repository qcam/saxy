defmodule Saxy.PartialTest do
  use ExUnit.Case, async: true

  import SaxyTest.Utils

  alias Saxy.Partial

  alias SaxyTest.{
    ControlHandler,
    StackHandler
  }

  doctest Saxy.Partial

  test "parses XML document partially line by line" do
    data_chunks =
      "./test/support/fixture/food.xml"
      |> File.read!()
      |> remove_indents()
      |> String.split("\n")

    assert {:ok, partial} = Partial.new(StackHandler, [])

    partial =
      Enum.reduce(data_chunks, partial, fn data, acc ->
        assert {:cont, partial} = Partial.parse(acc, data)
        partial
      end)

    assert {:ok, _state} = Partial.terminate(partial)
  end

  test "parses XML document partially character by character" do
    data_chunks =
      "./test/support/fixture/food.xml"
      |> File.read!()
      |> remove_indents()
      |> String.split("")

    assert {:ok, partial} = Partial.new(StackHandler, [])

    partial =
      Enum.reduce(data_chunks, partial, fn data, acc ->
        assert {:cont, partial} = Partial.parse(acc, data)
        partial
      end)

    assert {:ok, state} = Partial.terminate(partial)
    assert length(state) == 74
  end

  test "supports parser stopping" do
    data = "<foo>foo</foo>"

    assert_parse_stop(data, :start_document)
    assert_parse_stop(data, :start_element)
    assert_parse_stop(data, :characters)
    assert_parse_stop(data, :end_element)
  end

  defp assert_parse_stop(data, stop_event) do
    ref = make_ref()

    assert {:ok, partial} = Partial.new(ControlHandler, {stop_event, {:stop, ref}})
    assert Partial.parse(partial, data) == {:halt, ref}
  end

  test "supports parser halting" do
    data = "<foo>foo</foo><bar></bar>"

    assert_parse_halt(data, :start_document, "<foo>foo</foo><bar></bar>")
    assert_parse_halt(data, :start_element, "foo</foo><bar></bar>")
    assert_parse_halt(data, :characters, "</foo><bar></bar>")
    assert_parse_halt(data, :end_element, "<bar></bar>")
  end

  defp assert_parse_halt(data, halt_event, rest) do
    value = make_ref()

    assert {:ok, partial} = Partial.new(ControlHandler, {halt_event, {:halt, value}})
    assert Partial.parse(partial, data) == {:halt, value, rest}
  end

  test "handles parsing errors" do
    assert {:ok, partial} = Partial.new(StackHandler, [])
    assert {:error, _reason} = Partial.parse(partial, "<foo<")
    assert {:error, _reason} = Partial.parse(partial, "<foo></bar>")
  end
end
