defmodule Saxy.ParseError do
  @moduledoc """
  Returned when parser encounters malformed token during parsing.
  """

  defexception [
    :reason,
    :binary,
    :position
  ]

  def message(%__MODULE__{} = exception) do
    format_message(
      exception.reason,
      exception.binary,
      exception.position
    )
  end

  defp format_message({:token, token}, binary, position) when position == byte_size(binary) do
    "unexpected end of input, expected token: #{inspect(token)}"
  end

  defp format_message({:token, token}, binary, position) do
    byte = :binary.at(binary, position)
    string = <<byte>>

    "unexpected byte #{inspect(string)}, expected token: #{inspect(token)}"
  end

  defp format_message({:wrong_closing_tag, open_tag, ending_tag}, _, _) do
    "unexpected ending tag #{inspect(ending_tag)}, expected tag: #{inspect(open_tag)}"
  end

  defp format_message({:invalid_pi, pi_name}, _, _) do
    "unexpected target name #{inspect(pi_name)} at the start of processing instruction, the target names \"XML\", \"xml\", and so on are reserved for standardization"
  end

  defp format_message({:invalid_encoding, encoding}, _, _) do
    "unexpected encoding declaration #{inspect(encoding)}, only UTF-8 is supported"
  end

  defp format_message({:bad_return, {event, return}}, _, _) do
    "unexpected return #{inspect(return)} in #{inspect(event)} event handler"
  end
end
