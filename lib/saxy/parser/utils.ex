defmodule Saxy.Parser.Utils do
  alias Saxy.{
    Entities,
    HandlerError,
    ParseError,
  }

  def syntax_error(<<>>, _state, token) do
    {:error, %ParseError{reason: {:syntax, token}, next_byte: :eof}}
  end

  def syntax_error(<<byte::utf8, _::bits>>, _state, token) do
    {:error, %ParseError{reason: {:syntax, token}, next_byte: <<byte::utf8>>}}
  end

  @compile {:inline, [convert_entity_ref: 1]}

  def convert_entity_ref(name) do
    Entities.convert(name)
  end

  @compile {:inline, [compute_char_len: 1]}

  def compute_char_len(char) do
    cond do
      char <= 0x7F -> 1
      char <= 0x7FF -> 2
      char <= 0xFFFF -> 3
      true -> 4
    end
  end

  def bad_return_error(reason) do
    {:error, %HandlerError{reason: {:bad_return, reason}}}
  end

  @compile {:inline, [valid_pi_name?: 1]}

  def valid_pi_name?(<<l::integer, m::integer, x::integer>>)
       when x in [?X, ?x] or m in [?M, ?m] or l in [?L, ?l], do: false

  def valid_pi_name?(<<_::bits>>), do: true
end
