defmodule Saxy do
  @moduledoc ~S"""
  Saxy is a XML SAX parser which provides functions to parse XML file in both binary and streaming way.
  Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

  ## SAX Events

  There are currently 5 types of events emitted by the parser.

  * `:start_document`.
  * `:start_element`.
  * `:characters`.
  * `:end_element`.
  * `:end_document`.

  See `Saxy.Handler` for more information.

  ## Encoding

  Saxy supports ASCII and UTF-8 encodings and respects the encoding set in XML document prolog. That
  means that if the prolog declares an encoding that is not supported, it simply stops parsing and returns.

  Though encoding declaration is optional in XML, so when encoding is missing in the document, UTF-8 will be
  the default encoding.

  ## Entity Reference converting

  The parser converts character and entity reference, for example `&amp;` will be converted to `&` and `&#60;`
  to `<`.

  There is currently no support for external entity references.

  ## Creation of atoms

  Saxy does not automatically create new atoms during the parsing process.

  ## XSD Schema

  Saxy does not support XSD schemas.

  """

  alias Saxy.{Parser, ParsingError, State}

  @doc ~S"""
  Parses XML binary data.

  This function takes XML binary, SAX event handler (see more at `Saxy.Handler`) and an initial state as the input, it returns
  `{:ok, state}` if parsing is successful, otherwise `{:error, exception}`, where `exception` is a
  `Saxy.ParsingError` struct which can be converted into readable message with `Exception.message/1`.

  The third argument `state` can be used to keep track of data and parsing progress when parsing is happening, which will be
  returned when parsing finishes.

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

      iex> xml = "<?xml version='1.0' ?><foo bar='value'></foo>"
      iex> Saxy.parse_string(xml, MyEventHandler, [])
      {:ok,
       [
         {:end_document},
         {:end_element, "foo"},
         {:start_element, "foo", [{"bar", "value"}]},
         {:start_document, [version: "1.0", encoding: "UTF-8", standalone: false]}
       ]}
  """

  @spec parse_string(
          data :: binary,
          handler :: module | function,
          state :: term
        ) :: {:ok, state :: term} | {:error, exception :: ParsingError.t()}

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

  @doc ~S"""
  Parses XML stream data.

  This function takes a stream, SAX event handler (see more at `Saxy.Handler`) and an initial state as the input, it returns
  `{:ok, state}` if parsing is successful, otherwise `{:error, exception}`, where `exception` is a
  `Saxy.ParsingError` struct which can be converted into readable message with `Exception.message/1`.

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

      iex> stream = File.stream!("/path/to/file.xml")
      iex> Saxy.parse_stream(stream, MyEventHandler, [])
      {:ok,
       [
         {:end_document},
         {:end_element, "foo"},
         {:start_element, "foo", [{"bar", "value"}]},
         {:start_document, [version: "1.0", encoding: "UTF-8", standalone: false]}
       ]}

  ## Memory usage

  `Saxy.parse_stream/3` takes a `File.Stream` or `Stream` as the input, so you are in control of how many bytes
  in each chunk in the file you want to buffer.  Anyway, Saxy will try trimming off the parsed parts of buffer
  when it exceeds 4096 bytes (this number is not configurable yet) to keep the memory usage in a reasonable limit.

  """

  @spec parse_stream(
          stream :: File.Stream.t() | Stream.t(),
          handler :: module | function,
          state :: term
        ) :: {:ok, state :: term} | {:error, exception :: ParsingError.t()}

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
      :throw, reason ->
        handle_throw(reason)
    else
      {:ok, {:document, _document}, {_buffer, _position}, %{user_state: state}} ->
        {:ok, state}
    end
  end

  defp handle_throw({:error, reason}) do
    {:error, %ParsingError{reason: reason}}
  end

  defp handle_throw({:stop, returning}) do
    {:ok, returning}
  end
end
