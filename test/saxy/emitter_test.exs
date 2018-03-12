defmodule Saxy.EmitterTest do
  use ExUnit.Case

  alias Saxy.Handler

  defmodule EventHandler do
    @behaviour Handler

    def handle_event(event, data, state) do
      {:ok, [{event, data} | state]}
    end
  end

  test "emit/3 with a module" do
    xml = """
    <?xml version="1.0" encoding="utf-8" standalone="no"?>
    <foo>First Foo<bar>First Bar</bar><bar>Second Bar</bar>Last Foo</foo>
    """

    assert {:ok, state} = Saxy.parse_string(xml, EventHandler, [])
    state = Enum.reverse(state)
    assert [{:start_document, prolog} | state] = state
    assert Keyword.fetch!(prolog, :version) == "1.0"
    assert Keyword.fetch!(prolog, :encoding) == "utf-8"
    assert Keyword.fetch!(prolog, :standalone) == false

    assert [{:start_element, {"foo", []}} | state] = state
    assert [{:characters, "First Foo"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "First Bar"} | state] = state
    assert [{:end_element, "bar"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "Second Bar"} | state] = state
    assert [{:end_element, "bar"} | state] = state
    assert [{:characters, "Last Foo"} | state] = state
    assert [{:end_element, "foo"} | state] = state
    assert [{:end_document, {}} | []] = state
  end

  test "emit/3 with a function" do
    xml = """
    <?xml version="1.0" encoding="utf-8" standalone="no"?>
    <foo>First Foo<bar>First Bar</bar><bar>Second Bar</bar>Last Foo</foo>
    """

    assert {:ok, state} = Saxy.parse_string(xml, &EventHandler.handle_event/3, [])
    state = Enum.reverse(state)

    assert [{:start_document, prolog} | state] = state
    assert Keyword.fetch!(prolog, :version) == "1.0"
    assert Keyword.fetch!(prolog, :encoding) == "utf-8"
    assert Keyword.fetch!(prolog, :standalone) == false

    assert [{:start_element, {"foo", []}} | state] = state
    assert [{:characters, "First Foo"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "First Bar"} | state] = state
    assert [{:end_element, "bar"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "Second Bar"} | state] = state
    assert [{:end_element, "bar"} | state] = state
    assert [{:characters, "Last Foo"} | state] = state
    assert [{:end_element, "foo"} | state] = state
    assert [{:end_document, {}} | []] = state
  end

  test "emit/3 handles user :stop message" do
    xml = """
    <?xml version="1.0" encoding="utf-8" standalone="no"?>
    <foo>First Foo</foo>
    """

    event_handler = fn :start_document, _data, _state -> {:stop, 1} end

    assert Saxy.parse_string(xml, event_handler, []) == {:ok, 1}
  end
end
