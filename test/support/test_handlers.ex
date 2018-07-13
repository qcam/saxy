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

# For docs test

defmodule Person do
  @derive {
    Saxy.Builder,
    name: "person",
    attributes: [:gender],
    children: [:name]
  }

  defstruct [:name, :gender]
end

defmodule User do
  defstruct [:username, :name]
end

defimpl Saxy.Builder, for: User do
  import Saxy.XML

  def build(user) do
    element(
      "Person",
      [{"userName", user.username}],
      [element("Name", [], user.name)]
    )
  end
end
