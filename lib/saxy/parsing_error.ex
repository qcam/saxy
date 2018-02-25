defmodule Saxy.ParsingError do
  @type t :: %__MODULE__{
          reason:
            {:bad_syntax, any}
            | {:wrong_closing_tag, {binary, binary}}
            | {:invalid_return, any}
        }

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    {error_type, term} = exception.reason

    format_message(error_type, term)
  end

  defp format_message(:bad_syntax, {mismatched_rule, {buffer, position}})
       when byte_size(buffer) == position do
    "unexpected byte at end of input, expected: #{inspect(mismatched_rule)}"
  end

  defp format_message(:bad_syntax, {mismatched_rule, {buffer, position}}) do
    byte = :binary.at(buffer, position)
    char = <<byte>>

    "unexpected byte #{inspect(char)}, expected: #{inspect(mismatched_rule)}"
  end

  defp format_message(:wrong_closing_tag, {open_tag, end_tag}) do
    "unexpected closing tag #{inspect(end_tag)}, expected: #{inspect(open_tag)}"
  end

  defp format_message(:invalid_return, return) do
    "unexpected value returned by handler: #{inspect(return)}"
  end
end
