defmodule Saxy.Guards do
  @moduledoc false

  defguard is_ascii(codepoint) when codepoint <= 0x7F

  defguard is_whitespace(codepoint) when codepoint in [0xA, 0x9, 0xD, 0x20]

  defguard is_ascii_name_start_char(codepoint)
           when codepoint == ?: or
                  (codepoint >= ?A and codepoint <= ?Z) or
                  codepoint == ?_ or (codepoint >= ?a and codepoint <= ?z)

  defguard is_utf8_name_start_char(codepoint)
           when (codepoint >= 0xC0 and codepoint <= 0xD6) or
                  (codepoint >= 0xD8 and codepoint <= 0xF6) or (codepoint >= 0xF8 and codepoint <= 0x2FF) or
                  (codepoint >= 0x370 and codepoint <= 0x37D) or
                  (codepoint >= 0x37F and codepoint <= 0x1FFF) or
                  (codepoint >= 0x200C and codepoint <= 0x200D) or
                  (codepoint >= 0x2070 and codepoint <= 0x218F) or
                  (codepoint >= 0x2C00 and codepoint <= 0x2FEF) or
                  (codepoint >= 0x3001 and codepoint <= 0xD7FF) or
                  (codepoint >= 0xF900 and codepoint <= 0xFDCF) or
                  (codepoint >= 0xFDF0 and codepoint <= 0xFFFD) or
                  (codepoint >= 0x10000 and codepoint <= 0xEFFFF)

  defguard is_ascii_name_char(codepoint)
           when (codepoint >= ?0 and codepoint <= ?9) or codepoint in [?-, ?.] or
                  is_ascii_name_start_char(codepoint)

  defguard is_utf8_name_char(codepoint)
           when codepoint == 0xB7 or
                  is_utf8_name_start_char(codepoint) or (codepoint >= 0x0300 and codepoint <= 0x036F) or
                  (codepoint >= 0x203F and codepoint <= 0x2040)
end
