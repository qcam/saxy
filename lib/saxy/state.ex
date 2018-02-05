defmodule Saxy.State do
  @enforce_keys [:handler, :cont, :user_state, :prolog]

  defstruct @enforce_keys
end
