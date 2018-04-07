defmodule Saxy do
  @moduledoc ~S"""
  Saxy is a XML SAX parser which provides functions to parse XML file in both binary and streaming way.
  Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

  ## Parsing mode

  Saxy can be used in two modes: SAX and simple form.

  ### SAX (Simple API for XML)

  SAX is an event driven algorithm for parsing XML documents. A SAX parser takes XML document as the input
  and emits events out to a pre-configured event handler during parsing.

  There are 5 types of SAX events supported by Saxy:

  * `:start_document` - after prolog is parsed.
  * `:start_element` - when open tag is parsed.
  * `:characters` - when a chunk of `CharData` is parsed.
  * `:end_element` - when end tag is parsed.
  * `:end_document` - when the root element is closed.

  See `Saxy.Handler` for more information.

  ### Simple form

  Saxy supports parsing XML documents into a simple format. See `Saxy.SimpleForm` for more details.

  ## Encoding

  Saxy **only** supports UTF-8 encoding. It also respects the encoding set in XML document prolog, which means
  that if the declared encoding is not UTF-8, the parser stops. Anyway, when there is no encoding declared,
  Saxy defaults the encoding to UTF-8.

  ## Reference expansion

  Saxy supports expanding character references and XML 1.0 predefined entity references, for example `&#65;`
  is expanded to `"A"`, `&#x26;` to `"&"`, and `&amp;` to `"&"`.

  Saxy does not expand external entity references, but provides an option to specify how they should be handled.
  See more in "Shared options" section.

  ## Creation of atoms

  Saxy does not create atoms during the parsing process.

  ## DTD and XSD

  Saxy does not support DTD (Doctype Definition) and XSD schemas.

  ## Shared options

  * `:expand_entity` - specifies how external entity references should be handled. Three supported strategies respectively are:
    * `:keep` - keep the original binary, for example `Orange &reg;` will be expanded to `"Orange &reg;"`, this is the default strategy.
    * `:skip` - skip the original binary, for example `Orange &reg;` will be expanded to `"Orange "`.
    * `{mod, fun, args}` - take the applied result of the specified MFA.

  """

  alias Saxy.{Parser, State}

  @doc ~S"""
  Parses XML binary data.

  This function takes XML binary, SAX event handler (see more at `Saxy.Handler`) and an initial state as the input, it returns
  `{:ok, state}` if parsing is successful, otherwise `{:error, exception}`, where `exception` is a
  `Saxy.ParseError` struct which can be converted into readable message with `Exception.message/1`.

  The third argument `state` can be used to keep track of data and parsing progress when parsing is happening, which will be
  returned when parsing finishes.

  ### Options

  See the “Shared options” section at the module documentation.

  ## Examples

      defmodule MyTestHandler do
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

        def handle_event(:end_element, {name}, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
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
        ) :: {:ok, state :: term()} | {:error, exception :: Saxy.ParseError.t()}
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
  `Saxy.ParseError` struct which can be converted into readable message with `Exception.message/1`.

  ## Examples

      defmodule MyTestHandler do
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

        def handle_event(:end_element, {name}, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
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

  `Saxy.parse_stream/3` takes a `File.Stream` or `Stream` as the input, so the amount of bytes to buffer in each
  chunk can be controlled by `File.stream!/3` API.

  During parsing, the actual memory used by Saxy might be higher than the number configured for each chunk, since
  Saxy holds in memory some parsed parts of the original binary to leverage Erlang sub-binary extracting. Anyway,
  Saxy tries to free those up when it makes sense.

  ### Options

  See the “Shared options” section at the module documentation.

  """

  @spec parse_stream(
          stream :: File.Stream.t() | Stream.t(),
          handler :: module() | function(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, state :: term()} | {:error, exception :: Saxy.ParseError.t()}

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
