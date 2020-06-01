alias Bench.NoopHandler

inputs =
  Map.new(Path.wildcard("samples/*.*"), fn sample ->
    {sample, Path.expand(sample)}
  end)

bench_options = [
  time: 10,
  memory_time: 2,
  inputs: inputs
]

continue_file = fn tail, {io, offset, chunk} ->
  case :file.pread(io, offset, chunk) do
    {:ok, data} ->
      {<<tail::binary, data::binary>>, {io, offset + chunk, chunk}}

    :oef ->
      {tail, {io, offset, chunk}}
  end
end

saxy_parser = fn file_path ->
  stream = File.stream!(file_path, [], 1024)
  {:ok, _state} = Saxy.parse_stream(stream, NoopHandler, [])
end

erlsom_parser = fn file_path ->
  {:ok, io} = File.open(file_path, [:binary])

  try do
    cont_state = {io, 0, 1024}

    options = [{:continuation_function, continue_file, cont_state}]

    {:ok, _, _} = :erlsom.parse_sax("", [], &NoopHandler.handle_event/2, options)
  after
    File.close(io)
  end
end

xmerl_parser = fn file_path ->
  options = [
    event_fun: fn _, _, state -> state end,
    event_state: :foo
  ]

  {:ok, :foo, _} = :xmerl_sax_parser.file(file_path, options)
end

Benchee.run(
  %{
    "Saxy (apple)" => saxy_parser,
    "Erlsom (apple)" => erlsom_parser,
    "Xmerl (apple)" => xmerl_parser
  },
  bench_options
)
