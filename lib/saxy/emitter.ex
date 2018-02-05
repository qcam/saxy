defmodule Saxy.Emitter do
  alias Saxy.State

  def emit(event_type, data, %State{user_state: user_state, handler: handler} = state) do
    user_state = do_emit(event_type, data, handler, user_state)

    %{state | user_state: user_state}
  end

  def do_emit(:characters, <<>>, _handler, user_state) do
    user_state
  end

  def do_emit(event_type, data, handler, user_state) when is_atom(handler) do
    handler.handle_event(event_type, data, user_state)
  end

  def do_emit(event_type, data, handler, user_state) when is_function(handler, 3) do
    handler.(event_type, data, user_state)
  end
end
