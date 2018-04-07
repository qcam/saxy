defmodule Saxy.TestHandlers.StackHandler do
  @behaviour Saxy.Handler

  def handle_event(event_type, event_data, acc) do
    {:ok, [{event_type, event_data} | acc]}
  end
end

defmodule Saxy.TestHandlers.FastReturnHandler do
  @behaviour Saxy.Handler

  def handle_event(_event_type, _event_data, _acc) do
    {:stop, :fast_return}
  end
end

defmodule Saxy.TestHandlers.WrongHandler do
  @behaviour Saxy.Handler

  def handle_event(_event_type, _event_data, _acc) do
    :something_wrong
  end
end
