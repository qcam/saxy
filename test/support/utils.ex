defmodule SaxyTest.Utils do
  import ExUnit.Assertions

  def remove_indents(xml) do
    xml
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.join()
  end

  def parse(data, handler, state, options \\ []) do
    assert result = Saxy.parse_string(data, handler, state, options)
    assert Saxy.parse_stream([data], handler, state, options) == result

    result
  end

  def read_fixture(name) do
    "test/support/fixture/"
    |> Kernel.<>(name)
    |> Path.relative_to_cwd()
    |> File.read!()
  end

  def stream_fixture(name) do
    "test/support/fixture/"
    |> Kernel.<>(name)
    |> Path.relative_to_cwd()
    |> File.stream!([], 100)
  end
end
