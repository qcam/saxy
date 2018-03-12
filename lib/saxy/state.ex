defmodule Saxy.State do
  @moduledoc false

  @enforce_keys [:handler, :user_state, :prolog]

  defstruct @enforce_keys ++ [stack: []]
end
