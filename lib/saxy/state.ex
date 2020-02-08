defmodule Saxy.State do
  @moduledoc false

  @enforce_keys [:handler, :user_state, :prolog, :expand_entity, :character_data_max_length]

  defstruct @enforce_keys ++ [stack: []]
end
