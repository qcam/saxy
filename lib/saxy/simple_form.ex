defmodule Saxy.SimpleForm do
  @moduledoc ~S"""
  This provides function(s) to parse a XML document to
  [simple-form](http://erlang.org/doc/man/xmerl.html#export_simple-3) data structure.

  ## Simple Form data structure

  Simple form is a basic representation of the parsed XML document. It contains a root
  element, and all elements are in the following format:

  ```
  element = {tag_name, attributes, content}
  content = (element | binary)*
  ```

  ## Example

  Given this XML document.

  ```
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
  </menu>)
  ```

      iex> {:ok, simple_form} = Saxy.SimpleForm.parse_string(xml)

      [
        {"menu", [],
         [
           {"movie",
            [{"id", "tt0120338"}, {"url", "https://www.imdb.com/title/tt0120338/"}],
            [{"name", [], ["Titanic"]}, {"characters", [], ["Jack &amp; Rose"]}]},
           {"movie",
            [{"id", "tt0109830"}, {"url", "https://www.imdb.com/title/tt0109830/"}],
            [
              {"name", [], ["Forest Gump"]},
              {"characters", [], ["Forest &amp; Jenny"]}
            ]}
         ]}
      ]

  """

  @spec parse_string(data :: binary, options :: Keyword.t()) ::
          {:ok, term} | {:error, exception :: Saxy.ParseError.t() | Saxy.HandlerError.t()}

  def parse_string(data, options \\ []) when is_binary(data) do
    case Saxy.parse_string(data, __MODULE__.Handler, {[], options}, options) do
      {:ok, {stack, _options}} -> {:ok, stack}
      {:error, _reason} = error -> error
    end
  end
end
