defmodule Saxy.EncoderTest do
  use ExUnit.Case, async: true

  doctest Saxy.Encoder

  test "encodes empty element" do
    document = {
      "person",
      [{"first_name", "John"}, {"last_name", "Doe"}],
      []
    }

    xml = encode(document, version: "1.0")

    assert xml == ~s(<?xml version="1.0"?><person first_name="John" last_name="Doe"/>)
  end

  test "encodes normal element" do
    content = [{:characters, "Hello my name is John Doe"}]

    document = {
      "person",
      [{"first_name", "John"}, {"last_name", "Doe"}],
      content
    }

    xml = encode(document, version: "1.0")

    assert xml == ~s(<?xml version="1.0"?><person first_name="John" last_name="Doe">Hello my name is John Doe</person>)
  end

  test "encodes attributes with escapable characters" do
    xml = encode({"person", [{"first_name", "&'\"<>"}], []})

    assert xml == ~s(<person first_name="&amp;&apos;&quot;&lt;&gt;"/>)
  end

  test "encodes CDATA" do
    children = [{:cdata, "Tom & Jerry"}]

    document = {"person", [], children}
    xml = encode(document, version: "1.0")

    assert xml == ~s(<?xml version="1.0"?><person><![CDATA[Tom & Jerry]]></person>)
  end

  test "encodes characters to references" do
    content = [
      {:characters, "Tom & Jerry"}
    ]

    document = {"movie", [], content}
    xml = encode(document, version: "1.0")

    assert xml == ~s(<?xml version="1.0"?><movie>Tom &amp; Jerry</movie>)
  end

  test "supports mentioning utf-8 encoding in the prolog (as atom)" do
    document = {"body", [], []}

    xml = encode(document, version: "1.0", encoding: :utf8)
    assert xml == ~s(<?xml version="1.0" encoding="utf-8"?><body/>)
  end

  test "supports mentioning UTF-8 encoding in the prolog (as string)" do
    document = {"body", [], []}

    xml = encode(document, version: "1.0", encoding: "UTF-8")
    assert xml == ~s(<?xml version="1.0" encoding="UTF-8"?><body/>)

    xml = encode(document, version: "1.0", encoding: "utf-8")
    assert xml == ~s(<?xml version="1.0" encoding="utf-8"?><body/>)
  end

  test "encodes reference" do
    content = [
      {:reference, {:entity, "foo"}},
      {:reference, {:hexadecimal, ?<}},
      {:reference, {:decimal, ?<}}
    ]

    document = {"movie", [], content}
    xml = encode(document, [])

    assert xml == ~s(<?xml version="1.0"?><movie>&foo;&x3C;&x60;</movie>)
  end

  test "encodes comments" do
    content = [
      {:comment, "This is obviously a comment"},
      {:comment, "A+, A, A-"}
    ]

    document = {"movie", [], content}
    xml = encode(document)

    assert xml == ~s(<movie><!--This is obviously a comment--><!--A+, A, A- --></movie>)
  end

  test "encodes processing instruction" do
    content = [
      {:processing_instruction, "xml-stylesheet", "type=\"text/xsl\" href=\"style.xsl\""}
    ]

    document = {"movie", [], content}
    xml = encode(document, version: "1.0")

    assert xml == ~s(<?xml version="1.0"?><movie><?xml-stylesheet type="text/xsl" href="style.xsl"?></movie>)
  end

  test "encodes nested element" do
    children = [
      {"address", [{"street", "foo"}, {"city", "bar"}], []},
      {"gender", [], [{:characters, "male"}]}
    ]

    document = {"person", [{"first_name", "John"}, {"last_name", "Doe"}], children}
    xml = encode(document)

    assert xml ==
             ~s(<person first_name="John" last_name="Doe"><address street="foo" city="bar"/><gender>male</gender></person>)
  end

  test "integration with builder" do
    import Saxy.XML

    items =
      for index <- 1..2 do
        element(:item, [], [
          element(:title, [], "Item #{index}"),
          element(:link, [], "Link #{index}"),
          comment("Comment #{index}"),
          element(:description, [], cdata("<a></b>")),
          characters("ABCDEFG"),
          reference(:entity, "copyright")
        ])
      end

    xml =
      :rss
      |> element([version: "2.0"], items)
      |> encode(version: "1.0")

    expected = """
    <?xml version="1.0"?>
    <rss version="2.0">
    <item>
    <title>Item 1</title>
    <link>Link 1</link>
    <!--Comment 1-->
    <description><![CDATA[<a></b>]]></description>
    ABCDEFG
    &copyright;
    </item>
    <item>
    <title>Item 2</title>
    <link>Link 2</link>
    <!--Comment 2-->
    <description><![CDATA[<a></b>]]></description>
    ABCDEFG
    &copyright;
    </item>
    </rss>
    """

    assert xml == String.replace(expected, "\n", "")
  end

  test "generates deeply nested document" do
    {document, xml} =
      Enum.reduce(100..1//-1, {"content", "content"}, fn index, {document, xml} ->
        {
          Saxy.XML.element("level#{index}", [], document),
          "<level#{index}>#{xml}</level#{index}>"
        }
      end)

    xml = "<?xml version=\"1.0\"?>" <> xml

    assert encode(document, version: "1.0") == xml
  end

  test "encodes non expanded entity reference" do
    document = {"foo", [], [{"event", [], ["test &apos; test"]}]}
    assert "<foo><event>test &apos; test</event></foo>" == encode(document)
  end

  defp encode(document, prolog \\ nil) do
    Saxy.encode!(document, prolog)
  end
end
