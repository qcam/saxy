defmodule Saxy do
  @moduledoc ~S"""
  Saxy is an XML SAX parser and encoder.

  Saxy provides functions to parse XML file in both binary and streaming way in compliant
  with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

  Saxy also offers DSL and API to build, compose and encode XML document.
  See "Encoder" section below for more information.

  ## Parser

  Saxy parser supports two modes of parsing: SAX and simple form.

  ### SAX mode (Simple API for XML)

  SAX is an event driven algorithm for parsing XML documents. A SAX parser takes XML document as the input
  and emits events out to a pre-configured event handler during parsing.

  There are several types of SAX events supported by Saxy:

  * `:start_document` - after prolog is parsed.
  * `:start_element` - when open tag is parsed.
  * `:characters` - when a chunk of `CharData` is parsed.
  * `:cdata` - when a chunk of `CData` is parsed.
  * `:end_element` - when end tag is parsed.
  * `:end_document` - when the root element is closed.

  See `Saxy.Handler` for more information.

  ### Simple form mode

  Saxy supports parsing XML documents into a simple format. See `Saxy.SimpleForm` for more details.

  ### Encoding

  Saxy **only** supports UTF-8 encoding. It also respects the encoding set in XML document prolog, which means
  that if the declared encoding is not UTF-8, the parser stops. Anyway, when there is no encoding declared,
  Saxy defaults the encoding to UTF-8.

  ### Reference expansion

  Saxy supports expanding character references and XML 1.0 predefined entity references, for example `&#65;`
  is expanded to `"A"`, `&#x26;` to `"&"`, and `&amp;` to `"&"`.

  Saxy does not expand external entity references, but provides an option to specify how they should be handled.
  See more in "Shared options" section.

  ### Creation of atoms

  Saxy does not create atoms during the parsing process.

  ### DTD and XSD

  Saxy does not support parsing DTD (Doctype Definition) and XSD schemas. When encountering DTD, the parser simply
  skips that.

  ### Shared options

  * `:expand_entity` - specifies how external entity references should be handled. Three supported strategies respectively are:
    * `:keep` - keep the original binary, for example `Orange &reg;` will be expanded to `"Orange &reg;"`, this is the default strategy.
    * `:skip` - skip the original binary, for example `Orange &reg;` will be expanded to `"Orange "`.
    * `{mod, fun, args}` - take the applied result of the specified MFA.
    * `:never` - keep the original binary, including predefined entity reference, e.g. `"Orange &amp;"` will remain `"Orange &amp;"`
  * `:cdata_as_characters` - `true` to emit CData events as `:characters`. Defaults to `true`.

  ## Encoder

  Saxy offers two APIs to build simple form and encode XML document.

  Use `Saxy.XML` to build and compose XML simple form, then `Saxy.encode!/2`
  to encode the built element into XML binary.

      iex> import Saxy.XML
      iex> element = element("person", [gender: "female"], "Alice")
      {"person", [{"gender", "female"}], ["Alice"]}
      iex> Saxy.encode!(element, [version: "1.0"])
      "<?xml version=\"1.0\"?><person gender=\"female\">Alice</person>"

  See `Saxy.XML` for more XML building APIs.

  Saxy also provides `Saxy.Builder` protocol to help composing structs into simple form.

      defmodule Person do
        @derive {
          Saxy.Builder,
          name: "person", attributes: [:gender], children: [:name, emails: &__MODULE__.build_emails/1]
        }

        import Saxy.XML

        defstruct [:name, :gender, emails: []]

        def build_emails(emails) do
          count = Enum.count(emails)

          element(
            "emails",
            [count: Enum.count(emails)],
            Enum.map(emails, &element("email", [], &1))
          )
        end
      end

      iex> jack = %Person{gender: :male, name: "Jack", emails: ["john@example.com"]}
      iex> john = %Person{gender: :male, name: "John"}
      iex> import Saxy.XML
      iex> root = element("people", [], [jack, john])
      iex> Saxy.encode!(root, [version: "1.0"])
      "<?xml version=\"1.0\"?><people><person gender=\"male\">Jack<emails count=\"1\"><email>john@example.com</email></emails></person><person gender=\"male\">John<emails count=\"0\"/></person></people>"

  """

  @compile {:inline, do_transform_stream: 5}

  alias Saxy.{
    Encoder,
    Handler.Accumulating,
    Parser,
    State
  }

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

        def handle_event(:end_element, name, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end

      iex> xml = "<?xml version='1.0' ?><foo bar='value'></foo>"
      iex> Saxy.parse_string(xml, MyTestHandler, [])
      {:ok,
       [{:end_document},
        {:end_element, "foo"},
        {:start_element, "foo", [{"bar", "value"}]},
        {:start_document, [version: "1.0"]}]}
  """

  @spec parse_string(
          data :: binary,
          handler :: module(),
          initial_state :: term(),
          options :: Keyword.t()
        ) ::
          {:ok, state :: term()}
          | {:halt, state :: term(), rest :: String.t()}
          | {:error, exception :: Saxy.ParseError.t()}
  def parse_string(data, handler, initial_state, options \\ [])
      when is_binary(data) and is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    # TODO: Start deprecating this option in next minor versions.
    cdata_as_characters = Keyword.get(options, :cdata_as_characters, true)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity,
      cdata_as_characters: cdata_as_characters,
      character_data_max_length: :infinity
    }

    case Parser.Binary.parse_prolog(data, false, data, 0, state) do
      {:ok, state} ->
        {:ok, state.user_state}

      {:halt, state, {buffer, pos}} ->
        length = byte_size(buffer) - pos
        {:halt, state.user_state, binary_part(buffer, pos, length)}

      {:error, _reason} = error ->
        error
    end
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

        def handle_event(:end_element, name, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end

      iex> stream = File.stream!("./test/support/fixture/foo.xml")
      iex> Saxy.parse_stream(stream, MyTestHandler, [])
      {:ok,
       [{:end_document},
        {:end_element, "foo"},
        {:start_element, "foo", [{"bar", "value"}]},
        {:start_document, [version: "1.0"]}]}

  ## Memory usage

  `Saxy.parse_stream/3` takes a `File.Stream` or `Stream` as the input, so the amount of bytes to buffer in each
  chunk can be controlled by `File.stream!/3` API.

  During parsing, the actual memory used by Saxy might be higher than the number configured for each chunk, since
  Saxy holds in memory some parsed parts of the original binary to leverage Erlang sub-binary extracting. Anyway,
  Saxy tries to free those up when it makes sense.

  ### Options

  See the “Shared options” section at the module documentation.

  * `:character_data_max_length` - tells the parser to emit the `:characters` event when its length exceeds the specified
    number. The option is useful when the tag being parsed containing a very large chunk of data. Defaults to `:infinity`.

  """

  @spec parse_stream(
          stream :: Enumerable.t(),
          handler :: module(),
          initial_state :: term(),
          options :: Keyword.t()
        ) ::
          {:ok, state :: term()}
          | {:halt, state :: term(), rest :: String.t()}
          | {:error, exception :: Saxy.ParseError.t()}

  def parse_stream(stream, handler, initial_state, options \\ []) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)
    character_data_max_length = Keyword.get(options, :character_data_max_length, :infinity)
    cdata_as_characters = Keyword.get(options, :cdata_as_characters, true)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity,
      cdata_as_characters: cdata_as_characters,
      character_data_max_length: character_data_max_length
    }

    init = {&Parser.Stream.parse_prolog(&1, &2, &1, 0, &3), state}

    case stream
         |> Stream.concat([:end_of_stream])
         |> Enum.reduce_while(init, &reduce_stream/2) do
      {:ok, state} ->
        {:ok, state.user_state}

      {:halt, state, {buffer, pos}} ->
        length = byte_size(buffer) - pos
        {:halt, state.user_state, binary_part(buffer, pos, length)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reduce_stream(:end_of_stream, {cont_fun, state}) do
    {:halt, cont_fun.(<<>>, false, state)}
  end

  defp reduce_stream(buffer, {cont_fun, state}) do
    case cont_fun.(buffer, true, state) do
      {:halted, cont_fun, state} ->
        {:cont, {cont_fun, state}}

      other ->
        {:halt, other}
    end
  end

  @doc """
  Parses XML stream and returns a stream of elements.

  This function takes a stream and returns a stream of xml SAX events.
  When any parsing error occurs, it raises a `Saxy.ParseError` exception.


  ## Examples

      iex> stream = File.stream!("./test/support/fixture/foo.xml")
      iex> Enum.to_list Saxy.stream_events stream
      [
        start_document: [version: "1.0"],
        start_element: {"foo", [{"bar", "value"}]},
        end_element: "foo"
      ]
      iex> Enum.to_list Saxy.stream_events ["<foo>unclosed value"]
      ** (Saxy.ParseError) unexpected end of input, expected token: :chardata

  > #### Warning {: .warning }
  >
  > Input stream is evaluated lazily, therefore some events may be emitted before
  > exception is raised

  ## Memory usage

  `Saxy.stream_events/2` takes a `File.Stream` or `Stream` as the input, so the amount of bytes to buffer in each
  chunk can be controlled by `File.stream!/3` API.

  During parsing, the actual memory used by Saxy might be higher than the number configured for each chunk, since
  Saxy holds in memory some parsed parts of the original binary to leverage Erlang sub-binary extracting. Anyway,
  Saxy tries to free those up when it makes sense.

  ### Options

  See the “Shared options” section at the module documentation.

  * `:character_data_max_length` - tells the parser to emit the `:characters` event when its length exceeds the specified
    number. The option is useful when the tag being parsed containing a very large chunk of data. Defaults to `:infinity`.

  """
  @spec stream_events(in_stream :: Enumerable.t(), options :: Keyword.t()) :: out_stream :: Enumerable.t()
  def stream_events(stream, options \\ []) do
    cont_fun = fn user_state -> {:lists.reverse(user_state), []} end
    stream_state(stream, Accumulating, [], cont_fun, options)
  end

  @doc """
  Parses an XML stream with the supplied handler and returns a stream of parsed elements.

  This function expects:
  * a stream;
  * a SAX event handler (see more at `Saxy.Handler`);
  * an initial state;
  * and an emit function that will be called after parsing each element of the input stream.

  The `emit_fun` takes the user state as input and returns a tuple `{emitted, new_state}`,
  where `emitted` is an enumerable of elements that will be appended to the output stream,
  and `new_state` is the user state that will be used in subsequent parsing.

  This lets you control both when elements are emitted, as well the user state as you parse along the stream.
  For example: emiting only elements that are completely parsed or cleaning up the state
  by removing elements from it when they have been emitted.

  Parsing errors raise a `Saxy.ParseError` exception.

  ## Examples

      defmodule BookHandler do
        @behaviour Saxy.Handler

        def handle_event(:start_document, _prolog, state) do
          {:ok, state}
        end

        def handle_event(:end_document, _data, state) do
          {:ok, state}
        end

        def handle_event(:start_element, {"book", attributes}, state) do
          category = with {"category", category} <- List.keyfind(attributes, "category", 0), do: category
          {:ok, %{state | book: %{category: category}}}
        end

        def handle_event(:start_element, {"title", _attributes}, %{book: book} = state) when is_map(book) do
          state = Map.put_new(state, :title, "")
          {:ok, state}
        end

        def handle_event(:start_element, _, state) do
          {:ok, state}
        end

        def handle_event(:end_element, "book", %{parsed: parsed, book: book} = state) do
          {:ok, %{state | parsed: [book | parsed], book: nil}}
        end

        def handle_event(:end_element, "title", %{book: book, title: title} = state) do
          book = Map.put(book, :title, title)
          state = Map.drop(state, [:title])
          {:ok, %{state | book: book}}
        end

        def handle_event(:end_element, _, state) do
          {:ok, state}
        end

        def handle_event(:characters, chars, %{title: title} = state) when is_binary(title) do
          {:ok, %{state | title: title <> chars}}
        end

        def handle_event(:characters, _chars, state) do
          {:ok, state}
        end
      end

      iex> stream = File.stream!("./test/support/fixture/books.xml")
      iex> initial_state = %{parsed: [], book: nil}
      iex> emit_fun = fn %{parsed: parsed} = state -> {parsed, Map.put(state, :parsed, [])} end
      iex> stream |> Saxy.stream_state(BookHandler, initial_state, emit_fun) |> Enum.to_list
      [
        %{category: "cooking", title: "Everyday Italian"},
        %{category: "children", title: "Harry Potter"},
        %{category: "web", title: "XQuery Kick Start"},
        %{category: "web", title: "Learning XML"}
      ]
      iex> ["<foo>unclosed value"]  |> Saxy.stream_state(BookHandler, %{}, fn state -> {[], state} end) |> Enum.to_list
      ** (Saxy.ParseError) unexpected end of input, expected token: :chardata

  > #### Warning {: .warning }
  >
  > The input stream is evaluated lazily, therefore some events may be emitted before any exception is raised

  ### Options

  See the “Shared options” section at the module documentation.

  * `:character_data_max_length` - tells the parser to emit the `:characters` event when its length exceeds the specified
    number. The option is useful when the tag being parsed containing a very large chunk of data. Defaults to `:infinity`.

  """

  @spec stream_state(
          in_stream :: Enumerable.t(),
          handler :: module(),
          initial_state :: term(),
          emit_fun,
          options :: Keyword.t()
        ) :: out_stream :: Enumerable.t()
        when emit_fun: (any() -> {Enumerable.t(), any()})
  def stream_state(stream, handler, initial_state, emit_fun, options \\ []) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)
    character_data_max_length = Keyword.get(options, :character_data_max_length, :infinity)
    cdata_as_characters = Keyword.get(options, :cdata_as_characters, true)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity,
      cdata_as_characters: cdata_as_characters,
      character_data_max_length: character_data_max_length
    }

    init = {&Parser.Stream.parse_prolog(&1, &2, &1, 0, &3), emit_fun, state}

    stream
    |> Stream.concat([:end_of_stream])
    |> Stream.transform(init, &transform_stream/2)
  end

  defp transform_stream(:end_of_stream, {cont_fun, emit_fun, state}) do
    do_transform_stream(<<>>, false, cont_fun, emit_fun, state)
  end

  defp transform_stream(buffer, {cont_fun, emit_fun, state}) do
    do_transform_stream(buffer, true, cont_fun, emit_fun, state)
  end

  defp do_transform_stream(buffer, more?, cont_fun, emit_fun, state) do
    case cont_fun.(buffer, more?, state) do
      {:halted, cont_fun, %{user_state: user_state} = state} ->
        {emit, new_state} = emit_fun.(user_state)
        {emit, {cont_fun, emit_fun, %{state | user_state: new_state}}}

      {:error, error} ->
        raise error

      other ->
        {:halt, other}
    end
  end

  @doc """
  Encodes a simple form XML element into string.

  This function encodes an element in simple form format and a prolog to an XML document.

  ## Examples

      iex> import Saxy.XML
      iex> root = element(:foo, [{"foo", "bar"}], "bar")
      iex> prolog = [version: "1.0"]
      iex> Saxy.encode!(root, prolog)
      "<?xml version=\\"1.0\\"?><foo foo=\\"bar\\">bar</foo>"
      iex> prolog = [version: "1.0", encoding: "UTF-8"]
      iex> Saxy.encode!(root, prolog)
      "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?><foo foo=\\"bar\\">bar</foo>"
  """

  @spec encode!(root :: Saxy.XML.element(), prolog :: Saxy.Prolog.t() | Keyword.t() | nil) :: String.t()

  def encode!(root, prolog \\ nil) do
    root
    |> Encoder.encode_to_iodata(prolog)
    |> IO.iodata_to_binary()
  end

  @doc """
  Encodes a simple form element into IO data.

  Same as `encode!/2` but this encodes the document into IO data.

  ## Examples

      iex> import Saxy.XML
      iex> root = element(:foo, [{"foo", "bar"}], "bar")
      iex> prolog = [version: "1.0"]
      iex> Saxy.encode_to_iodata!(root, prolog)
      [
        [~c'<?xml', [32, ~c'version', 61, 34, "1.0", 34], [], [], ~c'?>'],
        [60, "foo", 32, "foo", 61, 34, "bar", 34],
        62,
        ["bar"],
        [60, 47, "foo", 62]
      ]

  """
  @spec encode_to_iodata!(root :: Saxy.XML.element(), prolog :: Saxy.Prolog.t() | Keyword.t() | nil) :: iodata()

  def encode_to_iodata!(root, prolog \\ nil) do
    Encoder.encode_to_iodata(root, prolog)
  end
end
