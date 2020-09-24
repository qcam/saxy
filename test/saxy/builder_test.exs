defmodule Saxy.BuilderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Saxy.Builder, only: [build: 1]

  doctest Saxy.Builder

  test "builds pre-built simple-form element" do
    element = Saxy.XML.element(:foo, [], [])
    assert build(element) == element

    element = Saxy.XML.empty_element(:foo, [])
    assert build(element) == element

    characters = Saxy.XML.characters("foo")
    assert build(characters) == characters

    cdata = Saxy.XML.cdata("foo")
    assert build(cdata) == cdata

    reference = Saxy.XML.reference(:entity, "foo")
    assert build(reference) == reference

    comment = Saxy.XML.comment("foo")
    assert build(comment) == comment

    assert_raise Protocol.UndefinedError, fn -> build({}) end
  end

  defmodule Struct do
    @derive {Saxy.Builder, name: :test, attributes: [:foo], children: [:bar]}

    defstruct [:foo, :bar]
  end

  defmodule UnderivedStruct do
    defstruct [:foo, :bar]
  end

  test "builds element from struct" do
    struct = %Struct{foo: "foo", bar: "bar"}
    assert build(struct) == {"test", [{"foo", "foo"}], ["bar"]}

    nested_struct = %Struct{bar: struct}

    assert build(nested_struct) == {"test", [{"foo", ""}], [{"test", [{"foo", "foo"}], ["bar"]}]}

    underived_struct = %UnderivedStruct{}
    assert_raise Protocol.UndefinedError, fn -> build(underived_struct) end
  end
end
