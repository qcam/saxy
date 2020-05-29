defmodule Saxy.EmitterTest do
  use ExUnit.Case, async: true

  alias SaxyTest.ControlHandler

  @events [
    :start_document,
    :start_element,
    :characters,
    :end_element,
    :end_document
  ]

  for event <- @events do
    test "allows stopping the parsing process on #{inspect(event)}" do
      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      assert_parse_stop(data, unquote(event))
    end
  end

  defp assert_parse_stop(data, stop_event) do
    value = make_ref()
    state = {stop_event, {:stop, value}}

    assert parse(data, ControlHandler, state) == {:ok, value}
  end

  describe "parser halting" do
    test "halts the parsing process and returns the rest of the binary" do
      data = "<?xml version=\"1.0\" ?><foo/>"
      assert parse_halt(data, :start_document) == "<foo/>"
      assert parse_halt(data, :start_element) == ""
      assert parse_halt(data, :end_element) == ""
      assert parse_halt(data, :end_document) == ""

      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      assert parse_halt(data, :start_element) == "foo</foo>"
      assert parse_halt(data, :characters) == "</foo>"
      assert parse_halt(data, :end_element) == ""

      data = "<?xml version=\"1.0\" ?><foo>foo <bar/></foo>"
      assert parse_halt(data, {:start_element, {"foo", []}}) == "foo <bar/></foo>"
      assert parse_halt(data, {:characters, "foo "}) == "<bar/></foo>"
      assert parse_halt(data, {:start_element, {"bar", []}}) == "</foo>"
      assert parse_halt(data, {:end_element, "bar"}) == "</foo>"
      assert parse_halt(data, {:end_element, "foo"}) == ""
      assert parse_halt(data <> "trailing", {:end_element, "foo"}) == "trailing"

      data = "<?xml version=\"1.0\" ?><foo><![CDATA[foo]]></foo>"
      assert parse_halt(data, {:characters, "foo"}) == "</foo>"
    end
  end

  defp parse_halt(data, halt_event) do
    value = make_ref()
    state = {halt_event, {:halt, value}}

    assert {:halt, ^value, rest} = parse(data, ControlHandler, state)

    rest
  end

  for event <- @events do
    test "errs on handler invalid returning on #{event}" do
      event = unquote(event)
      data = "<?xml version=\"1.0\" ?><foo>foo</foo>"
      value = System.unique_integer()

      assert {:error, error} = parse(data, ControlHandler, {event, value})
      assert Exception.message(error) == "unexpected return #{value} in #{inspect(event)} event handler"
    end
  end

  defp parse(data, handler, state) do
    assert result = Saxy.parse_string(data, handler, state)
    assert Saxy.parse_stream([data], handler, state) == result

    result
  end
end
