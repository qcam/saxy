defmodule Saxy.SimpleForm do
  def parse_string(data) when is_binary(data) do
    Saxy.parse_string(data, __MODULE__.Handler, [])
  end
end
