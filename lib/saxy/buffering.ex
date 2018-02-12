defmodule Saxy.Buffering do
  def maybe_commit(buffer, position)
      when is_binary(buffer) and byte_size(buffer) > 4096 do
    {subbuffer(buffer, position), 0}
  end

  def maybe_commit(buffer, position), do: {buffer, position}

  def subbuffer(buffer, 0), do: buffer

  def subbuffer(buffer, position)
      when position <= byte_size(buffer) do
    buffer_size = byte_size(buffer)
    :binary.part(buffer, {buffer_size, -(buffer_size - position)})
  end

  def maybe_buffer(buffer, position, cont)
      when byte_size(buffer) <= position + 100 do
    case do_buffer(buffer, cont) do
      {:ok, {new_buffer, next_cont}} ->
        maybe_buffer(new_buffer, position, next_cont)

      :done ->
        {:ok, buffer, position, :binary}
    end
  end

  def maybe_buffer(buffer, position, cont) do
    {:ok, buffer, position, cont}
  end

  defp do_buffer(_buffer, :binary), do: :done

  defp do_buffer(buffer, cont) do
    case next_cont(cont) do
      {:suspended, next_bytes, reducer} ->
        next_cont = fn _, _ -> reducer.({:cont, :first}) end
        {:ok, {buffer <> next_bytes, next_cont}}

      {:halted, _} ->
        :done
    end
  end

  defp next_cont(cont) do
    Enumerable.reduce(cont, {:cont, :first}, fn
      next_bytes, :first -> {:suspend, next_bytes}
      next_bytes, _ -> {:cont, next_bytes}
    end)
  end
end
