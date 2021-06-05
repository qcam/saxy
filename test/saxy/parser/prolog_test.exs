defmodule Saxy.Parser.PrologTest do
  use SaxyTest.ParsingCase, async: true

  alias SaxyTest.ControlHandler

  defmodule PrologHandler do
    def handle_event(:start_document, prolog, _) do
      {:stop, prolog}
    end
  end

  describe "welformed XML prologs" do
    test "with all properties declared" do
      data = ~s(<?xml version="1.0" encoding="utf-8" standalone='yes' ?>)

      assert {:ok, prolog} = parse_prolog(data)

      assert prolog[:version] == "1.0"
      assert prolog[:encoding] == "utf-8"
      assert prolog[:standalone] == true
    end

    test "with version and standalone declared" do
      data = ~s(<?xml version="1.0" standalone='yes' ?>)

      assert {:ok, prolog} = parse_prolog(data)

      assert prolog[:version] == "1.0"
      assert prolog[:encoding] == nil
      assert prolog[:standalone] == true
    end

    test "with version and encoding declared" do
      data = ~s(<?xml version="1.0" encoding="UTF-8" ?>)

      assert {:ok, prolog} = parse_prolog(data)

      assert prolog[:version] == "1.0"
      assert prolog[:encoding] == "UTF-8"
      assert prolog[:standalone] == nil
    end

    test "with only version declared" do
      data = ~s(<?xml version = "1.0" ?>)

      assert {:ok, prolog} = parse_prolog(data)

      assert prolog[:version] == "1.0"
      assert prolog[:encoding] == nil
      assert prolog[:standalone] == nil
    end

    test "with no prolog declaration" do
      data = "<foo></foo>"

      assert parse_prolog(data) == {:ok, []}
    end
  end

  describe "malformed XML prolog" do
    test "missing version declaration" do
      data = ~s(<?xml encoding="utf-8" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"e\", expected token: :version"
    end

    test "misplaced encoding and standalone declaration" do
      data = ~s(<?xml version="1.0" standalone="yes" encoding="utf-8" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"e\", expected token: :xml_decl_close"
    end

    test "invalid version declaration" do
      data = ~s(<?xml version= "2.0" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"2\", expected token: :\"1.\""

      data = ~s(<?xml version="1.2e" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"e\", expected token: :version_num"

      data = ~s(<?xml version="1." ?>)
      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == ~s(unexpected byte "\\"", expected token: :version_num)
    end

    test "invalid ending quote in version declaration" do
      data = ~s(<?xml version="1.0' ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == ~s(unexpected byte "'", expected token: :version_num)

      data = ~s(<?xml version='1.0" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == ~s(unexpected byte "\\\"", expected token: :version_num)
    end

    test "invalid ending quote in encoding declaration" do
      data = ~s(<?xml version="1.0" encoding='UTF-8" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"\\\"\", expected token: :encoding_name"

      data = ~s(<?xml version="1.0" encoding="UTF-8' ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == ~s(unexpected byte "'", expected token: :encoding_name)
    end

    test "invalid encoding value" do
      data = ~s(<?xml version="1.0" encoding='<hello>' ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"<\", expected token: :encoding_name"

      data = ~s(<?xml version="1.0" encoding="a<" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"<\", expected token: :encoding_name"

      data = ~s(<?xml version="1.0" encoding="abc" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected encoding declaration \"abc\", only UTF-8 is supported"
    end

    test "returns error for malformed standalone declaration" do
      buffer = """
      <?xml version="1.0" standalone="yes' ?> <foo></foo>
      """

      assert {:error, error} = parse_prolog(buffer)
      assert Exception.message(error) == "unexpected byte \"'\", expected token: :quote"

      buffer = """
      <?xml version="1.0" standalone='yes" ?> <foo></foo>
      """

      assert {:error, error} = parse_prolog(buffer)
      assert Exception.message(error) == "unexpected byte \"\\\"\", expected token: :quote"
    end

    test "invalid standalone value" do
      data = ~s(<?xml version="1.0" standalone="foo" ?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"f\", expected token: :yes_or_no"
    end

    test "malformed XML declaration" do
      data = ~s(<?xml version="1.0" x?>)

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"x\", expected token: :xml_decl_close"
    end

    test "incomplete version declaration" do
      data = ~s(<?xml version)
      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected end of input, expected token: :="
    end
  end

  describe "misc after XML declaration" do
    test "process instructions" do
      data = ~s(<?xml version="1.0" ?><?foo hello world ?><foo/>)

      assert {:ok, prolog} = parse_prolog(data)
      assert prolog == [version: "1.0"]

      data = """
      <?xml version="1.0" ?>
      <?xMl hello world ?>
      """

      assert {:error, error} = parse_prolog(data)

      assert Exception.message(error) ==
               "unexpected target name \"xMl\" at the start of processing instruction, the target names \"XML\", \"xml\", and so on are reserved for standardization"

      data = """
      <?xml version="1.0" ?>
      <?? hello world ?>
      """

      assert {:error, error} = parse_prolog(data)
      assert Exception.message(error) == "unexpected byte \"?\", expected token: :processing_instruction"
    end

    test "comments" do
      data = ~s(<?xml version="1.0" ?><!--foo-->)

      assert {:ok, prolog} = parse_prolog(data)
      assert prolog == [version: "1.0"]
    end
  end

  describe "document type definition" do
    test "skips parsing DTD" do
      data = """
      <?xml version="1.0" ?>
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
      <foo/>
      """

      assert_parse_dtd(data)
    end

    test "skips parsing DTD with declaration" do
      data = """
      <?xml version="1.0" ?>
      <!DOCTYPE note [
        <!ELEMENT note (to,from,heading,body)>
        <!ELEMENT to (#PCDATA)>
        <!ELEMENT from (#PCDATA)>
        <!ELEMENT heading (#PCDATA)>
        <!ELEMENT body (#PCDATA)>
      ]>
      <foo/>
      """

      assert_parse_dtd(data)
    end

    test "parses misc afters DTD" do
      data = """
      <?xml version="1.0" ?>
      <!DOCTYPE html>
      <!--This is comment-->
      <?foo foo?>
      <foo/>
      """

      assert_parse_dtd(data)
    end

    test "raises when DTD is incomplete" do
      data = """
      <?xml version="1.0" ?>
      <!DOCTYPE note
      <foo/>
      """

      assert {:error, error} = parse(data, ControlHandler, {:start_element, {:stop, :foo}})
      assert Exception.message(error) == "unexpected byte \" \", expected token: :dtd_content"
    end
  end

  property "prolog parsing" do
    check all {prolog, data} <- prolog() do
      assert {:ok, result} = parse_prolog(data)

      assert result[:version] == prolog[:version]
      assert result[:encoding] == prolog[:encoding]
      assert result[:standalone] == prolog[:standalone]
    end
  end

  defp prolog() do
    gen all s1 <- xml_whitespace(min_length: 1),
            {version_value, version} <- prolog_version(),
            s2 <- xml_whitespace(min_length: 1),
            {encoding_value, encoding} <- prolog_encoding(),
            s3 <- xml_whitespace(min_length: 1),
            {standalone_value, standalone} <- prolog_standalone(),
            s4 <- xml_whitespace() do
      prolog = %{
        version: version_value,
        encoding: encoding_value,
        standalone: standalone_value
      }

      prolog_text = "<?xml" <> s1 <> version <> s2 <> encoding <> s3 <> standalone <> s4 <> "?>"

      {prolog, prolog_text}
    end
  end

  defp prolog_version() do
    gen all version <- constant("1.0"),
            wrapping_quote <- xml_quote(),
            equal_sign <- xml_equal_sign() do
      binary = IO.iodata_to_binary(["version", equal_sign, wrapping_quote, version, wrapping_quote])
      {version, binary}
    end
  end

  defp prolog_encoding() do
    gen all encoding <- one_of([constant("utf-8"), constant(nil)]),
            wrapping_quote <- xml_quote(),
            equal_sign <- xml_equal_sign() do
      if encoding do
        binary = IO.iodata_to_binary(["encoding", equal_sign, wrapping_quote, encoding, wrapping_quote])
        {encoding, binary}
      else
        {encoding, ""}
      end
    end
  end

  defp prolog_standalone() do
    gen all standalone <- one_of([constant({true, "yes"}), constant({false, "no"}), constant(nil)]),
            wrapping_quote <- xml_quote(),
            equal_sign <- xml_equal_sign() do
      case standalone do
        nil ->
          {nil, ""}

        {standalone_value, standalone_text} ->
          binary = IO.iodata_to_binary(["standalone", equal_sign, wrapping_quote, standalone_text, wrapping_quote])
          {standalone_value, binary}
      end
    end
  end

  defp parse_prolog(data) do
    parse(data, PrologHandler, nil)
  end

  defp assert_parse_dtd(data) do
    assert parse(data, ControlHandler, {:start_element, {:stop, :foo}}) == {:ok, :foo}
  end
end
