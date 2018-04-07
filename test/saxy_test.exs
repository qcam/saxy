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

  test "parse_string/3" do
    data = File.read!("./test/support/fixture/food.xml")
    assert {:ok, _state} = Saxy.parse_string(data, StackHandler, [])
  end

  test "parse_string/4 expanding entities" do
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

  test "parse_stream/3" do
    stream = File.stream!("./test/support/fixture/food.xml", [], 1024)
    assert {:ok, _state} = Saxy.parse_stream(stream, StackHandler, [])
  end

  test "parse_stream/3 with unicode" do
    stream = File.stream!("./test/support/fixture/unicode.xml", [], 1)
    assert {:ok, _state} = Saxy.parse_stream(stream, StackHandler, [])
  end

  test "parsing error" do
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

  test "handles user control flow" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    assert Saxy.parse_string(data, FastReturnHandler, []) == {:ok, :fast_return}
  end

  test "handles invalid handler return" do
    data = "<?xml version=\"1.0\" ?><foo/>"

    assert {:error, error} = Saxy.parse_string(data, WrongHandler, [])
    assert HandlerError.message(error) == "unexpected return :something_wrong in :start_document event handler"
  end

  def convert_entity("unknown"), do: "known"
end
