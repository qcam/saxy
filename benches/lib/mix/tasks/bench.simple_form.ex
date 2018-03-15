defmodule Mix.Tasks.Bench.SimpleForm do
  use Mix.Task

  def run(args) do
    case args do
      [] ->
        Mix.raise("file name must be provided")

      [filename] ->
        xml = File.read!("./samples/#{filename}.xml")

        Benchee.run(%{
          "saxy"    => fn -> {:ok, _} = Saxy.SimpleForm.parse_string(xml) end,
          "erlsom" => fn -> {:ok, _, _} = :erlsom.simple_form(xml) end
        }, time: 10)
    end
  end
end
