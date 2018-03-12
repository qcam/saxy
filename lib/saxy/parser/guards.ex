defmodule Saxy.Guards do
  @moduledoc false

  # TODO: Use defguard when supporting Elixir 1.6+.

  defmacro is_whitespace(charcode) do
    quote do
      unquote(charcode) in [0xA, 0x9, 0xD, 0x20]
    end
  end

  defmacro is_name_start_char(charcode) do
    quote do
      unquote(charcode) == ?: or (unquote(charcode) >= ?A and unquote(charcode) <= ?Z) or
      unquote(charcode) == ?_ or (unquote(charcode) >= ?a and unquote(charcode) <= ?z) or
      (unquote(charcode) >= 0xC0 and unquote(charcode) <= 0xD6) or (unquote(charcode) >= 0xD8 and unquote(charcode) <= 0xF6) or
      (unquote(charcode) >= 0xF8 and unquote(charcode) <= 0x2FF) or (unquote(charcode) >= 0x370 and unquote(charcode) <= 0x37D) or
      (unquote(charcode) >= 0x37F and unquote(charcode) <= 0x1FFF) or (unquote(charcode) >= 0x200C and unquote(charcode) <= 0x200D) or
      (unquote(charcode) >= 0x2070 and unquote(charcode) <= 0x218F) or (unquote(charcode) >= 0x2C00 and unquote(charcode) <= 0x2FEF) or
      (unquote(charcode) >= 0x3001 and unquote(charcode) <= 0xD7FF) or (unquote(charcode) >= 0xF900 and unquote(charcode) <= 0xFDCF) or
      (unquote(charcode) >= 0xFDF0 and unquote(charcode) <= 0xFFFD) or (unquote(charcode) >= 0x10000 and unquote(charcode) <= 0xEFFFF)
    end
  end

  defmacro is_name_char(charcode) do
    quote do
      (unquote(charcode) >= ?0 and unquote(charcode) <= ?9) or unquote(charcode) in [?-, ?., 0xB7] or
      is_name_start_char(unquote(charcode)) or (unquote(charcode) >= 0x0300 and unquote(charcode) <= 0x036F) or
      (unquote(charcode) >= 0x203F and unquote(charcode) <= 0x2040)
    end
  end
end

