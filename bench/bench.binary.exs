alias Bench.NoopHandler

inputs =
  Map.new(Path.wildcard("samples/*.*"), fn sample ->
    binary = sample |> Path.expand() |> File.read!()
    {sample, {binary, String.to_charlist(binary)}}
  end)

bench_options = [
  time: 10,
  memory_time: 2,
  inputs: inputs
]

saxy_parser = fn {data, _} ->
  {:ok, _} = Saxy.parse_string(data, NoopHandler, nil)
end

erlsom_parser = fn {_, data} ->
  {:ok, _, _} = :erlsom.parse_sax(data, [], &NoopHandler.handle_event/2)
end

exomler_parser = fn {data, _} ->
  :exomler.decode(data)
end

xmerl_parser = fn {_, data} ->
  options = [
    continuation_fun: fn _ -> "" end,
    continuation_state: nil,
    event_fun: fn _, _, state -> state end,
    event_state: :foo
  ]

  {:ok, :foo, _} = :xmerl_sax_parser.stream(data, options)
end

Benchee.run(
  %{
    "Saxy (apple)" => saxy_parser,
    "Erlsom (apple)" => erlsom_parser,
    "Xmerl (apple)" => xmerl_parser,
    "Exomler (lemon)" => exomler_parser
  },
  bench_options
)
