Saxy
===

Saxy (Sá xị) is a XML SAX parser in Elixir that focuses on speed and standard compliance.

Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

## Features

* SAX parsing for XML 1.0.
* Large file parsing in native Elixir stream.
* XML Simple DOM.
* Quickly return during parsing process.
* Manual entity references conversion.

## Installation

Add `:saxy` to your `mix.exs`.

```elixir
def deps do
  [{:saxy, "~> 0.4.0"}]
end
```

## Overview

Full documentation is available on [HexDocs](https://hexdocs.pm/saxy/).

### SAX Parser

A SAX event handler implementation is required before starting parsing.

```elixir
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
    MyHTMLEntityConverter.convert(reference_name)
  end
end
```

Then parse your XML with:

```elixir
initial_state = []

Saxy.parse_string(data, MyEventHandler, initial_state)
```

### Streaming parsing

Saxy's SAX parser accepts file stream as the input.

```elixir
stream = File.stream!("/path/to/file")

Saxy.parse_stream(stream, MyEventHandler, initial_state)
```

Or it even accepts a normal stream.

```elixir
stream = File.stream!("/path/to/file") |> Stream.filter(&(&1 != "\n"))

Saxy.parse_stream(stream, MyEventHandler, initial_state)
```

### Simple form parsing

Saxy also supports parsing XML documents into simple-form format.

```elixir
Saxy.SimpleForm.parse_string(data)

[
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
]
```

### Limitations

* No XSD supported.
* No DTD supported, when the parser encounters a `<!DOCTYPE`, it simply stops
  parsing.
* Manual conversion of entity reference is required.

## Where does the name come from?

![Sa xi Chuong Duong](http://www.alan.vn/files/posts/made-in-viet-nam/2017/03/xa-xi-chuong-duong-1488861958.jpg)

👆 Sa xi is an awesome soft drink that made by [Chuong Duong](http://www.cdbeco.com.vn/en).

## Contributing

If you have any issues or ideas, feel free to write to https://github.com/qcam/saxy/issues.

To start developing:

1. Fork the repository.
2. Write your code and related tests.
3. Create a pull request at https://github.com/qcam/saxy/pulls.
