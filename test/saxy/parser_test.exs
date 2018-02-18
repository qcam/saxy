defmodule Saxy.ParserTest do
  use ExUnit.Case

  test "streaming" do
    buffer = ""
    stream = File.stream!("./test/support/fixture/food.xml", [], 200)
    state = %Saxy.State{cont: stream, user_state: [], handler: &handler/3, prolog: []}

    assert {:ok, {:document, {}}, {_, 1119}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :document, state)

    assert length(state) == 105
  end

  test "document rule" do
    buffer = ~s(<?xml version="1.0" encoding='utf-8' standalone="yes" ?><foo/>)

    {:ok, {:document, {}}, {^buffer, 62}, %{user_state: state, prolog: prolog}} =
      Saxy.Parser.match(buffer, 0, :document, make_state())

    assert prolog == [version: "1.0", encoding: "utf-8", standalone: true]
    assert length(state) == 4

    buffer = File.read!("./test/support/fixture/food.xml")

    assert {:ok, {:document, {}}, {^buffer, 1119}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :document, make_state())

    assert length(state) == 105
  end

  test "prolog rule" do
    buffer = ~s(<?xml version="1.0" encoding='utf-8' standalone="yes" ?> bar)

    {:ok, {:prolog, prolog}, {^buffer, 57}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :prolog, make_state())

    assert prolog == [version: "1.0", encoding: "utf-8", standalone: true]
    assert state == []

    buffer = ~s(<?xml version="1.0" standalone="yes" ?>bar)

    {:ok, {:prolog, prolog}, {^buffer, 39}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :prolog, make_state())

    assert prolog == [version: "1.0", encoding: "UTF-8", standalone: true]
    assert state == []

    buffer = ~s(<?xml ?>)

    assert catch_throw(Saxy.Parser.match(buffer, 0, :prolog, make_state())) ==
             {:bad_syntax, {:XMLDecl, {buffer, 6}}}

    buffer = ""

    assert {:ok, {:prolog, []}, {^buffer, 0}, _state} =
             Saxy.Parser.match(buffer, 0, :prolog, make_state())
  end

  test "XMLDecl rule" do
    buffer = ~s(<?xml version="1.0" ?>bar)

    {:ok, {:XMLDecl, xml}, {^buffer, 22}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :XMLDecl, make_state())

    assert xml == [version: "1.0", encoding: "UTF-8", standalone: false]
    assert state == []

    buffer = ~s(<?xml version="1.0" encoding='utf-8'?>bar)

    {:ok, {:XMLDecl, xml}, {^buffer, 38}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :XMLDecl, make_state())

    assert xml == [version: "1.0", encoding: "utf-8", standalone: false]
    assert state == []

    buffer = ~s(<?xml version="1.0" encoding='utf-8' standalone="yes" ?>bar)

    {:ok, {:XMLDecl, xml}, {^buffer, 56}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :XMLDecl, make_state())

    assert xml == [version: "1.0", encoding: "utf-8", standalone: true]
    assert state == []
  end

  test "element rule for normal element" do
    buffer = "<foo></foo>bar"

    {:ok, {:element, element}, {^buffer, 11}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 2

    buffer = "<foo>John Cena</foo>bar"

    {:ok, {:element, element}, {^buffer, 20}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 3

    buffer = "<foo><bar></bar></foo>bar"

    {:ok, {:element, element}, {^buffer, 22}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 4

    buffer = "<foo><bar>John Cena</bar></foo>bar"

    {:ok, {:element, element}, {^buffer, 31}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 5

    buffer = "<foo><bar></bar><!--hello world--></foo>bar"

    {:ok, {:element, element}, {^buffer, 40}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 4

    buffer = "<foo><bar><!--hello world--></bar><!--hello world--></foo>bar"

    {:ok, {:element, element}, {^buffer, 58}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 4

    buffer = "<foo><![CDATA[Hello world]]></foo>bar"

    {:ok, {:element, element}, {^buffer, 34}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 3

    buffer = "<foo>Hello World &amp; people!</foo>bar"

    {:ok, {:element, element}, {^buffer, 36}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 5

    buffer = "<foo>Hello World &amp; people!</bar>"

    assert catch_throw(Saxy.Parser.match(buffer, 0, :element, make_state())) ==
             {:wrong_closing_tag, {"foo", "bar"}}

    assert element == {"foo", []}
    assert length(state) == 5
  end

  test "element rule for empty element" do
    buffer = "<foo />bar"

    {:ok, {:element, element}, {^buffer, 7}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 2

    buffer = "<foo/>bar"

    {:ok, {:element, element}, {^buffer, 6}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", []}
    assert length(state) == 2

    buffer = ~s(<foo bar1='123' bar-1='456' bar:1="789"/>bar)

    {:ok, {:element, element}, {^buffer, 41}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", [{"bar:1", "789"}, {"bar-1", "456"}, {"bar1", "123"}]}
    assert length(state) == 2
  end

  test "element attributes" do
    buffer = ~s(<foo bar1='123' bar-1='456' bar:1="789"/>bar)

    assert {:ok, {:element, element}, {^buffer, 41}, _state} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", [{"bar:1", "789"}, {"bar-1", "456"}, {"bar1", "123"}]}

    buffer = ~s(<foo bar1='foo &amp; bar' bar-1='456' bar:1="789"/>bar)

    assert {:ok, {:element, element}, {^buffer, 51}, _state} =
      Saxy.Parser.match(buffer, 0, :element, make_state())

    assert element == {"foo", [{"bar:1", "789"}, {"bar-1", "456"}, {"bar1", "foo &amp; bar"}]}
  end

  test "CDSect rule" do
    buffer = "<![CDATA[Hello world]]>bar"

    {:ok, {:CDSect, cdata}, {^buffer, 23}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :CDSect, make_state())

    assert cdata == "Hello world"
    assert state == []

    buffer = "<![CDATA[]]>bar"

    assert {:ok, {:CDSect, cdata}, {^buffer, 12}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :CDSect, make_state())

    assert cdata == ""
    assert state == []
  end

  test "Reference rule" do
    buffer = "&amp; bar"

    assert {:ok, {:Reference, ref}, {^buffer, 5}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :Reference, make_state())

    assert ref == "&amp;"
    assert state == []

    buffer = "&#999; bar"

    assert {:ok, {:Reference, ref}, {^buffer, 6}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :Reference, make_state())

    assert ref == "&#999;"
    assert state == []

    buffer = "&#xAAF980; bar"

    assert {:ok, {:Reference, ref}, {^buffer, 10}, %{user_state: state}} =
             Saxy.Parser.match(buffer, 0, :Reference, make_state())

    assert ref == "&#xAAF980;"
    assert state == []
  end

  test "Misc rule" do
    buffer = <<0x20, 0x9, "foo">>

    {:ok, {:Misc, values}, {^buffer, 2}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :Misc, make_state())

    assert values == []
    assert state == []

    buffer = "<!--XML rocks!-->foo"

    {:ok, {:Misc, values}, {^buffer, 17}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :Misc, make_state())

    assert values == []
    assert state == []

    buffer = "foo<!--XML rocks!-->foo"

    {:ok, {:Misc, values}, {^buffer, 20}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 3, :Misc, make_state())

    assert values == []
    assert state == []

    buffer = "foo<!--XML rocks!-->"

    {:error, :Misc, {^buffer, 2}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 2, :Misc, make_state())

    assert values == []
    assert state == []
  end

  test "S rule" do
    buffer = <<0x20, 0x9, "foo">>

    {:ok, {:S, values}, {^buffer, 2}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :S, make_state())

    assert values == [<<0x9>>, <<0x20>>]
    assert state == []
  end

  test "Comment rule" do
    buffer = "<!--XML rocks!-->foo"

    {:ok, {:Comment, comment}, {^buffer, 17}, %{user_state: state}} =
      Saxy.Parser.match(buffer, 0, :Comment, make_state())

    assert comment == "XML rocks!"
    assert state == []
  end

  defp make_state() do
    %Saxy.State{
      cont: :binary,
      prolog: [],
      user_state: [],
      handler: &handler/3
    }
  end

  defp handler(event_type, data, state) do
    [{event_type, data} | state]
  end
end
