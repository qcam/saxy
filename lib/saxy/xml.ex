defmodule Saxy.XML do
  alias Saxy.Builder

  @moduledoc """
  Helper functions for building XML elements.
  """

  @type characters() :: {:characters, String.t()}

  @type cdata() :: {:cdata, String.t()}

  @type comment() :: {:comment, String.t()}

  @type ref() :: entity_ref() | hex_ref() | dec_ref()

  @type entity_ref() :: {:reference, {:entity, String.t()}}

  @type hex_ref() :: {:reference, {:hexadecimal, integer()}}

  @type dec_ref() :: {:reference, {:decimal, integer()}}

  @type processing_instruction() :: {:processing_instruction, name :: String.t(), instruction :: String.t()}

  @type element() :: {
          name :: String.t(),
          attributes :: [{key :: String.t(), value :: String.t()}],
          children :: [content]
        }

  @type content() :: element() | characters() | cdata() | ref() | comment() | String.t()

  @compile {
    :inline,
    [
      element: 3,
      characters: 1,
      cdata: 1,
      comment: 1,
      reference: 2,
      processing_instruction: 2
    ]
  }

  @doc """
  Builds empty element in simple form.
  """

  @spec empty_element(
          name :: term(),
          attributes :: [{key :: term(), value :: term()}]
        ) :: element()

  def empty_element(name, attributes) when not is_nil(name) do
    {
      to_string(name),
      attributes(attributes),
      []
    }
  end

  @doc """
  Builds element in simple form.
  """

  @spec element(
          name :: term(),
          attributes :: [{key :: term(), value :: term()}],
          children :: list()
        ) :: element()

  def element(name, attributes, children) when not is_nil(name) and is_list(children) do
    {
      to_string(name),
      attributes(attributes),
      children(children)
    }
  end

  def element(name, attributes, child) when not is_nil(name) do
    element(name, attributes, [child])
  end

  @doc """
  Builds characters in simple form.
  """

  @spec characters(text :: term()) :: characters()

  def characters(text) do
    {:characters, to_string(text)}
  end

  @doc """
  Builds CDATA in simple form.
  """

  @spec cdata(text :: term()) :: cdata()

  def cdata(text) do
    {:cdata, to_string(text)}
  end

  @doc """
  Builds comment in simple form.
  """

  @spec comment(text :: term()) :: comment()

  def comment(text) do
    {:comment, to_string(text)}
  end

  @doc """
  Builds reference in simple form.
  """

  @spec reference(
          character_type :: :entity | :hexadecimal | :decimal,
          value :: term()
        ) :: ref()

  def reference(:entity, name) when not is_nil(name) do
    {:reference, {:entity, to_string(name)}}
  end

  def reference(character_type, integer)
      when character_type in [:hexadecimal, :decimal] and is_integer(integer) do
    {:reference, {character_type, integer}}
  end

  @doc """
  Builds processing instruction in simple form.
  """

  @spec processing_instruction(
          name :: String.t(),
          instruction :: String.t()
        ) :: processing_instruction()

  def processing_instruction(name, instruction) when not is_nil(name) do
    {:processing_instruction, to_string(name), instruction}
  end

  defp attributes(attributes) do
    Enum.map(attributes, &attribute/1)
  end

  defp children(children, acc \\ [])

  defp children([binary | children], acc) when is_binary(binary) do
    children(children, [binary | acc])
  end

  defp children([{type, _} = form | children], acc)
       when type in [:characters, :comment, :cdata, :reference],
       do: children(children, [form | acc])

  defp children([{_name, _attributes, _content} = form | children], acc) do
    children(children, [form | acc])
  end

  defp children([], acc), do: Enum.reverse(acc)

  defp children([child | children], acc) do
    children(children, child |> Builder.build() |> List.wrap() |> Enum.reverse() |> Kernel.++(acc))
  end

  defp attribute({name, value}) when not is_nil(name) do
    {
      to_string(name),
      to_string(value)
    }
  end
end
