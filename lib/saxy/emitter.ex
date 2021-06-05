defmodule Saxy.Emitter do
  @moduledoc false

  alias Saxy.State

  def emit(event_type, data, state, on_halt) do
    case emit(event_type, data, state) do
      {:ok, state} -> {:cont, state}
      {:stop, state} -> {:ok, state}
      {:halt, state} -> {:halt, state, on_halt}
      {:error, exception} -> {:error, exception}
    end
  end

  defp emit(event_type, data, %State{user_state: user_state, handler: handler} = state) do
    case do_emit(event_type, data, handler, user_state) do
      {result, user_state} when result in [:ok, :stop, :halt] ->
        {result, %{state | user_state: user_state}}

      other ->
        Saxy.Parser.Utils.bad_return_error({event_type, other})
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
