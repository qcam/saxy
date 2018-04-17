Saxy
===

Saxy (Sá xị) is an XML SAX parser in Elixir that focuses on speed, usability and standard compliance.

Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

## Highlight features

* A incredibly fast XML 1.0 SAX parser.
* Native support for streaming parsing large XML files.
* Parse XML documents into simple DOM format.
* Support quick returning in event handlers.

## Installation

Add `:saxy` to your `mix.exs`.

```elixir
def deps do
  [{:saxy, "~> 0.6.0"}]
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
    [{:start_document, prolog} | state]
  end

  def handle_event(:end_document, _data, state) do
    IO.inspect("Finish parsing document")
    [{:end_document} | state]
  end

  def handle_event(:start_element, {name, attributes}, state) do
    IO.inspect("Start parsing element #{name} with attributes #{inspect(attributes)}")
    [{:start_element, name, attributes} | state]
  end

  def handle_event(:end_element, {name}, state) do
    IO.inspect("Finish parsing element #{name}")
    [{:end_element, name} | state]
  end

  def handle_event(:characters, chars, state) do
    IO.inspect("Receive characters #{chars}")
    [{:chacters, chars} | state]
  end
end
```

Then start parsing XML documents with:

```elixir
initial_state = []

Saxy.parse_string(data, MyEventHandler, initial_state)
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

### Benchmarking

Benchmarking in XML is hard and highly depends on the complexity of the
document. Saxy usually yields **1.4 times** better than [Erlsom](https://github.com/willemdj/erlsom)
in benchmark results. With deeply nested documents, it is particularly noticeably
faster with [**4.35 times faster**](https://github.com/qcam/saxy-bench#soccer-11mb-xml-file-1).

The benchmark suite can be found in [this repository](https://github.com/qcam/saxy-bench).

### Limitations

* No XSD supported.
* No DTD supported, when the parser encounters a `<!DOCTYPE`, it simply stops parsing.

## Where did the name come from?

![Sa xi Chuong Duong](http://www.alan.vn/files/posts/made-in-viet-nam/2017/03/xa-xi-chuong-duong-1488861958.jpg)

☝️  Sa Xi, pronounced like `sa-see`, is an awesome soft drink made by [Chuong Duong](http://www.cdbeco.com.vn/en).

## Contributing

If you have any issues or ideas, feel free to write to https://github.com/qcam/saxy/issues.

To start developing:

1. Fork the repository.
2. Write your code and related tests.
3. Create a pull request at https://github.com/qcam/saxy/pulls.
