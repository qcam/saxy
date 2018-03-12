defmodule Saxy.Parser.PrologTest do
  use ExUnit.Case, async: true

  import Saxy.Parser.Prolog, only: [parse_prolog: 5]

  alias Saxy.ParseError

  alias Saxy.TestHandlers.StackHandler

  test "parse_prolog/2 with all properties declared" do
    buffer = """
    <?xml version="1.0" encoding="utf-8" standalone='yes' ?> <foo></foo>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert Keyword.get(prolog, :version) == "1.0"
    assert Keyword.get(prolog, :encoding) == "utf-8"
    assert Keyword.get(prolog, :standalone) == true
  end

  test "parse_prolog/2 with 'version' and 'standalone' declared" do
    buffer = """
    <?xml version="1.0" standalone='yes' ?> <foo></foo>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert Keyword.get(prolog, :version) == "1.0"
    assert Keyword.get(prolog, :encoding) == nil
    assert Keyword.get(prolog, :standalone) == true
  end

  test "parse_prolog/2 with 'version' and 'encoding' declared" do
    buffer = """
    <?xml version="1.0" encoding="UTF-8" ?> <foo></foo>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert Keyword.get(prolog, :version) == "1.0"
    assert Keyword.get(prolog, :encoding) == "UTF-8"
  end

  test "parse_prolog/2 with only 'version' declared" do
    buffer = """
    <?xml version = "1.0" ?> <foo></foo>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert Keyword.get(prolog, :version) == "1.0"
    assert Keyword.get(prolog, :encoding) == nil
  end

  test "parse_prolog/2 with no prolog declared" do
    buffer = """
    <foo></foo>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert prolog == []
  end

  test "parse_prolog/2 with no version declaration" do
    buffer = """
    <?xml encoding="utf-8" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"e\", expected token: :version"
  end

  test "parse_prolog/2 with encoding and standalone in the wrong place" do
    buffer = """
    <?xml version="1.0" standalone="yes" encoding="utf-8" ?>
    <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"e\", expected token: :xml_decl_close"
  end

  test "parse_prolog/2 with malformed version" do
    buffer = """
    <?xml version= "2.0" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"2\", expected token: :\"1.\""
  end

  test "parse_prolog/2 with wrong version declared" do
    buffer = """
    <?xml version="1.2e" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"e\", expected token: :version_num"
  end

  test "parse_prolog/2 with wrong version closing quote" do
    buffer = """
    <?xml version="1.0' ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"'\", expected token: :version_num"
  end

  test "parse_prolog/2 with malformed encoding in quote" do
    buffer = """
    <?xml version="1.0" encoding='UTF-8" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"\\\"\", expected token: :encoding_name"

    buffer = """
    <?xml version="1.0" encoding="UTF-8' ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"'\", expected token: :encoding_name"
  end

  test "parse_prolog/2 with bad encoding value" do
    buffer = """
    <?xml version="1.0" encoding='<hello>' ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"<\", expected token: :encoding_name"

    buffer = """
    <?xml version="1.0" encoding="a<" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"<\", expected token: :encoding_name"
  end

  test "parse_prolog/2 with malformed standalone in quote" do
    buffer = """
    <?xml version="1.0" standalone="yes' ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"'\", expected token: :quote"

    buffer = """
    <?xml version="1.0" standalone='yes" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"\\\"\", expected token: :quote"
  end

  test "parse_prolog/2 with wrong standalone value" do
    buffer = """
    <?xml version="1.0" standalone="foo" ?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"f\", expected token: :yes_or_no"
  end

  test "parse_prolog/2 with malformed XMLDecl close" do
    buffer = """
    <?xml version="1.0" x?> <foo></foo>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"x\", expected token: :xml_decl_close"
  end

  test "parse_prolog/2 with Misc" do
    buffer = """
    <?xml version="1.0" ?>
    <?foo hello world ?><foo/>
    """

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert prolog == [version: "1.0"]

    buffer = """
    <?xml version="1.0" ?>
    <?xMl hello world ?>
    <foo/>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) ==
      "unexpected target name \"xMl\" at the start of processing instruction, the target names \"XML\", \"xml\", and so on are reserved for standardization" 

    buffer = """
    <?xml version="1.0" ?>
    <?! hello world ?>
    <foo/>
    """

    assert {:error, error} = parse_prolog(buffer, make_cont(), buffer, 0, make_state())
    assert ParseError.message(error) == "unexpected byte \"!\", expected token: :processing_instruction"
  end

  test "parse_prolog/2 with streaming" do
    buffer = ""
    stream = Stream.map(["<?xml version", "='1.0' ?>", "<foo/>"], &(&1))
    state = make_state() |> Map.put(:cont, stream)

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, stream, buffer, 0, state)
    assert prolog == [version: "1.0"]

    buffer = "<?xml"
    stream = Stream.map(["  version", "='1.0' ?><foo/>"], &(&1))
    state = make_state() |> Map.put(:cont, stream)

    assert {:ok, %{prolog: prolog}} = parse_prolog(buffer, stream, buffer, 0, state)
    assert prolog == [version: "1.0"]

    stream =
      """
      <?xml version='1.0' encoding=\"utf-8\" standalone='yes' ?>
      <!--Ignore me I am just a comment-->
      <?foo Hmm? Then probably ignore me too ?>
      <foo/>
      """
      |> String.codepoints()
      |> Stream.map(&(&1))

    state = make_state()
    assert {:ok, %{prolog: prolog}} = parse_prolog("", stream, "", 0, state)

    assert Keyword.get(prolog, :version) == "1.0"
    assert Keyword.get(prolog, :encoding) == "utf-8"
    assert Keyword.get(prolog, :standalone) == true
  end

  defp make_state(state \\ []) do
    %Saxy.State{
      prolog: nil,
      handler: StackHandler,
      user_state: state
    }
  end

  defp make_cont(), do: :done
end
