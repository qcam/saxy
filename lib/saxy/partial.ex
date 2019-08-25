defmodule Saxy.Partial do
  alias Saxy.Parser

  @moduledoc ~S"""
  Support parsing an XML document partially. This module is useful when
  the XML document cannot be turned into a `Stream` e.g over sockets.
  """

  @enforce_keys [:context_fun]
  defstruct @enforce_keys

  @opaque t() :: %__MODULE__{
            context_fun: function()
          }

  @spec new(
          handler :: module() | function(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, fun :: function()} | {:error, exception :: Saxy.ParseError.t()}
  def new(handler, initial_state, options \\ [])
      when is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %Saxy.State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    with {:halted, context_fun} <- Parser.Prolog.parse(<<>>, true, <<>>, 0, state) do
      {:ok, %__MODULE__{context_fun: context_fun}}
    end
  end

  @spec parse(
          data :: binary,
          context_fun :: function()
        ) :: {:ok, state :: term()} | {:cont, partial :: t()} | {:error, exception :: Saxy.ParseError.t()}
  def parse(data, %__MODULE__{context_fun: context_fun} = partial)
      when is_binary(data) do
    case context_fun.(data, true) do
      {:halted, context_fun} ->
        {:cont, %{partial | context_fun: context_fun}}

      {:ok, state} ->
        {:ok, state.user_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finishes parsing partial. Please note that the parsing document needs to be finished in order
  to extract state.
  """

  @spec finish(context_fun :: function()) :: {:ok, state :: term()} | {:error, exception :: Saxy.ParseError.t()}

  def finish(%__MODULE__{context_fun: context_fun}) do
    with {:ok, state} <- context_fun.(<<>>, false) do
      {:ok, state.user_state}
    end
  end
end
