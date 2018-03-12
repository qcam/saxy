defmodule SaxyTest do
  use ExUnit.Case

  alias Saxy.{
    ParseError,
    HandlerError
  }

  test "parse_string/3" do
    data = File.read!("./test/support/fixture/food.xml")
    assert {:ok, _state} = Saxy.parse_string(data, &event_handler/3, [])
  end

  test "parse_stream/3" do
    stream = File.stream!("./test/support/fixture/food.xml", [], 1024)
    assert {:ok, _state} = Saxy.parse_stream(stream, &event_handler/3, [])
  end

  test "parsing error" do
    data = "<?xml ?><foo/>"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])
    assert ParseError.message(exception) == "unexpected byte \"?\", expected token: :version"

    data = "<?xml"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])

    assert ParseError.message(exception) ==
             "unexpected end of input, expected token: :version"

    data = "<foo><bar></bee></foo>"

    assert {:error, exception} = Saxy.parse_string(data, &event_handler/3, [])

    assert ParseError.message(exception) == "unexpected ending tag \"bee\", expected tag: \"bar\""
  end

  test "handles user control flow" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    handler = fn :start_document, _event_data, _state ->
      {:stop, :stop_parsing}
    end

    assert Saxy.parse_string(data, handler, []) == {:ok, :stop_parsing}
  end

  test "handles invalid handler return" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    handler = fn :start_document, _event_data, _state ->
      :unexpected
    end

    assert {:error, error} = Saxy.parse_string(data, handler, [])
    assert HandlerError.message(error) == "unexpected return :unexpected in :start_document event handler"
  end

  defp event_handler(event_type, data, state) do
    {:ok, [{event_type, data} | state]}
  end
end
