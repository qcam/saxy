defmodule SaxyTest.Utils do
  def remove_indents(xml) do
    xml
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.join()
  end
end
