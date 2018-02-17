defmodule Saxy.State do
  @moduledoc false

  @enforce_keys [:handler, :cont, :user_state, :prolog]

  defstruct @enforce_keys
end
