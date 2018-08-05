defmodule Saxy.Parser.ElementTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Saxy.Parser.Element, only: [parse_element: 5]

  alias Saxy.ParseError

  alias Saxy.TestHandlers.StackHandler

  test "parses element having no attributes" do
    buffer = "<foo></foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())

    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"foo", []}} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events
    assert events == []

    buffer = "<fóo></fóo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())

    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"fóo", []}} | events] = events
    assert [{:end_element, "fóo"} | events] = events
    assert [{:end_document, {}} | events] = events
    assert events == []
  end

  test "parses element with nested children" do
    buffer = """
    <item name="[日本語] Tom &amp; Jerry" category='movie' >
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

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

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

  test "parses empty element" do
    buffer = "<foo />"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"foo", []}} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []

    buffer = "<foo foo='FOO' bar='BAR'/>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    element = {"foo", [{"bar", "BAR"}, {"foo", "FOO"}]}
    assert [{:start_element, ^element} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []

    buffer = "<foo foo='Tom &amp; Jerry' bar='bar' />"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    element = {"foo", [{"bar", "bar"}, {"foo", "Tom & Jerry"}]}
    assert [{:start_element, ^element} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []
  end

  test "parses element content" do
    buffer = "<foo>Lorem Ipsum Lorem Ipsum</foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"foo", []}} | events] = events
    assert [{:characters, "Lorem Ipsum Lorem Ipsum"} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []

    buffer = """
    <foo>
    Lorem Ipsum Lorem Ipsum
    </foo>
    """

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"foo", []}} | events] = events
    assert [{:characters, "\nLorem Ipsum Lorem Ipsum\n"} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []
  end

  test "parses comments" do
    buffer = "<foo><!--IGNORE ME--></foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    events = Enum.reverse(state.user_state)

    assert [{:start_element, {"foo", []}} | events] = events
    assert [{:end_element, "foo"} | events] = events
    assert [{:end_document, {}} | events] = events

    assert events == []
  end

  test "handles malformed comments" do
    buffer = "<foo><!--IGNORE ME---></foo>"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"-\", expected token: :comment"
  end

  test "parses element references" do
    buffer = "<foo>Tom &#x26; Jerry</foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :characters, "Tom & Jerry")

    buffer = "<foo>Tom &#38; Jerry</foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :characters, "Tom & Jerry")

    buffer = "<foo>Tom &amp; Jerry</foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :characters, "Tom & Jerry")
  end

  test "handles malformed references in element" do
    buffer = "<foo>Tom &#xt5; Jerry</foo>"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    buffer = "<foo>Tom &#t5; Jerry</foo>"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    buffer = "<foo>Tom &t5 Jerry</foo>"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \" \", expected token: :entity_ref"
  end

  test "parses CDATA" do
    buffer = "<foo><![CDATA[John Cena <foo></foo> &amp;]]></foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_events(state, :characters) == [{:characters, "John Cena <foo></foo> &amp;"}]
  end

  test "handles malformed CDATA" do
    buffer = "<foo><![CDATA[John Cena </foo>"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected end of input, expected token: :\"]]\""
  end

  test "parses processing instruction" do
    buffer = "<foo><?hello the instruction?></foo>"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert length(state.user_state) == 3
  end

  test "handles malformed processing instruction" do
    buffer = "<foo><?hello the instruction"

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected end of input, expected token: :processing_instruction"
  end

  test "parses element attributes" do
    buffer = "<foo abc='123' def=\"456\" g:hi='789' />"

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    tag = {"foo", [{"g:hi", "789"}, {"def", "456"}, {"abc", "123"}]}
    assert find_event(state, :start_element, tag)
    assert find_event(state, :end_element, "foo")

    buffer = ~s(<foo abc = "ABC" />)

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    tag = {"foo", [{"abc", "ABC"}]}
    assert find_event(state, :start_element, tag)
    assert find_event(state, :end_element, "foo")

    buffer = ~s(<foo val="Tom &#x26; Jerry" />)

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(state, :end_element, "foo")

    buffer = ~s(<foo val="Tom &#x26 Jerry" />)

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \" \", expected token: :char_ref"

    buffer = ~s(<foo val="Tom &#38; Jerry" />)

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(state, :end_element, "foo")

    buffer = ~s(<foo val="Tom &#38 Jerry" />)

    assert {:error, error} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \" \", expected token: :char_ref"

    buffer = ~s(<foo val="Tom &amp; Jerry" />)

    assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
    assert find_event(state, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(state, :end_element, "foo")
  end

  @tag :property

  property "element name" do
    check all name <- name() do
      buffer = "<#{name}></#{name}>"
      assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())

      events = Enum.reverse(state.user_state)

      assert [{:start_element, {^name, []}} | events] = events
      assert [{:end_element, ^name} | events] = events
      assert [{:end_document, {}} | events] = events
      assert events == []
    end

    check all name <- name() do
      buffer = "<#{name}/>"
      assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())

      events = Enum.reverse(state.user_state)

      assert [{:start_element, {^name, []}} | events] = events
      assert [{:end_element, ^name} | events] = events
      assert [{:end_document, {}} | events] = events
      assert events == []
    end
  end

  property "attribute name" do
    check all attribute_name <- name() do
      buffer = "<foo #{attribute_name}='bar'></foo>"

      assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
      events = Enum.reverse(state.user_state)

      element = {"foo", [{attribute_name, "bar"}]}

      assert [{:start_element, ^element} | events] = events
      assert [{:end_element, "foo"} | events] = events
      assert [{:end_document, {}} | events] = events
      assert events == []
    end
  end

  property "attribute value" do
    reference_generator =
      gen all name <- name() do
        "&" <> name <> ";"
      end

    check all attribute_value_chars <- string(:printable),
              reference <- reference_generator do
      attribute_value =
        [attribute_value_chars, reference]
        |> Enum.shuffle()
        |> IO.iodata_to_binary()

      buffer = "<foo foo='#{attribute_value}'></foo>"

      assert {:ok, state} = parse_element(buffer, make_cont(), buffer, 0, make_state())
      events = Enum.reverse(state.user_state)

      element = {"foo", [{"foo", attribute_value}]}

      assert [{:start_element, ^element} | events] = events
      assert [{:end_element, "foo"} | events] = events
      assert [{:end_document, {}} | events] = events
      assert events == []
    end
  end

  defp make_state(state \\ []) do
    %Saxy.State{
      prolog: nil,
      handler: StackHandler,
      user_state: state,
      expand_entity: :keep
    }
  end

  defp make_cont() do
    :done
  end

  defp find_events(state, event_type) do
    Enum.filter(state.user_state, fn {type, _data} -> type == event_type end)
  end

  defp find_event(state, event_type, event_data) do
    Enum.find(state.user_state, fn {type, data} ->
      type == event_type && data == event_data
    end)
  end

  defp name() do
    name_start_char_ranges = [
      ?:, ?A..?Z, ?a..?z, ?_, 0xC0..0xD6, 0xD8..0xF6,
      0xF8..0x2FF, 0x370..0x200D, 0x2070..0x218F,
      0x2C00..0x2FEF, 0x3001..0xD7FF, 0xF900..0xFDCF,
      0xFDF0..0xFFFD, 0x10000..0xEFFFF
    ]

    name_char_ranges = name_start_char_ranges ++ [
      ?0..?9, ?-, ?., 0xB7, 0x300..0x036F, 0x203F..0x2040
    ]

    gen all start_char <- string(name_start_char_ranges, min_length: 1, max_length: 4),
            chars <- string(name_char_ranges) do
      start_char <> chars
    end
  end
end
