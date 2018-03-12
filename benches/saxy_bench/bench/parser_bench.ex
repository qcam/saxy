defmodule EventHandler do
  # Handler for Saxy
  def handle_event(event_type, event_data, acc) do
    {:ok, [{event_type, event_data} | acc]}
  end

  # Handler for Erlsom
  def handle_event(event, acc) do
    [event | acc]
  end
end

xml = File.read!("./rss.txt")

Benchee.run(%{
  "saxy"    => fn -> {:ok, _state} = Saxy.parse_string(xml, EventHandler, []) end,
  "erlsom" => fn -> {:ok, _, _} = :erlsom.parse_sax(xml, [], &EventHandler.handle_event/2) end
}, time: 5)
