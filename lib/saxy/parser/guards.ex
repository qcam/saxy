defmodule Saxy.Guards do
  defguard is_whitespace(charcode)
           when charcode in [0xA, 0x9, 0xD, 0x20]

  defguard is_name_start_char(charcode)
           when charcode == ?: or (charcode >= ?A and charcode <= ?Z) or
                charcode == ?_ or (charcode >= ?a and charcode <= ?z) or
                (charcode >= 0xC0 and charcode <= 0xD6) or (charcode >= 0xD8 and charcode <= 0xF6) or
                (charcode >= 0xF8 and charcode <= 0x2FF) or (charcode >= 0x370 and charcode <= 0x37D) or
                (charcode >= 0x37F and charcode <= 0x1FFF) or (charcode >= 0x200C and charcode <= 0x200D) or
                (charcode >= 0x2070 and charcode <= 0x218F) or (charcode >= 0x2C00 and charcode <= 0x2FEF) or
                (charcode >= 0x3001 and charcode <= 0xD7FF) or (charcode >= 0xF900 and charcode <= 0xFDCF) or
                (charcode >= 0xFDF0 and charcode <= 0xFFFD) or (charcode >= 0x10000 and charcode <= 0xEFFFF)

  defguard is_name_char(charcode)
           when (charcode >= ?0 and charcode <= ?9) or charcode in [?-, ?., 0xB7] or
                is_name_start_char(charcode) or (charcode >= 0x0300 and charcode <= 0x036F) or
                        (charcode >= 0x203F and charcode <= 0x2040)
end

