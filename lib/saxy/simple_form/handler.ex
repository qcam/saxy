defmodule Saxy.SimpleForm.Handler do
  @moduledoc false

  @behaviour Saxy.Handler

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:start_element, {tag_name, attributes}, state) do
    {stack, options} = state
    tag = {tag_name, attributes, []}

    {:ok, {[tag | stack], options}}
  end

  def handle_event(:characters, chars, state) do
    {stack, options} = state
    [{tag_name, attributes, content} | stack] = stack

    current = {tag_name, attributes, [chars | content]}

    {:ok, {[current | stack], options}}
  end

  def handle_event(:end_element, tag_name, state) do
    {stack, options} = state
    [{^tag_name, attributes, content} | stack] = stack

    current = {tag_name, attributes, Enum.reverse(content)}

    case stack do
      [] ->
        {:ok, {[current], options}}

      [parent | rest] ->
        {parent_tag_name, parent_attributes, parent_content} = parent
        parent = {parent_tag_name, parent_attributes, [current | parent_content]}
        {:ok, {[parent | rest], options}}
    end
  end

  def handle_event(:end_document, _, state) do
    {:ok, state}
  end
end
