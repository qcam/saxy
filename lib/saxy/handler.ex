defmodule Saxy.Handler do
  @moduledoc ~S"""
  This module provides callbacks to implement SAX events handler.
  """

  @doc ~S"""
  Callback for event handling.

  This callback takes an event type, an event data and `user_state` as the input.

  The initial `user_state` is the third argument in `Saxy.parse_string/3` and `Saxy.parse_stream/3`.
  It can be accumulated and passed around during the parsing time by returning it as the result of
  the callback implementation, which can be used to keep track of data when parsing is happening.

  Returning `{:ok, new_state}` continues the parsing process with the new state.

  Returning `{:stop, anything}` stops the prosing process immediately, and `anything` will be returned.
  This is usually handy when we want to get the desired return without parsing the whole file.

  Returning `{:halt, anything}` stops the prosing process immediately, `anything` will be returned, together
  with the rest of buffer being parsed. This is usually handy when we want to get the desired return
  without parsing the whole file.

  ## SAX Events

  There are a couple of events that need to be handled in the handler.

  * `:start_document`.
  * `:start_element`.
  * `:characters` – the binary that matches [`CharData*`](https://www.w3.org/TR/xml/#d0e1106) and [Reference](https://www.w3.org/TR/xml/#NT-Reference).
    Note that it is **not trimmed** and includes **ALL** whitespace characters that match `CharData`.
  * `:cdata` – the binary that matches [`CData*`](https://www.w3.org/TR/2006/REC-xml11-20060816/#NT-CData).
  * `:end_document`.
  * `:end_element`.

  Check out `event_data()` type for more information of what are emitted for each event type.

  ## Examples

      defmodule MyEventHandler do
        @behaviour Saxy.Handler

        def handle_event(:start_document, prolog, state) do
          {:ok, [{:start_document, prolog} | state]}
        end

        def handle_event(:end_document, _data, state) do
          {:ok, [{:end_document} | state]}
        end

        def handle_event(:start_element, {name, attributes}, state) do
          {:ok, [{:start_element, name, attributes} | state]}
        end

        def handle_event(:end_element, name, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end
  """

  @type event_name() :: :start_document | :end_document | :start_element | :characters | :cdata | :end_element

  @type start_document_data() :: Keyword.t()
  @type end_document_data() :: any()
  @type start_element_data() :: {name :: String.t(), attributes :: [{name :: String.t(), value :: String.t()}]}
  @type end_element_data() :: name :: String.t()
  @type characters_data() :: String.t()
  @type cdata_data() :: String.t()

  @type event_data() ::
          start_document_data()
          | end_document_data()
          | start_element_data()
          | end_element_data()
          | characters_data()
          | cdata_data()

  @callback handle_event(event_type :: event_name(), data :: event_data(), user_state :: any()) ::
              {:ok, user_state :: any()} | {:stop, returning :: any()} | {:halt, returning :: any()}
end
