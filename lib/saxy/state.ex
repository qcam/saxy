defmodule Saxy.State do
  @moduledoc false

  @enforce_keys [:handler, :user_state, :prolog, :expand_entity]

  defstruct @enforce_keys ++ [stack: []]
end
