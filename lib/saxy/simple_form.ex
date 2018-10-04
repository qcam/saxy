defmodule Saxy.SimpleForm do
  @moduledoc ~S"""
  Provides functions to parse a XML document to
  [simple-form](http://erlang.org/doc/man/xmerl.html#export_simple-3) data structure.

  ## Data structure

  Simple form is a basic representation of the parsed XML document. It contains a root
  element, and all elements are in the following format:

  ```
  element = {tag_name, attributes, content}
  content = (element | binary)*
  ```

  See "Types" section for more information.

  """

  @doc """
  Parse given string into simple form.

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
      iex> Saxy.SimpleForm.parse_string(xml)
      {:ok,
       {"menu", [],
        [
          {"movie",
           [
             {"url", "https://www.imdb.com/title/tt0120338/"},
             {"id", "tt0120338"}
           ],
           [{"name", [], ["Titanic"]}, {"characters", [], ["Jack & Rose"]}]},
          {"movie",
           [
             {"url", "https://www.imdb.com/title/tt0109830/"},
             {"id", "tt0109830"}
           ],
           [
             {"name", [], ["Forest Gump"]},
             {"characters", [], ["Forest & Jenny"]}
           ]}
        ]}}

  """

  @type tag_name() :: String.t()

  @type attributes() :: [{name :: String.t(), value :: String.t()}]

  @type content() :: [String.t() | Saxy.SimpleForm.t()]

  @type t() :: {tag_name(), attributes(), content()}

  @spec parse_string(data :: binary, options :: Keyword.t()) ::
          {:ok, Saxy.SimpleForm.t()} :: {:error, exception :: Saxy.ParseError.t()}

  def parse_string(data, options \\ []) when is_binary(data) do
    case Saxy.parse_string(data, __MODULE__.Handler, {[], options}, options) do
      {:ok, {[document], _options}} ->
        {:ok, document}

      {:error, _reason} = error ->
        error
    end
  end
end
