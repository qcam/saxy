defmodule Saxy.Emitter do
  @moduledoc false

  alias Saxy.State

  defmacro emit_event({:<-, _, [state, emit_args]}, on_halt, do: block) do
    quote do
      case Saxy.Emitter.emit(unquote_splicing(emit_args)) do
        {:ok, new_state} ->
          unquote(state) = new_state
          unquote(block)

        {:stop, state} ->
          {:ok, state}

        {:halt, state} ->
          {:halt, state, unquote(on_halt)}

        other ->
          other
      end
    end
  end

  def emit(event_type, data, %State{user_state: user_state, handler: handler} = state) do
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
