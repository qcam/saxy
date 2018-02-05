defmodule Saxy.Handler do
  @callback handle_event(event_type :: atom, data :: tuple, user_state :: term) ::
              user_state :: term
end
