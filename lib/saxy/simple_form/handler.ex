defmodule Saxy.SimpleForm.Handler do
  @moduledoc false

  @behaviour Saxy.Handler

  def handle_event(:start_document, _prolog, stack) do
    {:ok, stack}
  end

  def handle_event(:start_element, {tag_name, attributes}, stack) do
    tag = {tag_name, attributes, []}
    {:ok, [tag | stack]}
  end

  def handle_event(:characters, chars, stack) do
    [{tag_name, attributes, content} | stack] = stack

    current = {tag_name, attributes, [chars | content]}

    {:ok, [current | stack]}
  end

  def handle_event(:cdata, chars, stack) do
    [{tag_name, attributes, content} | stack] = stack

    current = {tag_name, attributes, [{:cdata, chars} | content]}

    {:ok, [current | stack]}
  end

  def handle_event(:end_element, tag_name, [{tag_name, attributes, content} | stack]) do
    current = {tag_name, attributes, Enum.reverse(content)}

    case stack do
      [] ->
        {:ok, current}

      [parent | rest] ->
        {parent_tag_name, parent_attributes, parent_content} = parent
        parent = {parent_tag_name, parent_attributes, [current | parent_content]}
        {:ok, [parent | rest]}
    end
  end

  def handle_event(:end_document, _, stack) do
    {:ok, stack}
  end
end
