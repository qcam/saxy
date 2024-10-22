defmodule Saxy.PartialTest do
  use SaxyTest.ParsingCase, async: true

  alias Saxy.Partial

  alias SaxyTest.{
    ControlHandler,
    StackHandler
  }

  doctest Saxy.Partial

  @fixtures [
    "no-xml-decl.xml",
    "no-xml-decl-with-std-pi.xml",
    "no-xml-decl-with-custom-pi.xml",
    "foo.xml",
    "food.xml",
    "complex.xml",
    "illustrator.svg",
    "unicode.xml"
  ]

  test "parses partially and emits events" do
    chunks = [
      ~s(<?xml version="1.0"?>),
      "<foo>",
      "foo",
      "<!--COMMENT-->",
      "</foo>"
    ]

    assert {:ok, events} = parse_partial(chunks) |> Partial.terminate()

    events = Enum.reverse(events)

    assert events == [
             {:start_document, [version: "1.0"]},
             {:start_element, {"foo", []}},
             {:characters, "foo"},
             {:end_element, "foo"},
             {:end_document, {}}
           ]
  end

  test "fetch user state from a partial" do
    chunks = ["<foo>", "sdf</foo>", ""]
    partial = parse_partial(chunks)

    assert Partial.get_state(partial) == [
             {:end_element, "foo"},
             {:characters, "sdf"},
             {:start_element, {"foo", []}},
             {:start_document, []}
           ]
  end

  test "resets user state" do
    chunks = ["<some>c", "hun", "k</some>"]
    partial = parse_partial(chunks)
    {:cont, partial} = Partial.parse(partial, "", [:made_up_thing])
    {:ok, state} = Partial.terminate(partial)
    assert state == [{:end_document, {}}, :made_up_thing]
  end

  defp parse_partial(chunks) do
    assert {:ok, partial} = Partial.new(StackHandler, [])

    Enum.reduce(chunks, partial, fn chunk, acc ->
      assert {:cont, partial} = Partial.parse(acc, chunk)
      partial
    end)
  end

  test "parses XML document partially line by line" do
    for fixture <- @fixtures do
      data_chunks = stream_fixture(fixture)

      assert {:ok, _state} = parse_partial(data_chunks) |> Partial.terminate()
    end
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
