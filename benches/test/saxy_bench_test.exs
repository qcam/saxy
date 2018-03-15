defmodule SaxyBenchTest do
  use ExUnit.Case
  doctest SaxyBench

  test "greets the world" do
    assert SaxyBench.hello() == :world
  end
end
