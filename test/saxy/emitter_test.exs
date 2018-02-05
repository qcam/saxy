defmodule Saxy.EmitterTest do
  use ExUnit.Case

  alias Saxy.{Parser, Handler, State}

  defmodule EventHandler do
    @behaviour Handler

    def handle_event(event, data, state) do
      [{event, data} | state]
    end
  end

  test "emit/3 with a module" do
    xml = """
    <?xml version="1.0" encoding="utf8" standalone="no"?>
    <foo>First Foo<bar>First Bar</bar><bar>Second Bar</bar>Last Foo</foo>
    """

    state = %State{
      cont: :binary,
      user_state: [],
      prolog: [],
      handler: EventHandler
    }

    prolog = [version: "1.0", encoding: "utf8", standalone: false]

    assert {:ok, _, _, %State{user_state: state}} = Parser.match(xml, 0, :document, state)
    state = Enum.reverse(state)
    assert [{:start_document, ^prolog} | state] = state
    assert [{:start_element, {"foo", []}} | state] = state
    assert [{:characters, "First Foo"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "First Bar"} | state] = state
    assert [{:end_element, {"bar"}} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "Second Bar"} | state] = state
    assert [{:end_element, {"bar"}} | state] = state
    assert [{:characters, "Last Foo"} | state] = state
    assert [{:end_element, {"foo"}} | state] = state
    assert [{:end_document, {}} | []] = state
  end

  test "emit/3 with a function" do
    xml = """
    <?xml version="1.0" encoding="utf8" standalone="no"?>
    <foo>First Foo<bar>First Bar</bar><bar>Second Bar</bar>Last Foo</foo>
    """

    state = %State{
      cont: :binary,
      user_state: [],
      prolog: [],
      handler: &EventHandler.handle_event/3
    }

    prolog = [version: "1.0", encoding: "utf8", standalone: false]

    assert {:ok, _, _, %State{user_state: state}} = Parser.match(xml, 0, :document, state)
    state = Enum.reverse(state)
    assert [{:start_document, ^prolog} | state] = state
    assert [{:start_element, {"foo", []}} | state] = state
    assert [{:characters, "First Foo"} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "First Bar"} | state] = state
    assert [{:end_element, {"bar"}} | state] = state
    assert [{:start_element, {"bar", []}} | state] = state
    assert [{:characters, "Second Bar"} | state] = state
    assert [{:end_element, {"bar"}} | state] = state
    assert [{:characters, "Last Foo"} | state] = state
    assert [{:end_element, {"foo"}} | state] = state
    assert [{:end_document, {}} | []] = state
  end
end
