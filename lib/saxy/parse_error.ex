defmodule Saxy.ParseError do
  defexception [:reason, :next_byte]

  def message(%__MODULE__{} = exception) do
    {error_type, term} = exception.reason

    format_message(error_type, term, exception.next_byte)
  end

  defp format_message(:syntax, {:token, token}, :eof) do
    "unexpected end of input, expected token: #{inspect(token)}"
  end

  defp format_message(:syntax, {:token, token}, next_byte) do
    "unexpected byte #{inspect(next_byte)}, expected token: #{inspect(token)}"
  end

  defp format_message(:syntax, {:wrong_closing_tag, open_tag, ending_tag}, _next_byte) do
    "unexpected ending tag #{inspect(ending_tag)}, expected tag: #{inspect(open_tag)}"
  end

  defp format_message(:syntax, {:invalid_pi, pi_name}, _next_byte) do
    "unexpected target name #{inspect(pi_name)} at the start of processing instruction, the target names \"XML\", \"xml\", and so on are reserved for standardization"
  end
end
