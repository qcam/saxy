defmodule Saxy.Emitter do
  @moduledoc false

  alias Saxy.State

  def emit(event_type, data, %State{user_state: user_state, handler: handler} = state) do
    case do_emit(event_type, data, handler, user_state) do
      {:ok, user_state} ->
        {:ok, %{state | user_state: user_state}}

      {:stop, returning} ->
        {:stop, %{state | user_state: returning}}

      other ->
        {:error, {event_type, other}}
    end
  end

  def do_emit(event_type, data, handler, user_state) when is_atom(handler) do
    handler.handle_event(event_type, data, user_state)
  end

  def do_emit(event_type, data, handler, user_state) when is_function(handler, 3) do
    handler.(event_type, data, user_state)
  end
end
