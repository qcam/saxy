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

  # Maximum number of digits allowed in a numeric character reference. The
  # largest valid code point is U+10FFFF, which needs 7 decimal / 6 hexadecimal
  # digits; the extra budget tolerates a few leading zeros while still bounding
  # the integer we hand to `String.to_integer/2`, preventing huge-bignum DoS.
  @max_decimal_char_ref_digits 10
  @max_hexadecimal_char_ref_digits 8

  @doc """
  Parses the digits of a numeric character reference into a code point.

  `base` is `10` for `&#...;` or `16` for `&#x...;`. Returns `{:ok, codepoint}`
  for a valid XML character, or `{:error, reason}` (a `Saxy.ParseError` reason)
  when there are too many digits or the code point is not a valid XML `Char`.
  """
  def parse_char_ref(digits, base) do
    max_digits =
      case base do
        10 -> @max_decimal_char_ref_digits
        16 -> @max_hexadecimal_char_ref_digits
      end

    if byte_size(digits) > max_digits do
      {:error, {:invalid_char_ref, :too_long}}
    else
      codepoint = String.to_integer(digits, base)

      if valid_char_ref?(codepoint) do
        {:ok, codepoint}
      else
        {:error, {:invalid_char_ref, codepoint}}
      end
    end
  end

  @compile {:inline, [valid_char_ref?: 1]}

  # Returns `true` when the code point is a valid XML 1.0 `Char`, ordered with
  # the common printable BMP range first. See https://www.w3.org/TR/xml/#NT-Char
  # — this excludes NUL and other disallowed control characters, the surrogate
  # range (U+D800–U+DFFF), U+FFFE, U+FFFF, and anything beyond U+10FFFF.
  defp valid_char_ref?(codepoint) do
    (codepoint >= 0x20 and codepoint <= 0xD7FF) or
      codepoint == 0x9 or codepoint == 0xA or codepoint == 0xD or
      (codepoint >= 0xE000 and codepoint <= 0xFFFD) or
      (codepoint >= 0x10000 and codepoint <= 0x10FFFF)
  end

  def valid_pi_name?(<<l::integer, m::integer, x::integer>>)
      when x in [?X, ?x] or m in [?M, ?m] or l in [?L, ?l],
      do: false

  def valid_pi_name?(<<_::bits>>), do: true

  def valid_encoding?(encoding) do
    String.upcase(encoding, :ascii) == "UTF-8"
  end
end
