# Saxy

![Sa xi Chuong Duong](http://www.alan.vn/files/posts/made-in-viet-nam/2017/03/xa-xi-chuong-duong-1488861958.jpg)

======

Saxy is a XML SAX parser which provides functions to parse XML file in both binary and streaming way.
Comply with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

## Installation

```elixir
def deps do
  [{:saxy, "~> 0.4.0"}]
end
```

## Overview

Full documentation is available on [HexDocs](https://hexdocs.pm/saxy/).

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

## Contributing

If you have any issues or ideas, feel free to write to https://github.com/qcam/saxy/issues.

To start developing:

1. Fork the repository.
2. Write your code and related tests.
3. Create a pull request at https://github.com/qcam/saxy/pulls.
