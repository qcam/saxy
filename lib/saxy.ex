defmodule Saxy do
  alias Saxy.{Parser, ParsingError, State}

  def parse_string(data, handler, state)
      when is_binary(data) and (is_atom(handler) or is_function(handler, 3)) do
    initial_state = %State{
      cont: :binary,
      prolog: nil,
      handler: handler,
      user_state: state
    }

    parse(data, initial_state)
  end

  def parse_stream(%module{} = stream, handler, state)
      when module in [File.Stream, Stream] and (is_atom(handler) or is_function(handler, 3)) do
    initial_state = %State{
      cont: stream,
      prolog: nil,
      handler: handler,
      user_state: state
    }

    parse(<<>>, initial_state)
  end

  defp parse(buffer, initial_state) do
    try do
      Parser.match(buffer, 0, :document, initial_state)
    catch
      :throw, reason -> {:error, %ParsingError{reason: reason}}
    else
      {:ok, {:document, _document}, {_buffer, _position}, %{user_state: state}} ->
        {:ok, state}
    end
  end
end
