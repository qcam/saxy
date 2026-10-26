defmodule Saxy.Parser.Lookahead do
  @moduledoc false

  def edge_ngrams(word) do
    {grams, _} =
      word
      |> String.to_charlist()
      |> Enum.flat_map_reduce("", fn char, last_word ->
        last_word = last_word <> <<char>>
        {[last_word], last_word}
      end)

    grams ++ [""]
  end

  defmacro lookahead(data, streaming?, do: rules) do
    streaming? = Macro.expand(streaming?, __CALLER__)

    clauses =
      rules
      |> Enum.flat_map(fn {:->, _, [clause, code]} -> build_clause(clause, code, streaming?) end)
      |> sink_empty_halts([])

    quote do
      case unquote(data) do
        unquote(clauses)
      end
    end
  end

  # Moves empty-buffer halts below the clauses that need a byte, which they
  # would otherwise split into groups the compiler matches one after another.
  defp sink_empty_halts([{:empty_halt, clause} | rest], held), do: sink_empty_halts(rest, [clause | held])
  defp sink_empty_halts([{:byte, clause} | rest], held), do: [clause | sink_empty_halts(rest, held)]
  defp sink_empty_halts([{:any, clause} | rest], held), do: Enum.reverse(held, [clause | sink_empty_halts(rest, [])])
  defp sink_empty_halts([], held), do: Enum.reverse(held)

  # "binary" <> rest.
  defp build_clause([{:<>, _, [ahead, rest]}], code, _streaming?) do
    quote do
      <<unquote(ahead), unquote(rest)::bits>> -> unquote(code)
    end
    |> tag(if ahead == "", do: :any, else: :byte)
  end

  defp build_clause([{:when, _, [left, guards]}], code, streaming?) do
    case left do
      # "in" is exclusively used in streaming.
      {:in, _, [token_var, tokens]} ->
        if streaming? do
          Enum.flat_map(tokens, fn token ->
            quote do
              unquote(token) when unquote(guards) ->
                unquote(token_var) = unquote(token)
                unquote(code)
            end
            |> tag(if token == "", do: :empty_halt, else: :byte)
          end)
        else
          []
        end

      # char <> rest when is_whitespace(char).
      {:<>, _, [ahead, rest]} ->
        quote do
          <<unquote(ahead), unquote(rest)::bits>> when unquote(guards) ->
            unquote(code)
        end
        |> tag(if ahead == "", do: :any, else: :byte)
    end
  end

  defp build_clause([other], code, _streaming?) do
    quote do
      unquote(other) -> unquote(code)
    end
    |> tag(:any)
  end

  defp tag(clauses, kind), do: Enum.map(clauses, &{kind, &1})
end
