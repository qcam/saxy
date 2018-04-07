defmodule Saxy.EmitterTest do
  use ExUnit.Case

  alias Saxy.TestHandlers.{StackHandler, FastReturnHandler}

  describe "emit/3" do
    test "emits events" do
      xml = """
      <?xml version="1.0" encoding="utf-8" standalone="no"?>
      <foo>First Foo<bar>First Bar</bar><bar>Second Bar</bar>Last Foo</foo>
      """

      assert {:ok, state} = Saxy.parse_string(xml, StackHandler, [])
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

    test "controls parsing process and quick return" do
      xml = """
      <?xml version="1.0" encoding="utf-8" standalone="no"?>
      <foo>First Foo</foo>
      """

      assert Saxy.parse_string(xml, FastReturnHandler, []) == {:ok, :fast_return}
    end
  end
end
