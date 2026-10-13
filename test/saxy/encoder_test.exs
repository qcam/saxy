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

  test "splits CDATA terminators into adjacent sections" do
    for encoder <- [&Saxy.encode!/1, &Saxy.encode_to_iodata!/1] do
      document = {"body", [], [{:cdata, "before]]>after]]>"}]}

      assert IO.iodata_to_binary(encoder.(document)) ==
               "<body><![CDATA[before]]]]><![CDATA[>after]]]]><![CDATA[>]]></body>"
    end
  end

  test "round trips CDATA as text without injecting XML structure" do
    payload = "Ordinary message]]><injected source=\"attacker\">true</injected><![CDATA[ continuing"

    for text <- [
          "",
          "Tom & Jerry <tag> 'text' \"quoted\"",
          "é指示",
          "]]>",
          "]]>tail",
          "head]]>",
          "]]>]]>",
          "]]]]>",
          "]",
          "]]",
          "before]]>middle]]>after",
          payload
        ],
        encoder <- [&Saxy.encode!/2, &Saxy.encode_to_iodata!/2],
        cdata_as_characters <- [true, false] do
      document =
        Saxy.XML.element("message", [], [
          Saxy.XML.element("body", [], Saxy.XML.cdata(text)),
          Saxy.XML.element("status", [], "delivered")
        ])

      xml = document |> encoder.(version: "1.0") |> IO.iodata_to_binary()

      assert {:ok, {"message", [], [{"body", [], children}, {"status", [], ["delivered"]}]}} =
               Saxy.SimpleForm.parse_string(xml, cdata_as_characters: cdata_as_characters)

      decoded =
        Enum.map(children, fn
          {:cdata, characters} when not cdata_as_characters -> characters
          characters when is_binary(characters) and cdata_as_characters -> characters
        end)

      assert IO.iodata_to_binary(decoded) == text
    end
  end

  test "splits CDATA terminators across nested iodata chunks" do
    for characters <- [["before]", [?], [">after"]]], ["before]]" | ">after"]],
        encoder <- [&Saxy.encode!/1, &Saxy.encode_to_iodata!/1] do
      xml = encoder.({"body", [], [{:cdata, characters}]}) |> IO.iodata_to_binary()

      assert xml == "<body><![CDATA[before]]]]><![CDATA[>after]]></body>"

      assert {:ok, {"body", [], [{:cdata, "before]]"}, {:cdata, ">after"}]}} =
               Saxy.SimpleForm.parse_string(xml, cdata_as_characters: false)
    end
  end

  test "encodes a single byte in a direct CDATA tuple" do
    for encoder <- [&Saxy.encode!/1, &Saxy.encode_to_iodata!/1] do
      assert IO.iodata_to_binary(encoder.({"body", [], [{:cdata, ?A}]})) ==
               "<body><![CDATA[A]]></body>"
    end
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

    assert xml == ~s(<?xml version="1.0"?><movie>&foo;&#x3C;&#60;</movie>)
  end

  test "encodes character references that parse back to their characters" do
    document = {"movie", [], [{:reference, {:hexadecimal, ?<}}, {:reference, {:decimal, ?>}}]}

    assert Saxy.SimpleForm.parse_string(encode(document)) == {:ok, {"movie", [], ["<>"]}}
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
