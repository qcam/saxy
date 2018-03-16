defmodule Mix.Tasks.Bench.Stream do
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
        Benchee.run(%{
          "saxy.binary" => fn ->
            string = File.read!("./samples/#{filename}.xml")
            {:ok, _state} = Saxy.parse_string(string, EventHandler, [])
          end,
          "saxy.stream" => fn ->
            stream = File.stream!("./samples/#{filename}.xml", [], 512)
            {:ok, _state} = Saxy.parse_stream(stream, EventHandler, [])
          end,
          "erlsom.binary" => fn ->
            string = File.read!("./samples/#{filename}.xml")
            {:ok, _, _} = :erlsom.parse_sax(string, [], &EventHandler.handle_event/2)
          end,
          "erlsom.stream" => fn ->
            {:ok, handle} = File.open("./samples/#{filename}.xml", [:binary])
            c_state  = {handle, 0, 512}
            options = [
              {:continuation_function, &continue_file/2, c_state}
            ]
            {:ok, _, _} = :erlsom.parse_sax("", [], &EventHandler.handle_event/2, options)
          end,
        }, time: 10)
    end
  end

  def continue_file(tail, {handle, offset, chunk}) do
    case :file.pread(handle, offset, chunk) do
      {:ok, data} ->
        {<<tail :: binary, data::binary>>, {handle, offset + chunk, chunk}}
      :oef ->
        {tail, {handle, offset, chunk}}
    end
  end
end
