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

  ## Simple form parsing

  SAX supports parsing XML document into a simple format. See `Saxy.SimpleForm` for more details.

  ## Encoding

  Saxy supports ASCII and UTF-8 encodings and respects the encoding set in XML document prolog. That
  means that if the prolog declares an encoding that is not supported, it simply stops parsing and returns.

  Though encoding declaration is optional in XML, so when encoding is missing in the document, UTF-8 will be
  the default encoding.

  ## Reference

  Saxy converts character references by default, for example `&#65;` is converted to `"A"` and `&#x26;` is
  converted to `"&"`.

  The parser **DOES NOT** convert any entity reference, the handler that uses `Saxy.Handler` behaviour needs to convert
  all entity references during parsing by implementing `handle_entity_reference/1` callback.

  See `Saxy.Handler` for more details.

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

        def handle_entity_reference(reference_name) do
          MyEntitiesConverter.convert(reference_name)
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
          handler :: module() | function(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, state :: term()} | {:error, exception :: ParsingError.t()}
  def parse_string(data, handler, initial_state, options \\ []) when is_binary(data) and is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    Parser.parse_document(data, :done, state)
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

        def handle_entity_reference(reference_name) do
          MyEntitiesConverter.convert(reference_name)
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
  in each chunk in the file you want to buffer. Anyway, Saxy will try trimming off the parsed parts of buffer
  when it exceeds 2048 bytes (this number is not configurable yet) to keep the memory usage in a reasonable limit.

  """

  @spec parse_stream(
          stream :: File.Stream.t() | Stream.t(),
          handler :: module() | function(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, state :: term()} | {:error, exception :: ParsingError.t()}

  def parse_stream(%module{} = stream, handler, initial_state, options \\ []) when module in [File.Stream, Stream] do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    Parser.parse_document(<<>>, stream, state)
  end
end
