defmodule Saxy.Xmerl.State do
  @moduledoc false

  defstruct [
    :atom_fun,
    stack: [],
    child_count: []
  ]
end
