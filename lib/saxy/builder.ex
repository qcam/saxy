defprotocol Saxy.Builder do
  @moduledoc """
  Protocol for building XML content.

  ## Deriving

  This helps to generate XML content simple form in trivial cases.

  There are a few required options:

  * `name` - tag name of generated XML element.
  * `attributes` - fields to be encoded as attributes.
  * `children` - fields to be encoded as element children.

  ## Examples

      defmodule Person do
        @derive {Saxy.Builder, name: "person", attributes: [:gender], children: [:name]}

        defstruct [:name, :gender]
      end

      iex> person = %Person{name: "Alice", gender: "female"}
      iex> Saxy.Builder.build(person)
      {"person", [{"gender", "female"}], [{:characters, "Alice"}]}

  Custom implementation could be done by implementing protocol:

      defmodule User do
        defstruct [:username, :name]
      end

      defimpl Saxy.Builder do
        import Saxy.XML

        def build(user) do
          element(
            "Person",
            [{"userName", user.username}],
            [element("Name", [], user.name)]
          )
        end
      end

      iex> user = %User{name: "Alice", username: "alice99"}
      iex> Saxy.Builder.build(user)
      {"Person", [{"userName", "alice99"}], [{"Name", [], [{:characters, "Alice"}]}]}
  """

  @doc """
  Builds `content` to XML content in simple form.
  """

  @spec build(content :: term()) :: Saxy.XML.content()

  def build(content)
end

defimpl Saxy.Builder, for: Any do
  defmacro __deriving__(module, _struct, options) do
    name = Keyword.fetch!(options, :name)
    attribute_fields = Keyword.get(options, :attributes, [])
    children_fields = Keyword.get(options, :children, [])

    quote do
      defimpl Saxy.Builder, for: unquote(module) do
        def build(struct) do
          import Saxy.XML

          attributes =
            struct
            |> Map.take(unquote(attribute_fields))
            |> Enum.to_list()

          children =
            struct
            |> Map.take(unquote(children_fields))
            |> Map.values()

          element(unquote(name), attributes, children)
        end
      end
    end
  end

  def build(%_{} = struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      Saxy.Builder.Content doesn't know how to build this struct.

      You can derive the implementation by specifying in the module.

      @derive {
        Saxy.Builder.Content,
        [name: "person",
         attributes: [:gender, :telephone],
         children: [:name]]
      }
      defstruct ...
      """
  end
end

defimpl Saxy.Builder, for: Tuple do
  def build({type, _} = form)
      when type in [:characters, :comment, :cdata, :reference],
      do: form

  def build({_name, _attributes, _content} = form), do: form

  def build(other) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: other,
      description: "cannot build content with tuple"
  end
end

defimpl Saxy.Builder, for: BitString do
  def build(binary) when is_binary(binary) do
    Saxy.XML.characters(binary)
  end

  def build(bitstring) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot build content with a bitstring"
  end
end

defimpl Saxy.Builder, for: Atom do
  def build(nil), do: ""

  def build(value) do
    value
    |> Atom.to_string()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: Integer do
  def build(value) do
    value
    |> Integer.to_string()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: Float do
  def build(value) do
    value
    |> Float.to_string()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: NaiveDateTime do
  def build(value) do
    value
    |> NaiveDateTime.to_iso8601()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: DateTime do
  def build(value) do
    value
    |> DateTime.to_iso8601()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: Date do
  def build(value) do
    value
    |> Date.to_iso8601()
    |> Saxy.XML.characters()
  end
end

defimpl Saxy.Builder, for: Time do
  def build(value) do
    value
    |> Time.to_iso8601()
    |> Saxy.XML.characters()
  end
end
