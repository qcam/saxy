defmodule Saxy.Handler do
  @moduledoc ~S"""
  This module provides callbacks for implementing SAX events handler.

  There is only one callback to implement in this module.

  ## Examples

      defmodule MyEventHandler do
        @behaviour Saxy.Handler

        def handle_event(:start_document, prolog, state) do
          IO.inspect "Start parsing document"
          [{:start_document, prolog} | state]
        end

        def handle_event(:end_document, _data, state) do
          IO.inspect "Finish parsing document"
          [{:end_document} | state]
        end

        def handle_event(:start_element, {name, attributes}, state) do
          IO.inspect "Start parsing element #{name} with attributes #{inspect(attributes)}"
          [{:start_element, name, attributes} | state]
        end

        def handle_event(:end_element, {name}, state) do
          IO.inspect "Finish parsing element #{name}"
          [{:end_element, name} | state]
        end

        def handle_event(:characters, chars, state) do
          IO.inspect "Receive characters #{chars}"
          [{:chacters, chars} | state]
        end
      end

  """

  @callback handle_event(event_type :: atom, data :: tuple, user_state :: term) ::
              user_state :: term
end
