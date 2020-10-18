defmodule Saxy.SimpleFormTest do
  use ExUnit.Case, async: true

  import SaxyTest.Utils

  doctest Saxy.SimpleForm

  test "parses simple XML and default options" do
    xml = """
    <?xml version="1.0" encoding="utf-8" ?>
    <menu>
      <movie url="https://www.imdb.com/title/tt0120338/" id="tt0120338">
        <name>Titanic</name>
        <characters>Jack &amp; Rose</characters>
      </movie>
      <movie url="https://www.imdb.com/title/tt0109830/" id="tt0109830">
        <name>Forest Gump</name>
        <characters>Forest &amp; Jenny</characters>
      </movie>
    </menu>
    """

    assert {:ok, simple_form} = xml |> remove_indents() |> Saxy.SimpleForm.parse_string()

    assert {"menu", [], elements} = simple_form

    assert [first_element | elements] = elements
    assert {"movie", [{"url", "https://www.imdb.com/title/tt0120338/"}, {"id", "tt0120338"}], first_children} = first_element
    assert first_children == [{"name", [], ["Titanic"]}, {"characters", [], ["Jack & Rose"]}]

    assert [second_element] = elements
    assert {"movie", [{"url", "https://www.imdb.com/title/tt0109830/"}, {"id", "tt0109830"}], second_children} = second_element
    assert second_children == [{"name", [], ["Forest Gump"]}, {"characters", [], ["Forest & Jenny"]}]
  end

  test "parses a sample XML" do
    xml = File.read!("./test/support/fixture/food.xml")

    assert {:ok, simple_form} = Saxy.SimpleForm.parse_string(xml)

    assert {"breakfast_menu", [], children} = simple_form
    assert length(children) == 11
  end

  test "parses XML document with customized entity handler" do
    xml = """
    <?xml version="1.0" encoding="utf-8" ?>
    <menu>
      <movie url="https://www.imdb.com/title/tt0120338/" id="tt0120338">
        <name>Titanic</name>
        <characters>Jack &amp; Rose &reg;</characters>
      </movie>
      <movie url="https://www.imdb.com/title/tt0109830/" id="tt0109830">
        <name>Forest Gump</name>
        <characters>Forest &amp; Jenny</characters>
      </movie>
    </menu>
    """

    assert {:ok, simple_form} =
             xml
             |> remove_indents()
             |> Saxy.SimpleForm.parse_string(expand_entity: {__MODULE__, :handle_entity_reference, []})

    assert {"menu", [], elements} = simple_form

    assert [first_element | elements] = elements
    assert {"movie", [{"url", "https://www.imdb.com/title/tt0120338/"}, {"id", "tt0120338"}], first_children} = first_element
    assert first_children == [{"name", [], ["Titanic"]}, {"characters", [], ["Jack & Rose ®"]}]

    assert [second_element] = elements
    assert {"movie", [{"url", "https://www.imdb.com/title/tt0109830/"}, {"id", "tt0109830"}], second_children} = second_element
    assert second_children == [{"name", [], ["Forest Gump"]}, {"characters", [], ["Forest & Jenny"]}]
  end

  test "handles CData" do
    xml = """
    <?xml version="1.0" encoding="utf-8" ?>
    <foo><![CDATA[<greeting>Hello, world!</greeting>]]></foo>
    """

    assert {:ok, simple_form} =
             xml
             |> remove_indents()
             |> Saxy.SimpleForm.parse_string(cdata_as_characters: false)

    assert simple_form == {"foo", [], [{:cdata, "<greeting>Hello, world!</greeting>"}]}

    assert {:ok, simple_form} =
             xml
             |> remove_indents()
             |> Saxy.SimpleForm.parse_string(cdata_as_characters: false)

    assert simple_form == {"foo", [], [{:cdata, "<greeting>Hello, world!</greeting>"}]}
  end

  def handle_entity_reference("reg") do
    "®"
  end
end
