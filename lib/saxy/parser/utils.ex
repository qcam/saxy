defmodule Saxy.Parser.Utils do
  @moduledoc false

  alias Saxy.ParseError

  def parse_error(buffer, position, _state, reason) do
    {
      :error,
      %ParseError{
        reason: reason,
        binary: buffer,
        position: position
      }
    }
  end

  def bad_return_error(return) do
    {
      :error,
      %ParseError{
        reason: {:bad_return, return}
      }
    }
  end

  def compute_char_len(char) do
    cond do
      char <= 0x7F -> 1
      char <= 0x7FF -> 2
      char <= 0xFFFF -> 3
      true -> 4
    end
  end

  def valid_pi_name?(<<l::integer, m::integer, x::integer>>)
      when x in [?X, ?x] or m in [?M, ?m] or l in [?L, ?l],
      do: false

  def valid_pi_name?(<<_::bits>>), do: true

  def valid_encoding?(encoding) do
    String.upcase(encoding, :ascii) == "UTF-8"
  end
end
