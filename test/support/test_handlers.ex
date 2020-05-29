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

defmodule Saxy.TestHandlers.HaltHandler do
  @behaviour Saxy.Handler

  def handle_event(event_type, _event_data, event_type) do
    {:halt, :halt_return}
  end

  def handle_event(event_type, event_data, [event_type, event_data]) do
    {:halt, :halt_return}
  end

  def handle_event(_, _, event) do
    {:ok, event}
  end
end

defmodule Saxy.TestHandlers.WrongHandler do
  @behaviour Saxy.Handler

  def handle_event(_event_type, _event_data, _acc) do
    :something_wrong
  end
end

# For docs test

defmodule MyTestHandler do
  @behaviour Saxy.Handler

  def handle_event(:start_document, prolog, state) do
    {:ok, [{:start_document, prolog} | state]}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, [{:end_document} | state]}
  end

  def handle_event(:start_element, {name, attributes}, state) do
    {:ok, [{:start_element, name, attributes} | state]}
  end

  def handle_event(:end_element, name, state) do
    {:ok, [{:end_element, name} | state]}
  end

  def handle_event(:characters, chars, state) do
    {:ok, [{:chacters, chars} | state]}
  end
end

defmodule Person do
  @derive {
    Saxy.Builder,
    name: "person", attributes: [:gender], children: [:name]
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
