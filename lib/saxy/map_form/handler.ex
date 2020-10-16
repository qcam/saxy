defmodule Saxy.MapForm.Handler do
  @moduledoc false

  @behaviour Saxy.Handler

  defmodule State do
    defstruct elems: %{}
  end

  # Behavior Implementation --------------------------------------------------
  # --------------------------------------------------------------------------
  @spec handle_event(
          :start_document | :start_element | :characters | :end_element | :end_document,
          any,
          __MODULE__.State.t()
        ) :: {:ok, __MODULE__.State.t()}
  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, %State{} = state) do
    {:ok, %{state | elems: :top}}
  end

  def handle_event(:end_document, _data, %State{} = state) do
    {:ok, state}
  end

  def handle_event(:start_element, {name, attrs}, %State{elems: elems} = state) do
    {:ok, %{state | elems: [%{name: name, attrs: attrs, ord: 0, text: nil} | elems]}}
  end

  def handle_event(:end_element, _name, %State{elems: [elem | rest]} = state) do
    {:ok, %{state | elems: finish_element(elem, rest)}}
  end

  def handle_event(:characters, chars, %State{elems: [elem | rest]} = state) do
    {:ok, %{state | elems: [add_text(elem, String.trim(chars)) | rest]}}
  end

  # --------------------------------------------------------------------------
  # --------------------------------------------------------------------------
  # return the accumulator once the stack top is reached
  # for consistency, ensure that element name is the top level key
  defp finish_element(%{name: name} = elems, :top) do
    %{name => elems}
  end

  # on element_end update the parent with the current element
  defp finish_element(elem, [parent | rest] = _elems) do
    # 1. Implicit transition to array of elements when more than one is detected
    # 2. Keep track of element order by 'ord' field, not by forcing list order which would be inefficient
    #    (most use cases don't care about the order, and for those that do care sort_by(:ord) will do)
    new_elem =
      case parent[elem.name] do
        nil -> elem
        [other | _rest] = others -> [%{elem | ord: other.ord + 1} | others]
        other -> [%{elem | ord: other.ord + 1} | [other]]
      end

    [Map.put(parent, elem.name, new_elem) | rest]
  end

  # Ignore empty strings
  defp add_text(elem, "") do
    elem
  end

  # Assume there is only one text element per div
  defp add_text(elem, chars) do
    Map.put(elem, :text, chars)
  end
end
