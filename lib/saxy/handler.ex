defmodule Saxy.Handler do
  @moduledoc ~S"""
  This module provides callbacks for implementing SAX events handler.
  """

  @doc ~S"""
  Callback for event handling.

  This callback takes an event type, an event data and `user_state` as the input.

  `user_state` is the third argument in `Saxy.parse_string/3` and `Saxy.parse_stream/3`.
  It and can be accumulated, passed around during the parsing time by returning it
  as the result of the callback implementation, which can be used to keep track
  of data when parsing is happening.

  Returning `{:ok, new_state}` continues the parsing process with the new state.

  Returning `{:stop, anything}` stops the prosing process immediately, and `anything` will be returned.
  This is useful when we want to get the desired return without parsing the whole file.

  ## SAX Events

  There are 6 types of event need to be handled in the handler.

  ### `:start_document`

  The event data will be the XML prolog, which is a keyword list of `:version`, `:encoding` and `:standalone`
  respectively.

  ### `:start_element`

  The event data is the element, which is a two-element tuple, respectively tag name, attributes.

  ### `:characters`

  The event data is the binary that matches [`CharData*`](https://www.w3.org/TR/xml/#d0e1106) and [Reference](https://www.w3.org/TR/xml/#NT-Reference).

  Note that it is not trimmed and includes all the whitespace characters that match `CharData`.

  ### `:end_document`

  The event data is an empty tuple.

  ### `:end_element`

  The event data is a one-element tuple contains the tag name of the closing element.

  ## Examples

      defmodule MyEventHandler do
        @behaviour Saxy.Handler

        def handle_event(:start_document, prolog, state) do
          IO.inspect "Start parsing document"
          {:ok, [{:start_document, prolog} | state]}
        end

        def handle_event(:end_document, _data, state) do
          IO.inspect "Finish parsing document"
          {:ok, [{:end_document} | state]}
        end

        def handle_event(:start_element, {name, attributes}, state) do
          IO.inspect "Start parsing element #{name} with attributes #{inspect(attributes)}"
          {:ok, [{:start_element, name, attributes} | state]}
        end

        def handle_event(:end_element, {name}, state) do
          IO.inspect "Finish parsing element #{name}"
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          IO.inspect "Receive characters #{chars}"
          {:ok, [{:chacters, chars} | state]}
        end
      end
  """

  @callback handle_event(event_type :: atom, data :: any, user_state :: any) ::
              {:ok, user_state :: any} | {:stop, returning :: any}
end
