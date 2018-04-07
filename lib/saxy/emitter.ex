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

  defp do_emit(event_type, data, handler, user_state) do
    handler.handle_event(event_type, data, user_state)
  end

  @compile {:inline, [convert_entity_reference: 2]}

  def convert_entity_reference("amp", _state), do: [?&]

  def convert_entity_reference("lt", _state), do: [?<]

  def convert_entity_reference("gt", _state), do: [?>]

  def convert_entity_reference("apos", _state), do: [?']

  def convert_entity_reference("quot", _state), do: [?"]

  def convert_entity_reference(reference_name, state) do
    case state.expand_entity do
      :keep -> [?&, reference_name, ?;]
      :skip -> []
      {mod, fun, args} -> apply(mod, fun, [reference_name | args])
    end
  end
end
