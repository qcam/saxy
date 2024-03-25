# Getting started with SAX

This guide is an introduction of how you could parse a XML document in SAX mode
with Saxy.

## SAX (Simple API for XML)

SAX is an event driven algorithm to parse XML documents, which means that during
parsing, a SAX parser will emit any meaningful data of the document such as
start tag to a pre-configured handler, then the handler decides how to process
with the emitted data.

SAX is especially useful when it comes to large file parsing, because unlike DOM
parsing, it does not require fitting the whole parsed document into memory (for
XPath operations for example).

Parsing in SAX mode is efficient, but it would take some time to get used to.
This guide is here to help you get over it.

## Implement the handler

Given a XML document as below needs to be parsed, and the desired outcome
will be a list of foods with name, price and description.

```XML
<?xml version="1.0" encoding="UTF-8"?>
<breakfast_menu>
  <food>
    <name>Belgian Waffles</name>
    <price>$5.95</price>
    <description>Two of our famous Belgian Waffles with plenty of real maple syrup</description>
  </food>
  <food>
    <name>Strawberry Belgian Waffles</name>
    <price>$7.95</price>
    <description>Light Belgian waffles covered with strawberries and whipped cream</description>
  </food>
</breakfast_menu>
```

To parse a XML document the SAX way with Saxy, first you need to implement a
handler.

Let's start with handling the start and end events of the document. No action to
take here, we simply return whatever passed in.

```
defmodule FoodHandler do
  @behaviour Saxy.Handler

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _, state) do
    {:ok, state}
  end
end
```

Next we will be handling the `<food>` element. The action will be very simple as
well.

* When `<food>` element starts, we put a new struct into the food list.
* When `<food>` element ends, we do nothing but return the list.

To make it clear, let's call the state `foods` instead of `state`.

    defmodule FoodHandler do
      @behaviour Saxy.Handler

      def handle_event(:start_element, {name, _attributes}, foods) do
        if name == "food" do
          {:ok, [%Food{} | foods]}
        else
          {:ok, foods}
        end
      end

      def handle_event(:end_element, _data, foods) do
        {:ok, foods}
      end
    end

Now we shall start handling `<name>` and its content. But we encounter a problem:
`:characters` event, which we are supposed to get "Belgian Waffles" for the
first food name does not include which tag it belongs to.

So we need to somehow cache the current tag that is being parsed, let's revise
our handler a little bit.

    def handle_event(:start_element, {tag_name, _attributes}, {current_tag, foods}) do
      if tag_name == "food" do
        foods = [%Food{} | foods]
        {:ok, {tag_name, foods}}
      else
        {:ok, {tag_name, foods}}
      end
    end

With this now we can import the content of "name", and probably other food
properties too.

    def handle_event(:characters, content, {current_tag, foods}) do
      [current_food | foods] = foods

      food =
        case current_tag do
          "name" ->
            Map.put(current_food, :name, content)

          "price" ->
            Map.put(current_food, :price, content)

          "description" ->
            Map.put(current_food, :description, content)

          _other ->
            current_food
        end

      {:ok, {"food", [food | foods]}}
    end

As now we have implemented the event handler, it is time to parse the document.

    document = File.read!("/path/to/the/file")
    Saxy.parse_string(document, {nil, []}, FoodHandler)
    {:ok,
     [
       %Food{name: "Belgian Waffles", price: "$5.95", description: "Two of our famous Belgian Waffles with plenty of real maple syrup"},
       %Food{name: "Strawberry Belgian Waffles", price: "$7.95", description: "Light Belgian waffles covered with strawberries and whipped cream"},
     ]}
