defmodule Saxy.XmerlTest do
  use ExUnit.Case, async: true

  import Saxy.Xmerl.Records

  doctest Saxy.Xmerl

  test "parses simple XML document" do
    xml = """
    <?xml version="1.0"?>
    <foo foo1="foo1" foo2="foo2"><bar bar1="bar1" bar2="bar2"/><baz baz1="baz1" baz2="baz2"/></foo>
    """

    assert {:ok, foo} = parse(xml)

    assert xmlElement(foo, :name) == :foo
    assert [foo1, foo2] = xmlElement(foo, :attributes)

    assert xmlAttribute(foo1, :name) == :foo1
    assert xmlAttribute(foo1, :pos) == 1
    assert xmlAttribute(foo1, :value) == 'foo1'

    assert xmlAttribute(foo2, :name) == :foo2
    assert xmlAttribute(foo2, :pos) == 2
    assert xmlAttribute(foo2, :value) == 'foo2'

    assert [bar, baz] = xmlElement(foo, :content)

    assert xmlElement(bar, :name) == :bar
    assert xmlElement(bar, :pos) == 1
    assert [bar1, bar2] = xmlElement(bar, :attributes)

    assert xmlAttribute(bar1, :name) == :bar1
    assert xmlAttribute(bar1, :pos) == 1
    assert xmlAttribute(bar1, :value) == 'bar1'

    assert xmlAttribute(bar2, :name) == :bar2
    assert xmlAttribute(bar2, :pos) == 2
    assert xmlAttribute(bar2, :value) == 'bar2'

    assert xmlElement(baz, :name) == :baz
    assert xmlElement(baz, :pos) == 2
    assert [baz1, baz2] = xmlElement(baz, :attributes)

    assert xmlAttribute(baz1, :name) == :baz1
    assert xmlAttribute(baz1, :pos) == 1
    assert xmlAttribute(baz1, :value) == 'baz1'

    assert xmlAttribute(baz2, :name) == :baz2
    assert xmlAttribute(baz2, :pos) == 2
    assert xmlAttribute(baz2, :value) == 'baz2'
  end

  test "parses simply nested XML document" do
    xml = """
    <?xml version="1.0"?>
    <foo foo1="foo1" foo2="foo2"><bar bar1="bar1" bar2="bar2"><baz baz1="baz1" baz2="baz2"></baz></bar></foo>
    """

    assert {:ok, foo} = parse(xml)

    assert xmlElement(foo, :name) == :foo
    assert [foo1, foo2] = xmlElement(foo, :attributes)

    assert xmlAttribute(foo1, :name) == :foo1
    assert xmlAttribute(foo1, :pos) == 1
    assert xmlAttribute(foo1, :value) == 'foo1'

    assert xmlAttribute(foo2, :name) == :foo2
    assert xmlAttribute(foo2, :pos) == 2
    assert xmlAttribute(foo2, :value) == 'foo2'

    assert [bar] = xmlElement(foo, :content)

    assert xmlElement(bar, :name) == :bar
    assert xmlElement(bar, :pos) == 1
    assert [bar1, bar2] = xmlElement(bar, :attributes)

    assert xmlAttribute(bar1, :name) == :bar1
    assert xmlAttribute(bar1, :pos) == 1
    assert xmlAttribute(bar1, :value) == 'bar1'

    assert xmlAttribute(bar2, :name) == :bar2
    assert xmlAttribute(bar2, :pos) == 2
    assert xmlAttribute(bar2, :value) == 'bar2'

    assert [baz] = xmlElement(bar, :content)

    assert xmlElement(baz, :name) == :baz
    assert xmlElement(baz, :pos) == 1
    assert [baz1, baz2] = xmlElement(baz, :attributes)

    assert xmlAttribute(baz1, :name) == :baz1
    assert xmlAttribute(baz1, :pos) == 1
    assert xmlAttribute(baz1, :value) == 'baz1'

    assert xmlAttribute(baz2, :name) == :baz2
    assert xmlAttribute(baz2, :pos) == 2
    assert xmlAttribute(baz2, :value) == 'baz2'
  end

  test "parses XML with text" do
    xml = """
    <?xml version="1.0"?>
    <foo>FOO<bar>BAR<baz>BAZ</baz>BAR</bar>FOO</foo>
    """

    assert {:ok, foo} = parse(xml)

    assert xmlElement(foo, :name) == :foo
    assert xmlElement(foo, :pos) == 1
    assert xmlElement(foo, :attributes) == []

    assert [foo1, bar, foo2] = xmlElement(foo, :content)
    assert foo1 == xmlText(value: 'FOO')
    assert foo2 == xmlText(value: 'FOO')

    assert xmlElement(bar, :name) == :bar
    assert xmlElement(bar, :pos) == 1
    assert xmlElement(bar, :attributes) == []

    assert [bar1, baz, bar2] = xmlElement(bar, :content)

    assert bar1 == xmlText(value: 'BAR')
    assert bar2 == xmlText(value: 'BAR')

    assert xmlElement(baz, :name) == :baz
    assert xmlElement(baz, :pos) == 1
    assert xmlElement(baz, :attributes) == []

    assert xmlElement(baz, :content) == [xmlText(value: 'BAZ')]
  end

  describe "SweetXML integration" do
    import SweetXml, only: [xmap: 2, xpath: 3, sigil_x: 2]

    test "maps match.xml" do
      xml = File.read!("test/support/fixture/sweet_xml/match.xml")
      assert {:ok, document} = parse(xml, atom_fun: &String.to_atom/1)

      result =
        document
        |> xpath(
          ~x"//matchups/matchup"l,
          name: ~x"./name/text()",
          winner: [
            ~x".//team/id[.=ancestor::matchup/@winner-id]/..",
            name: ~x"./name/text()"
          ]
        )

      assert result == [
               %{name: 'Match One', winner: %{name: 'Team One'}},
               %{name: 'Match Two', winner: %{name: 'Team Two'}},
               %{name: 'Match Three', winner: %{name: 'Team One'}}
             ]
    end

    test "maps yahoo_fantasy.xml" do
      xml = File.read!("test/support/fixture/sweet_xml/yahoo_fantasy.xml")

      assert {:ok, document} = parse(xml, atom_fun: &String.to_atom/1)

      result =
        xmap(
          document,
          matchups: [
            ~x"//matchups/matchup/is_tied[contains(., '0')]/.."l,
            week: ~x"./week/text()",
            winner: [
              ~x"./teams/team/team_key[.=ancestor::matchup/winner_team_key]/..",
              name: ~x"./name/text()",
              key: ~x"./team_key/text()"
            ],
            loser: [
              ~x"./teams/team/team_key[.!=ancestor::matchup/winner_team_key]/..",
              name: ~x"./name/text()",
              key: ~x"./team_key/text()"
            ],
            teams: [
              ~x"./teams/team"l,
              name: ~x"./name/text()",
              key: ~x"./team_key/text()"
            ]
          ]
        )

      assert result == %{
               matchups: [
                 %{
                   week: '16',
                   winner: %{name: 'Asgardian Warlords', key: '273.l.239541.t.1'},
                   loser: %{name: 'yourgoindown220', key: '273.l.239541.t.2'},
                   teams: [
                     %{name: 'Asgardian Warlords', key: '273.l.239541.t.1'},
                     %{name: 'yourgoindown220', key: '273.l.239541.t.2'}
                   ]
                 },
                 %{
                   week: '16',
                   winner: %{name: '187 she wrote', key: '273.l.239541.t.4'},
                   loser: %{name: 'bleedgreen', key: '273.l.239541.t.6'},
                   teams: [
                     %{name: '187 she wrote', key: '273.l.239541.t.4'},
                     %{name: 'bleedgreen', key: '273.l.239541.t.6'}
                   ]
                 },
                 %{
                   week: '16',
                   winner: %{name: 'jo momma', key: '273.l.239541.t.9'},
                   loser: %{name: 'Thunder Ducks', key: '273.l.239541.t.5'},
                   teams: [
                     %{name: 'Thunder Ducks', key: '273.l.239541.t.5'},
                     %{name: 'jo momma', key: '273.l.239541.t.9'}
                   ]
                 },
                 %{
                   week: '16',
                   winner: %{name: 'The Dude Abides', key: '273.l.239541.t.10'},
                   loser: %{name: 'bingo_door', key: '273.l.239541.t.8'},
                   teams: [
                     %{name: 'bingo_door', key: '273.l.239541.t.8'},
                     %{name: 'The Dude Abides', key: '273.l.239541.t.10'}
                   ]
                 }
               ]
             }
    end
  end

  defp parse(xml, options \\ []) do
    Saxy.Xmerl.parse_string(xml, options)
  end
end
