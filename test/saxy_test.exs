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

  doctest Saxy

  test "parse_string/3 parses a XML document binary" do
    data = File.read!("./test/support/fixture/food.xml")
    assert {:ok, state} = Saxy.parse_string(data, StackHandler, [])
    assert length(state) == 74

    data = File.read!("./test/support/fixture/complex.xml")
    assert {:ok, state} = Saxy.parse_string(data, StackHandler, [])
    assert length(state) == 79
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

  test "parse_stream/3 parses file stream" do
    stream = File.stream!("./test/support/fixture/food.xml", [], 1024)
    assert {:ok, _state} = Saxy.parse_stream(stream, StackHandler, [])

    stream = File.stream!("./test/support/fixture/food.xml", [], 200)
    assert {:ok, state} = Saxy.parse_stream(stream, StackHandler, [])

    assert length(state) == 74

    stream = File.stream!("./test/support/fixture/complex.xml", [], 200)
    assert {:ok, state} = Saxy.parse_stream(stream, StackHandler, [])

    assert length(state) == 79
  end

  test "parse_stream/3 parses normal stream" do
    stream =
      """
      <?xml version='1.0' encoding="UTF-8" ?>
      <item name="[日本語] Tom &amp; Jerry" category='movie'>
        <author name='William Hanna &#x26; Joseph Barbera' />
        <!--Ignore me please I am just a comment-->
        <?foo Hmm? Then probably ignore me too?>
        <description><![CDATA[<strong>"Tom & Jerry" is a cool movie!</strong>]]></description>
        <actors>
          <actor>Tom</actor>
          <actor>Jerry</actor>
        </actors>
      </item>
      <!--a very bottom comment-->
      <?foo what a instruction ?>
      """
      |> String.codepoints()
      |> Stream.map(&(&1))

    assert {:ok, state} = Saxy.parse_stream(stream, StackHandler, [])
    events = Enum.reverse(state)

    assert [{:start_document, [encoding: "UTF-8", version: "1.0"]} | events] = events

    item_attributes = [{"category", "movie"}, {"name", "[日本語] Tom & Jerry"}]
    assert [{:start_element, {"item", ^item_attributes}} | events] = events

    author_attributes = [{"name", "William Hanna & Joseph Barbera"}]
    assert [{:start_element, {"author", ^author_attributes}} | events] = events
    assert [{:end_element, "author"} | events] = events

    assert [{:start_element, {"description", []}} | events] = events
    assert [{:characters, "<strong>\"Tom & Jerry\" is a cool movie!</strong>"} | events] = events
    assert [{:end_element, "description"} | events] = events

    assert [{:start_element, {"actors", []}} | events] = events
    assert [{:start_element, {"actor", []}} | events] = events
    assert [{:characters, "Tom"} | events] = events
    assert [{:end_element, "actor"} | events] = events
    assert [{:start_element, {"actor", []}} | events] = events
    assert [{:characters, "Jerry"} | events] = events
    assert [{:end_element, "actor"} | events] = events
    assert [{:end_element, "actors"} | events] = events

    assert [{:end_element, "item"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []
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

  describe "encode!/2" do
    import Saxy.XML

    test "encodes XML document into string" do
      root = element("foo", [], "foo")
      assert Saxy.encode!(root) == ~s(<?xml version="1.0"?><foo>foo</foo>)
    end
  end

  describe "encode_to_iodata!/2" do
    import Saxy.XML

    test "encodes XML document into IO data" do
      root = element("foo", [], "foo")
      assert xml = Saxy.encode_to_iodata!(root)
      assert is_list(xml)
      assert IO.iodata_to_binary(xml) == ~s(<?xml version="1.0"?><foo>foo</foo>)
    end
  end

  def convert_entity("unknown"), do: "known"
end
