defmodule Saxy.Parser.Partial do
  alias Saxy.Parser

  @moduledoc ~S"""
  The Partial module allows partially parsing an XML document, then continuing parsing where 
  it left off using the context returned from the previous call.
  """

  @spec init(
          handler :: module() | function(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, fun :: function()}, {:error, exception :: Saxy.ParseError.t()}
  def init(handler, initial_state, options \\ [])
      when is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %Saxy.State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    case Parser.Prolog.parse(<<>>, true, <<>>, 0, state) do
      {:halted, fun} -> {:ok, fun}
      {:error, _reason} = error -> error
    end
  end

  @spec parse(
          data :: binary,
          context_fun :: function()
        ) :: {:ok, fun :: function()}, {:error, exception :: Saxy.ParseError.t()}
  def parse(data, context_fun) when is_binary(data) do
    case context_fun.(data, true) do
      {:halted, fun} -> {:ok, fun}
      {:error, _reason} = error -> error
     end
  end

  @spec finish(
          context_fun :: function()
        ) :: {:ok, state :: term()}, {:error, exception :: Saxy.ParseError.t()}
  def finish(context_fun) do
    case context_fun.(<<>>, false) do
      {:ok, state} -> {:ok, state.user_state}
      {:error, reason} -> {:error, reason}
    end
  end

end
