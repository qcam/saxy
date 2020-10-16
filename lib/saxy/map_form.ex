defmodule Saxy.MapForm do
  alias Saxy.MapForm.Handler

  @moduledoc ~S"""
  Provides functions to parse an XML document to a simple map based data structure.

  ## Data structure

  Map based basic representation of the parsed XML document. It contains a root
  element, and all elements are in the following format:

  ```
  element = %{name: binary, attrs: list, ord: integer, text: binary}
    - where each element also has binary keys that point to child elements
  ```
  """

  @doc """
  Parse given string/stream into map form.

  ## Options

  * `:expand_entity` - specifies how external entity references should be handled. Three supported strategies respectively are:
    * `:keep` - keep the original binary, for example `Orange &reg;` will be expanded to `"Orange &reg;"`, this is the default strategy.
    * `:skip` - skip the original binary, for example `Orange &reg;` will be expanded to `"Orange "`.
    * `{mod, fun, args}` - take the applied result of the specified MFA.

  ## Examples

  Given this XML document.

      iex> xml = \"\"\"
      ...> <?xml version="1.0" encoding="utf-8" ?>
      ...> <menu>
      ...>   <movie url="https://www.imdb.com/title/tt0120338/" id="tt0120338">
      ...>     <name>Titanic</name>
      ...>     <characters>Jack &amp; Rose</characters>
      ...>   </movie>
      ...>   <movie url="https://www.imdb.com/title/tt0109830/" id="tt0109830">
      ...>     <name>Forest Gump</name>
      ...>     <characters>Forest &amp; Jenny</characters>
      ...>   </movie>
      ...> </menu>
      ...> \"\"\"
      iex> {:ok, doc} = Saxy.MapForm.parse_string(xml)
      {:ok,
        %{
          "menu" => %{
            :attrs => [],
            :name => "menu",
            :ord => 0,
            :text => nil,
            "movie" => [
              %{
                :attrs => [
                  {"url", "https://www.imdb.com/title/tt0109830/"},
                  {"id", "tt0109830"}
                ],
                :name => "movie",
                :ord => 1,
                :text => nil,
                "characters" => %{
                  attrs: [],
                  name: "characters",
                  ord: 0,
                  text: "Forest & Jenny"
                },
                "name" => %{attrs: [], name: "name", ord: 0, text: "Forest Gump"}
              },
              %{
                :attrs => [
                  {"url", "https://www.imdb.com/title/tt0120338/"},
                  {"id", "tt0120338"}
                ],
                :name => "movie",
                :ord => 0,
                :text => nil,
                "characters" => %{
                  attrs: [],
                  name: "characters",
                  ord: 0,
                  text: "Jack & Rose"
                },
                "name" => %{attrs: [], name: "name", ord: 0, text: "Titanic"}
              }
            ]
          }
        }}
      iex> get_in(doc, ["menu", "movie"]) |> Enum.find(& &1["name"].text == "Forest Gump")
      %{
        :attrs => [
          {"url", "https://www.imdb.com/title/tt0109830/"},
          {"id", "tt0109830"}
        ],
        :name => "movie",
        :ord => 1,
        :text => nil,
        "characters" => %{
          attrs: [],
          name: "characters",
          ord: 0,
          text: "Forest & Jenny"
        },
        "name" => %{attrs: [], name: "name", ord: 0, text: "Forest Gump"}
      }

  """
  @spec parse_string(binary, keyword) :: {:ok, map} | {:error, Saxy.ParseError.t()} | {:halt, any, binary}
  def parse_string(string, options \\ []) when is_binary(string) do
    case Saxy.parse_string(string, Handler, %Handler.State{}, options) do
      {:ok, %{elems: doc}} -> {:ok, doc}
      error -> error
    end
  end

  @spec parse_stream(any, keyword) :: {:ok, map} | {:error, Saxy.ParseError.t()} | {:halt, any, binary}
  def parse_stream(stream, options \\ []) do
    case Saxy.parse_stream(stream, Handler, %Handler.State{}, options) do
      {:ok, %{elems: doc}} -> {:ok, doc}
      error -> error
    end
  end
end
