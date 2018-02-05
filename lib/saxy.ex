defmodule Saxy do
  alias Saxy.{Parser, State}

  def parse_string(data, handler, state)
      when is_binary(data) and (is_atom(handler) or is_function(handler, 3)) do
    initial_state = %State{
      cont: :binary,
      prolog: nil,
      handler: handler,
      user_state: state
    }

    case Parser.match(data, 0, :document, initial_state) do
      {:ok, {:document, _document}, {_buffer, _position}, %{user_state: state}} ->
        {:ok, state}

      {:error, :document, {_buffer, _position}, _state} ->
        {:error, "FIXME: DO NOT SEND THIS MESSAGE TO USEr"}
    end
  end

  def parse_stream(%module{} = stream, handler, state)
      when module in [File.Stream, Stream] and (is_atom(handler) or is_function(handler, 3)) do
    initial_state = %State{
      cont: stream,
      prolog: nil,
      handler: handler,
      user_state: state
    }

    case Parser.match(<<>>, 0, :document, initial_state) do
      {:ok, {:document, _document}, {_buffer, _position}, %{user_state: state}} ->
        {:ok, state}

      {:error, :document, {_buffer, _position}, _state} ->
        {:error, "FIXME: DO NOT SEND THIS MESSAGE TO USER"}
    end
  end
end
