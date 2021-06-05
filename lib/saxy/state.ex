defmodule Saxy.State do
  @moduledoc false

  @enforce_keys [
    :handler,
    :user_state,
    :prolog,
    :expand_entity,
    :character_data_max_length,
    :cdata_as_characters
  ]

  defstruct [stack: []] ++ @enforce_keys
end
