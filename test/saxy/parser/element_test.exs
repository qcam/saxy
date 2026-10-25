defmodule Saxy.Parser.ElementTest do
  use SaxyTest.ParsingCase, async: true

  alias Saxy.TestHandlers.StackHandler

  test "parses element having no attributes" do
    events = assert_parse("<foo></foo>")

    assert events == [
             {:start_element, {"foo", []}},
             {:end_element, "foo"}
           ]

    assert_parse("<cổc></cổc>")
  end

  test "parses element with nested children" do
    buffer =
      remove_indents("""
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
      """)

    events = assert_parse(buffer, cdata_as_characters: false)

    item_attributes = [{"name", "[日本語] Tom & Jerry"}, {"category", "movie"}]
    assert [{:start_element, {"item", ^item_attributes}} | events] = events

    author_attributes = [{"name", "William Hanna & Joseph Barbera"}]
    assert [{:start_element, {"author", ^author_attributes}} | events] = events
    assert [{:end_element, "author"} | events] = events

    assert [{:start_element, {"description", []}} | events] = events
    assert [{:cdata, "<strong>\"Tom & Jerry\" is a cool movie!</strong>"} | events] = events
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

    assert events == []
  end

  test "parses empty element" do
    buffer = "<foo />"

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {"foo", []}},
             {:end_element, "foo"}
           ]

    buffer = "<foo foo='FOO' bar='BAR'/>"

    events = assert_parse(buffer)

    element = {"foo", [{"foo", "FOO"}, {"bar", "BAR"}]}

    assert events == [
             {:start_element, element},
             {:end_element, "foo"}
           ]

    buffer = "<foo foo='Tom &amp; Jerry' bar='bar' />"

    events = assert_parse(buffer)
    element = {"foo", [{"foo", "Tom & Jerry"}, {"bar", "bar"}]}

    assert events == [
             {:start_element, element},
             {:end_element, "foo"}
           ]
  end

  test "parses element content" do
    buffer = "<foo>Lorem Ipsum Lorem Ipsum</foo>"

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {"foo", []}},
             {:characters, "Lorem Ipsum Lorem Ipsum"},
             {:end_element, "foo"}
           ]

    buffer = """
    <foo>
    Lorem Ipsum Lorem Ipsum
    </foo>
    """

    events = assert_parse(buffer)

    assert events == [
             {:start_element, {"foo", []}},
             {:characters, "\nLorem Ipsum Lorem Ipsum\n"},
             {:end_element, "foo"}
           ]

    events = assert_parse("<foo>  </foo>")

    assert events == [
             {:start_element, {"foo", []}},
             {:characters, "  "},
             {:end_element, "foo"}
           ]
  end

  test "parses comments" do
    assert_parse("<foo><!--IGNORE ME--></foo>")
  end

  test "handles malformed comments" do
    error = refute_parse("<foo><!--IGNORE ME---></foo>")
    assert Exception.message(error) == "unexpected byte \"-\", expected token: :comment"

    refute_parse("<foo><!--IGNORE ME")
  end

  test "parses element references" do
    events = assert_parse("<foo>Tom &#x26; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")

    events = assert_parse("<foo>Tom &#38; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")

    events = assert_parse("<foo>Tom &amp; Jerry</foo>")
    assert find_event(events, :characters, "Tom & Jerry")
  end

  test "handles malformed references in element" do
    error = refute_parse("<foo>Tom &#xt5; Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    error = refute_parse("<foo>Tom &#t5; Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \"t\", expected token: :char_ref"

    error = refute_parse("<foo>Tom &t5 Jerry</foo>")
    assert Exception.message(error) == "unexpected byte \" \", expected token: :entity_ref"
  end

  test "rejects out-of-range numeric character references in element without crashing" do
    # Surrogate code points are not valid XML characters.
    error = refute_parse("<foo>&#xD800;</foo>")
    assert Exception.message(error) =~ "not a valid XML character"

    # Beyond the Unicode maximum (> U+10FFFF).
    error = refute_parse("<foo>&#x110000;</foo>")
    assert Exception.message(error) =~ "not a valid XML character"

    error = refute_parse("<foo>&#1114112;</foo>")
    assert Exception.message(error) =~ "not a valid XML character"

    # Disallowed control character (NUL).
    error = refute_parse("<foo>&#x0;</foo>")
    assert Exception.message(error) =~ "not a valid XML character"
  end

  test "rejects overlong numeric character references in element without crashing" do
    error = refute_parse("<foo>&#11111111111111111111;</foo>")
    assert Exception.message(error) =~ "character reference"

    error = refute_parse("<foo>&#x1111111111111111;</foo>")
    assert Exception.message(error) =~ "character reference"
  end

  test "rejects out-of-range numeric character references in attribute without crashing" do
    error = refute_parse(~s(<foo val="&#xD800;" />))
    assert Exception.message(error) =~ "not a valid XML character"

    error = refute_parse(~s(<foo val="&#x110000;" />))
    assert Exception.message(error) =~ "not a valid XML character"

    error = refute_parse(~s(<foo val="&#11111111111111111111;" />))
    assert Exception.message(error) =~ "character reference"
  end

  test "parses boundary numeric character references" do
    events = assert_parse("<foo>&#x10FFFF;</foo>")
    assert find_event(events, :characters, <<0x10FFFF::utf8>>)

    # Leading zeros within the digit budget are still accepted.
    events = assert_parse("<foo>&#x00041;</foo>")
    assert find_event(events, :characters, "A")

    events = assert_parse("<foo>&#x9;</foo>")
    assert find_event(events, :characters, "\t")
  end

  test "parses numeric character references with many leading zeros" do
    events = assert_parse("<foo>&#00000000065;</foo>")
    assert find_event(events, :characters, "A")

    events = assert_parse("<foo>&#x0000000041;</foo>")
    assert find_event(events, :characters, "A")

    events = assert_parse(~s(<foo val="&#00000000065;" />))
    assert find_event(events, :start_element, {"foo", [{"val", "A"}]})

    error = refute_parse("<foo>&#00000000000;</foo>")
    assert Exception.message(error) =~ "not a valid XML character"
  end

  test "rejects decimal NUL, U+FFFE and U+FFFF references" do
    for ref <- ["&#0;", "&#65534;", "&#65535;", "&#xFFFE;", "&#xFFFF;"] do
      error = refute_parse("<foo>#{ref}</foo>")
      assert Exception.message(error) =~ "not a valid XML character"

      error = refute_parse(~s(<foo val="#{ref}" />))
      assert Exception.message(error) =~ "not a valid XML character"
    end
  end

  test "rejects empty numeric character references" do
    for ref <- ["&#;", "&#x;"] do
      error = refute_parse("<foo>#{ref}</foo>")
      assert Exception.message(error) == "unexpected byte \";\", expected token: :char_ref"

      error = refute_parse(~s(<foo val="#{ref}" />))
      assert Exception.message(error) == "unexpected byte \";\", expected token: :char_ref"
    end
  end

  test "parses character references split across chunk boundaries" do
    data = ~s(<foo val="&#x26;&#65;">a&#x10FFFF;&#00000000065;b</foo>)
    expected = Saxy.parse_string(data, StackHandler, [])
    assert {:ok, _} = expected

    for i <- 1..(byte_size(data) - 1) do
      <<a::binary-size(i), b::binary>> = data
      assert Saxy.parse_stream([a, b], StackHandler, []) == expected
    end
  end

  test "malformed misc in the end of the document" do
    error = refute_parse("<foo/>bar")
    assert Exception.message(error) == "unexpected byte \"b\", expected token: :misc"

    error = refute_parse("<foo/><_")
    assert Exception.message(error) == "unexpected byte \"_\", expected token: :misc"
  end

  test "parses CDATA" do
    events = assert_parse("<foo><![CDATA[John Cena <foo></foo> &amp;]]></foo>")
    assert find_events(events, :characters) == [{:characters, "John Cena <foo></foo> &amp;"}]

    events = assert_parse("<foo><![CDATA[John Cena <foo></foo> &amp;]]></foo>", cdata_as_characters: false)
    assert find_events(events, :cdata) == [{:cdata, "John Cena <foo></foo> &amp;"}]
  end

  test "handles malformed CDATA" do
    error = refute_parse("<foo><![CDATA[John Cena </foo>")
    assert Exception.message(error) == "unexpected end of input, expected token: :\"]]\""
  end

  test "parses CDATA containing multi-byte UTF-8 characters" do
    events = assert_parse("<foo><![CDATA[£26,000]]></foo>")
    assert find_events(events, :characters) == [{:characters, "£26,000"}]
  end

  test "parses multi-byte UTF-8 split across chunks in an element comment" do
    assert_parse("<foo><!-- £ --></foo>")
  end

  test "parses multi-byte UTF-8 split across chunks in an in-element processing instruction" do
    assert_parse("<foo><?target £?></foo>")
  end

  test "parses multi-byte UTF-8 split across chunks in a prolog comment" do
    assert_parse("<!-- £ --><foo/>")
  end

  test "parses multi-byte UTF-8 split across chunks in a prolog processing instruction" do
    assert_parse("<?target £?><foo/>")
  end

  test "parses multi-byte UTF-8 split across chunks in a comment after the DOCTYPE" do
    assert_parse("<!DOCTYPE foo><!-- £ --><foo/>")
  end

  test "parses multi-byte UTF-8 split across chunks in a processing instruction after the DOCTYPE" do
    assert_parse("<!DOCTYPE foo><?target £?><foo/>")
  end

  test "parses multi-byte UTF-8 split across chunks in an epilog comment" do
    assert_parse("<foo/><!-- £ -->")
  end

  test "parses multi-byte UTF-8 split across chunks in an epilog processing instruction" do
    assert_parse("<foo/><?target £?>")
  end

  test "parses multi-byte UTF-8 split across chunks at the start of a child element name" do
    assert_parse("<foo><été/></foo>")
    assert_parse("<foo><日本語></日本語></foo>")
    assert_parse("<foo><𐌰/></foo>")
  end

  test "parses processing instruction" do
    events = assert_parse("<foo><?hello the instruction?></foo>")
    assert length(events) == 2

    assert_parse("<foo><?ổ instruction?></foo>")
    assert_parse("<foo><?cổ instruction?></foo>")
    assert_parse("<foo/><?ổ instruction?>")
    assert_parse("<foo/><?cổ instruction?>")
  end

  test "handles malformed processing instruction" do
    error = refute_parse("<foo><?hello the instruction")
    assert Exception.message(error) == "unexpected end of input, expected token: :processing_instruction"
  end

  test "parses element attributes" do
    events = assert_parse("<foo abc='123' def=\"456\" g:hi='789' />")
    tag = {"foo", [{"abc", "123"}, {"def", "456"}, {"g:hi", "789"}]}
    assert find_event(events, :start_element, tag)
    assert find_event(events, :end_element, "foo")

    events = assert_parse(~s(<foo abc = "ABC" />))
    tag = {"foo", [{"abc", "ABC"}]}
    assert find_event(events, :start_element, tag)
    assert find_event(events, :end_element, "foo")

    events = assert_parse(~s(<foo val="Tom &#x26; Jerry" />))
    assert find_event(events, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, "foo")

    error = refute_parse(~s(<foo val="Tom &#x26 Jerry" />))
    assert Exception.message(error) == "unexpected byte \" \", expected token: :char_ref"

    events = assert_parse(~s(<foo val="Tom &#38; Jerry" />))
    assert find_event(events, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, "foo")

    error = refute_parse(~s(<foo val="Tom &#38 Jerry" />))
    assert Exception.message(error) == "unexpected byte \" \", expected token: :char_ref"

    events = assert_parse(~s(<foo val="Tom &amp; Jerry" />))
    assert find_event(events, :start_element, {"foo", [{"val", "Tom & Jerry"}]})
    assert find_event(events, :end_element, "foo")
  end

  @tag :property

  property "element name" do
    check all(name <- name()) do
      events = assert_parse("<#{name}></#{name}>")

      assert events == [{:start_element, {name, []}}, {:end_element, name}]
    end

    check all(name <- name()) do
      events = assert_parse("<#{name}/>")

      assert events == [{:start_element, {name, []}}, {:end_element, name}]
    end
  end

  property "attribute name" do
    check all(attribute_name <- name()) do
      events = assert_parse("<foo #{attribute_name}='bar'></foo>")

      assert events == [
               {:start_element, {"foo", [{attribute_name, "bar"}]}},
               {:end_element, "foo"}
             ]
    end
  end

  property "attribute value" do
    reference_generator =
      gen all(name <- name()) do
        "&" <> name <> ";"
      end

    check all(
            attribute_value_chars <- string(:alphanumeric),
            reference <- reference_generator
          ) do
      attribute_value =
        [attribute_value_chars, reference]
        |> Enum.shuffle()
        |> IO.iodata_to_binary()

      events = assert_parse("<foo foo='#{attribute_value}'></foo>")
      element = {"foo", [{"foo", attribute_value}]}

      assert events == [{:start_element, element}, {:end_element, "foo"}]
    end
  end

  defp find_events(events, event_type) do
    Enum.filter(events, fn {type, _data} -> type == event_type end)
  end

  defp find_event(events, event_type, event_data) do
    Enum.find(events, fn {type, data} ->
      type == event_type && data == event_data
    end)
  end

  @name_start_char_ranges [
    ?:,
    ?_,
    ?A..?Z,
    ?a..?z,
    0xC0..0xD6,
    0xD8..0xF6,
    0xF8..0x2FF,
    0x370..0x37D,
    0x37F..0x1FFF,
    0x200C..0x200D,
    0x2070..0x218F,
    0x2C00..0x2FEF,
    0x3001..0xD7FF,
    0xF900..0xFDCF,
    0xFDF0..0xFFFD,
    0x10000..0xEFFFF
  ]

  @name_char_ranges @name_start_char_ranges ++
                      [
                        ?0..?9,
                        ?-,
                        ?.,
                        0xB7,
                        0x0300..0x036F,
                        0x203F..0x2040
                      ]

  defp name() do
    gen all(
          start_char <- string(@name_start_char_ranges, min_length: 1, max_length: 4),
          chars <- string(@name_char_ranges)
        ) do
      start_char <> chars
    end
  end

  defp refute_parse(data, options \\ []) do
    assert {:error, error} = Saxy.parse_string(data, StackHandler, [], options)

    stream = for <<char <- data>>, do: <<char>>
    assert {:error, _} = Saxy.parse_stream(stream, StackHandler, [], options)

    error
  end

  defp assert_parse(data, options \\ []) do
    assert {:ok, events} = Saxy.parse_string(data, StackHandler, [], options)

    stream = for <<char <- data>>, do: <<char>>
    assert Saxy.parse_stream(stream, StackHandler, [], options) == {:ok, events}

    assert [{:end_document, {}} | events] = events
    assert [{:start_document, []} | events] = Enum.reverse(events)

    events
  end
end
