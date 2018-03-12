defmodule Saxy.Parser do
  import Saxy.Parser.Prolog, only: [parse_prolog: 5]

  def parse_document(<<buffer::bits>>, cont, state) do
    case parse_prolog(buffer, cont, buffer, 0, state) do
      {:ok, state} ->
        {:ok, state.user_state}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
