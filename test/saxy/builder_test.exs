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

  test "builds datetime" do
    date = ~D[2018-03-01]
    assert build(date) == {:characters, "2018-03-01"}

    time = ~T[20:18:11.023]
    assert build(time) == {:characters, "20:18:11.023"}

    {:ok, naive_datetime} = NaiveDateTime.new(~D[2018-01-01], ~T[23:04:00.005])
    assert build(naive_datetime) == {:characters, "2018-01-01T23:04:00.005"}

    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    assert build(datetime) == {:characters, "2018-01-01T23:04:00.005Z"}
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
    assert build(struct) == {"test", [{"foo", "foo"}], [{:characters, "bar"}]}

    nested_struct = %Struct{bar: struct}

    assert build(nested_struct) ==
             {"test", [{"foo", ""}], [{"test", [{"foo", "foo"}], [{:characters, "bar"}]}]}

    underived_struct = %UnderivedStruct{}
    assert_raise Protocol.UndefinedError, fn -> build(underived_struct) end
  end

  @tag :property

  property "number" do
    check all integer <- integer() do
      assert build(integer) == {:characters, Integer.to_string(integer)}
    end

    check all float <- float() do
      assert build(float) == {:characters, Float.to_string(float)}
    end
  end

  property "bitstring" do
    check all string <- string(:printable) do
      assert build(string) == {:characters, string}
    end
  end

  property "atom" do
    assert build(nil) == {:characters, ""}

    check all atom <- atom(:alphanumeric) do
      assert build(atom) == {:characters, Atom.to_string(atom)}
    end
  end
end
