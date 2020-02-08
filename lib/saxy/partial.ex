defmodule Saxy.Partial do
  alias Saxy.Parser

  @moduledoc ~S"""
  Supports parsing an XML document partially. This module is useful when
  the XML document cannot be turned into a `Stream` e.g over sockets.

  ## Example

      iex> {:ok, partial} = Saxy.Partial.new(StackHandler, [])
      iex> {:cont, partial} = Saxy.Partial.parse(partial, "<foo>")
      iex> {:cont, partial} = Saxy.Partial.parse(partial, "</foo>")
      iex> Saxy.Partial.terminate(partial)
      {:ok,
       [
         end_document: {},
         end_element: "foo",
         start_element: {"foo", []},
         start_document: []
       ]}

  """

  @enforce_keys [:context_fun]
  defstruct @enforce_keys

  @opaque t() :: %__MODULE__{
            context_fun: function()
          }

  @doc """
  Builds up a `Saxy.Partial`, which can be used for later parsing.
  """

  @spec new(
          handler :: module(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, partial :: t()} | {:error, exception :: Saxy.ParseError.t()}

  def new(handler, initial_state, options \\ [])
      when is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)
    character_data_max_length = Keyword.get(options, :character_data_max_length, :infinity)

    state = %Saxy.State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity,
      character_data_max_length: character_data_max_length
    }

    with {:halted, context_fun} <- Parser.Prolog.parse(<<>>, true, <<>>, 0, state) do
      {:ok, %__MODULE__{context_fun: context_fun}}
    end
  end

  @doc """
  Continue parsing next chunk of the document with a partial.

  This function can return in 3 ways:

  * `{:cont, partial}` - The parsing process has not been terminated.
  * `{:halt, user_state}` - The parsing process has been terminated, usually because of fast return.
  * `{:error, exception}` - The parsing process has erred.

  """

  @spec parse(
          partial :: t(),
          data :: binary
        ) ::
          {:cont, partial :: t()}
          | {:halt, state :: term()}
          | {:error, exception :: Saxy.ParseError.t()}

  def parse(%__MODULE__{context_fun: context_fun} = partial, data)
      when is_binary(data) do
    case context_fun.(data, true) do
      {:halted, context_fun} ->
        {:cont, %{partial | context_fun: context_fun}}

      {:ok, state} ->
        {:halt, state.user_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Terminates the XML document parsing.
  """

  @spec terminate(partial :: t()) :: {:ok, state :: term()} | {:error, exception :: Saxy.ParseError.t()}

  def terminate(%__MODULE__{context_fun: context_fun}) do
    with {:ok, state} <- context_fun.(<<>>, false) do
      {:ok, state.user_state}
    end
  end
end
