defmodule SaxyTest do
  use ExUnit.Case

  test "parse_string/3" do
    data = File.read!("./test/support/fixture/food.xml")
    {:ok, state} = Saxy.parse_string(data, &event_handler/3, [])

    state = Enum.reverse(state)
    prolog = [version: "1.0", encoding: "UTF-8", standalone: false]

    assert [{:start_document, ^prolog} | state] = state
    assert length(state) == 104
  end

  test "parse_stream/3" do
    stream = File.stream!("./test/support/fixture/food.xml", [], 1024)
    {:ok, state} = Saxy.parse_stream(stream, &event_handler/3, [])

    state = Enum.reverse(state)
    prolog = [version: "1.0", encoding: "UTF-8", standalone: false]

    assert [{:start_document, ^prolog} | state] = state
    assert length(state) == 104
  end

  test "parsing error" do
    data = "<?xml ?><foo/>"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])
    assert Saxy.ParsingError.message(exception) == "unexpected byte \"?\", expected: :XMLDecl"

    data = "<?xml"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])

    assert Saxy.ParsingError.message(exception) ==
             "unexpected byte at end of input, expected: :XMLDecl"

    data = "<foo><bar></bee></foo>"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])

    assert Saxy.ParsingError.message(exception) ==
             "unexpected closing tag \"bee\", expected: \"bar\""
  end

  defp event_handler(event_type, data, state) do
    [{event_type, data} | state]
  end
end
