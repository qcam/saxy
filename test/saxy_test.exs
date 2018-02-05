defmodule SaxyTest do
  use ExUnit.Case
  doctest Saxy

  test "greets the world" do
    assert Saxy.hello() == :world
  end
end
