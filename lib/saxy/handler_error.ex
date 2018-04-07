defmodule Saxy.HandlerError do
  @moduledoc """
  Returned when the implemented handler returns unexpected value.
  """

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    {error_type, term} = exception.reason

    format_message(error_type, term)
  end

  defp format_message(:bad_return, {event, return}) do
    "unexpected return #{inspect(return)} in #{inspect(event)} event handler"
  end
end
