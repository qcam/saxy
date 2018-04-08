defmodule SaxyTest do
  use ExUnit.Case

  alias Saxy.{
    ParseError,
    HandlerError
  }

  alias Saxy.TestHandlers.{
    FastReturnHandler,
    WrongHandler,
    StackHandler
  }

  test "parse_string/3 parses a XML document binary" do
    data = File.read!("./test/support/fixture/food.xml")
    assert {:ok, _state} = Saxy.parse_string(data, StackHandler, [])
  end

  test "parse_string/4 parses XML binary with multiple \":expand_entity\" strategy" do
    data = """
    <?xml version="1.0" ?>
    <foo>Something &unknown;</foo>
    """

    assert {:ok, state} = Saxy.parse_string(data, StackHandler, [], expand_entity: :keep)

    assert state == [
      {:end_document, {}},
      {:end_element, "foo"},
      {:characters, "Something &unknown;"},
      {:start_element, {"foo", []}},
      {:start_document, [version: "1.0"]}
    ]

    assert {:ok, state} = Saxy.parse_string(data, StackHandler, [], expand_entity: :skip)

    assert state == [
      {:end_document, {}},
      {:end_element, "foo"},
      {:characters, "Something "},
      {:start_element, {"foo", []}},
      {:start_document, [version: "1.0"]}
    ]

    assert {:ok, state} = Saxy.parse_string(data, StackHandler, [], expand_entity: {__MODULE__, :convert_entity, []})

    assert state == [
      {:end_document, {}},
      {:end_element, "foo"},
      {:characters, "Something known"},
      {:start_element, {"foo", []}},
      {:start_document, [version: "1.0"]}
    ]
  end

  test "parse_stream/3 parses XML document stream" do
    stream = File.stream!("./test/support/fixture/food.xml", [], 1024)
    assert {:ok, _state} = Saxy.parse_stream(stream, StackHandler, [])
  end

  test "parse_stream/3 handles trailing unicode codepoints when buffering" do
    stream = File.stream!("./test/support/fixture/unicode.xml", [], 1)
    assert {:ok, state} = Saxy.parse_stream(stream, StackHandler, [])
    assert state == [
      {:end_document, {}},
      {:end_element, "songs"},
      {:end_element, "song"},
      {:characters, "Eva Braun 𠜎 𠜱 𠝹𠱓"},
      {:start_element, {"song", [{"singer", "Die Ärtze"}]}},
      {:end_element, "song"},
      {:characters, "Über den Wolken"},
      {:start_element, {"song", [{"singer", "Reinhard Mey"}]}},
      {:start_element, {"songs", []}},
      {:start_document, [version: "1.0"]}
    ]
  end

  test "returns parsing errors" do
    data = "<?xml ?><foo/>"

    assert {:error, exception} = Saxy.parse_string(data, StackHandler, [])
    assert ParseError.message(exception) == "unexpected byte \"?\", expected token: :version"

    data = "<?xml"

    assert {:error, exception} = Saxy.parse_string(data, StackHandler, [])

    assert ParseError.message(exception) ==
             "unexpected end of input, expected token: :version"

    data = "<foo><bar></bee></foo>"

    assert {:error, exception} = Saxy.parse_string(data, StackHandler, [])

    assert ParseError.message(exception) == "unexpected ending tag \"bee\", expected tag: \"bar\""
  end

  test "supports controling parsing flow" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    assert Saxy.parse_string(data, FastReturnHandler, []) == {:ok, :fast_return}
  end

  test "handles invalid return in handler" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    assert {:error, error} = Saxy.parse_string(data, WrongHandler, [])
    assert HandlerError.message(error) == "unexpected return :something_wrong in :start_document event handler"
  end

  def convert_entity("unknown"), do: "known"
end
