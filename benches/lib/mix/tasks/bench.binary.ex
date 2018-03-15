defmodule Mix.Tasks.Bench.Binary do
  use Mix.Task

  defmodule EventHandler do
    # Handler for Saxy
    def handle_event(event_type, event_data, acc) do
      {:ok, [{event_type, event_data} | acc]}
    end

    def handle_entity_reference(reference_name) do
      [?&, reference_name, ?;]
    end

    # Handler for Erlsom
    def handle_event(event, acc) do
      [event | acc]
    end
  end

  def run(args) do
    case args do
      [] ->
        Mix.raise("file name must be provided")

      [filename] ->
        xml = File.read!("./samples/#{filename}.xml")

        Benchee.run(%{
          "saxy"    => fn -> {:ok, _state} = Saxy.parse_string(xml, EventHandler, []) end,
          "erlsom" => fn -> {:ok, _, _} = :erlsom.parse_sax(xml, [], &EventHandler.handle_event/2) end
        }, time: 10)
    end
  end
end
