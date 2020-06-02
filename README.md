[![Hex pm](http://img.shields.io/hexpm/v/saxy.svg?style=flat)](https://hex.pm/packages/saxy)

Saxy
===

Saxy (Sá xị) is an XML SAX parser and encoder in Elixir that focuses on speed, usability and standard compliance.

Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

## Features highlight

* An incredibly fast XML 1.0 SAX parser.
* An extremely fast XML encoder.
* Native support for streaming parsing large XML files.
* Parse XML documents into simple DOM format.
* Support quick returning in event handlers.

## Installation

Add `:saxy` to your `mix.exs`.

```elixir
def deps do
  [{:saxy, "~> 1.1"}]
end
```

## Overview

Full documentation is available on [HexDocs](https://hexdocs.pm/saxy/).

### SAX parser

A SAX event handler implementation is required before starting parsing.

```elixir
defmodule MyEventHandler do
  @behaviour Saxy.Handler

  def handle_event(:start_document, prolog, state) do
    IO.inspect("Start parsing document")
    {:ok, [{:start_document, prolog} | state]}
  end

  def handle_event(:end_document, _data, state) do
    IO.inspect("Finish parsing document")
    {:ok, [{:end_document} | state]}
  end

  def handle_event(:start_element, {name, attributes}, state) do
    IO.inspect("Start parsing element #{name} with attributes #{inspect(attributes)}")
    {:ok, [{:start_element, name, attributes} | state]}
  end

  def handle_event(:end_element, name, state) do
    IO.inspect("Finish parsing element #{name}")
    {:ok, [{:end_element, name} | state]}
  end

  def handle_event(:characters, chars, state) do
    IO.inspect("Receive characters #{chars}")
    {:ok, [{:chacters, chars} | state]}
  end
end
```

Then start parsing XML documents with:

```elixir
iex> xml = "<?xml version='1.0' ?><foo bar='value'></foo>"
iex> Saxy.parse_string(xml, MyEventHandler, [])
{:ok,
 [{:end_document},
  {:end_element, "foo"},
  {:start_element, "foo", [{"bar", "value"}]},
  {:start_document, [version: "1.0"]}]}
```

### Streaming parsing

Saxy also accepts file stream as the input:

```elixir
stream = File.stream!("/path/to/file")

Saxy.parse_stream(stream, MyEventHandler, initial_state)
```

It even supports parsing a normal stream.

```elixir
stream = File.stream!("/path/to/file") |> Stream.filter(&(&1 != "\n"))

Saxy.parse_stream(stream, MyEventHandler, initial_state)
```

### Partial parsing

Saxy can parse an XML document partially. This feature is useful when the
document cannot be turned into a stream e.g receiving over socket.

```elixir
{:ok, partial} = Partial.new(MyEventHandler, initial_state)
{:cont, partial} = Partial.parse(partial, "<foo>")
{:cont, partial} = Partial.parse(partial, "<bar></bar>")
{:cont, partial} = Partial.parse(partial, "</foo>")
{:ok, state} = Partial.terminate(partial)
```

### Simple DOM format exporting

Sometimes it will be convenient to just export the XML document into simple DOM
format, which is a 3-element tuple including the tag name, attributes, and a
list of its children.

`Saxy.SimpleForm` module has this nicely supported:

```elixir
Saxy.SimpleForm.parse_string(data)

{"menu", [],
 [
   {"movie",
    [{"id", "tt0120338"}, {"url", "https://www.imdb.com/title/tt0120338/"}],
    [{"name", [], ["Titanic"]}, {"characters", [], ["Jack &amp; Rose"]}]},
   {"movie",
    [{"id", "tt0109830"}, {"url", "https://www.imdb.com/title/tt0109830/"}],
    [
      {"name", [], ["Forest Gump"]},
      {"characters", [], ["Forest &amp; Jenny"]}
    ]}
 ]}
```

### XML builder

Saxy offers two APIs to build simple form and encode XML document.

Use `Saxy.XML` to build and compose XML simple form, then `Saxy.encode!/2`
to encode the built element into XML binary.

```elixir
iex> import Saxy.XML
iex> element = element("person", [gender: "female"], "Alice")
{"person", [{"gender", "female"}], [{:characters, "Alice"}]}
iex> Saxy.encode!(element, [])
"<?xml version=\"1.0\"?><person gender=\"female\">Alice</person>"
```

See `Saxy.XML` for more XML building APIs.

Saxy also provides `Saxy.Builder` protocol to help composing structs into simple form.

```elixir
defmodule Person do
  @derive {Saxy.Builder, name: "person", attributes: [:gender], children: [:name]}

  defstruct [:gender, :name]
end

iex> jack = %Person{gender: :male, name: "Jack"}
iex> john = %Person{gender: :male, name: "John"}
iex> import Saxy.XML
iex> root = element("people", [], [jack, john])
iex> Saxy.encode!(root, [])
"<?xml version=\"1.0\"?><people><person gender=\"male\">Jack</person><person gender=\"male\">John</person></people>"
```

### Benchmarking

Note that benchmarking XML parsers is difficult and highly depends on the complexity
of the documents being parsed. Event I try hard to make the benchmarking suite
fair but it's hard to avoid biases when choosing the documents to benchmark
against.

Therefore the conclusion in this section is only for reference purpose. Please
feel free to benchmark against your target documents. The benchmark suite can be found
in [bench/](./bench).

A rule of thumb is that we should compare apple to apple. Some XML parsers
target only specific types of XML. Therefore some indicators are provided in the
test suite to let know of the fairness of the benchmark results.

Some quick and biased conclusions from the benchmark suite:

* For SAX parser, Saxy is usually 1.4 times faster than [Erlsom](https://github.com/willemdj/erlsom).
  With deeply nested documents, Saxy is noticeably faster (4 times faster).
* For XML builder and encoding, Saxy is usually 10 to 30 times faster than [XML Builder](https://github.com/joshnuss/xml_builder).
  With deeply nested documents, it could be 180 times faster.
* Saxy significantly uses less memory than XML Builder (4 times to 25 times).
* Saxy significantly uses less memory than Xmerl, Erlsom and Exomler (1.4 times
  10 times).

### Limitations

* No XSD supported.
* No DTD supported, when Saxy encounters a `<!DOCTYPE`, it skips that.

## Where did the name come from?

![Sa xi Chuong Duong](./saxi.jpg)

Sa Xi, pronounced like `sa-see`, is an awesome soft drink made by [Chuong Duong](http://www.cdbeco.com.vn/en).

## Contributing

If you have any issues or ideas, feel free to write to https://github.com/qcam/saxy/issues.

To start developing:

1. Fork the repository.
2. Write your code and related tests.
3. Create a pull request at https://github.com/qcam/saxy/pulls.
