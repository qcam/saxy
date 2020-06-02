defmodule Saxy.Encoder do
  @moduledoc false

  def encode_to_iodata(root, prolog) do
    prolog = prolog(prolog)
    element = element(root)

    [prolog | element]
  end

  defp prolog(%Saxy.Prolog{} = prolog) do
    ['<?xml', version(prolog.version), encoding(prolog.encoding), standalone(prolog.standalone), '?>']
  end

  defp prolog(prolog) when is_list(prolog) do
    prolog
    |> Saxy.Prolog.from_keyword()
    |> prolog()
  end

  defp prolog(nil), do: []

  defp version(version) when is_binary(version) do
    [?\s, 'version', ?=, ?", version, ?"]
  end

  defp encoding(nil), do: []

  defp encoding(:utf8) do
    [?\s, 'encoding', ?=, ?", 'utf-8', ?"]
  end

  defp standalone(nil), do: []

  defp standalone(true) do
    [?\s, 'standalone', ?=, ?", "yes", ?"]
  end

  defp element({tag_name, attributes, []}) do
    [start_tag(tag_name, attributes), ?/, ?>]
  end

  defp element({tag_name, attributes, contents}) do
    [
      start_tag(tag_name, attributes),
      ?>,
      content(contents),
      end_tag(tag_name, contents)
    ]
  end

  defp start_tag(tag_name, attributes) do
    [?<, tag_name | attributes(attributes)]
  end

  defp attributes([]), do: []

  defp attributes([{name, value} | attributes]) do
    [?\s, name, ?=, ?", escape(value, 0, value), ?" | attributes(attributes)]
  end

  defp content([]), do: []

  defp content([{:characters, characters} | elements]) do
    [characters(characters) | content(elements)]
  end

  defp content([{:cdata, cdata} | elements]) do
    [cdata(cdata) | content(elements)]
  end

  defp content([{:reference, reference} | elements]) do
    [reference(reference) | content(elements)]
  end

  defp content([{:comment, comment} | elements]) do
    [comment(comment) | content(elements)]
  end

  defp content([{:processing_instruction, name, content} | elements]) do
    [processing_instruction(name, content) | content(elements)]
  end

  defp content([characters | elements]) when is_binary(characters) do
    [characters | content(elements)]
  end

  defp content([element | elements]) do
    [element(element) | content(elements)]
  end

  defp end_tag(tag_name, _other) do
    [?<, ?/, tag_name, ?>]
  end

  defp characters(characters) do
    escape(characters, 0, characters)
  end

  @escapes [
    {?<, '&lt;'},
    {?>, '&gt;'},
    {?&, '&amp;'},
    {?", '&quot;'},
    {?', '&apos;'}
  ]

  for {match, insert} <- @escapes do
    defp escape(<<unquote(match), rest::bits>>, len, original) do
      [binary_part(original, 0, len), unquote(insert) | escape(rest, 0, rest)]
    end
  end

  defp escape(<<>>, _len, original) do
    original
  end

  defp escape(<<_, rest::bits>>, len, original) do
    escape(rest, len + 1, original)
  end

  defp cdata(characters) do
    ['<![CDATA[', characters | ']]>']
  end

  defp reference({:entity, reference}) do
    [?&, reference, ?;]
  end

  defp reference({:hexadecimal, reference}) do
    [?&, ?x, Integer.to_string(reference, 16), ?;]
  end

  defp reference({:decimal, reference}) do
    [?&, ?x, Integer.to_string(reference, 10), ?;]
  end

  defp comment(comment) do
    ['<!--', escape_comment(comment, comment) | '-->']
  end

  defp escape_comment(<<?->>, original) do
    [original, ?\s]
  end

  defp escape_comment(<<>>, original) do
    original
  end

  defp escape_comment(<<_char, rest::bits>>, original) do
    escape_comment(rest, original)
  end

  defp processing_instruction(name, content) do
    ['<?', name, ?\s, content | '?>']
  end
end
