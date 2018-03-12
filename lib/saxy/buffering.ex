defmodule Saxy.Buffering do
  @moduledoc false

  defmacro buffering_parse_fun(fun_name, arity, token \\ "")
  defmacro buffering_parse_fun(fun_name, arity, token) do
    quoted_params =
      case arity do
        5 -> quote(do: [cont, original, pos, state])
        6 -> quote(do: [cont, original, pos, state, acc1])
        7 -> quote(do: [cont, original, pos, state, acc1, acc2])
        8 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3])
        9 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3, acc4])
        10 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3, acc4, acc5])
      end
    quoted_mfa =
      case arity do
        5 -> quote(do: {__MODULE__, unquote(fun_name), []})
        6 -> quote(do: {__MODULE__, unquote(fun_name), [acc1]})
        7 -> quote(do: {__MODULE__, unquote(fun_name), [acc1, acc2]})
        8 -> quote(do: {__MODULE__, unquote(fun_name), [acc1, acc2, acc3]})
        9 -> quote(do: {__MODULE__, unquote(fun_name), [acc1, acc2, acc3, acc4]})
        10 -> quote(do: {__MODULE__, unquote(fun_name), [acc1, acc2, acc3, acc4, acc5]})
      end

    quote do
      def unquote(fun_name)(unquote(token), unquote_splicing(quoted_params))
          when cont != :done do
        Saxy.Buffering.maybe_buffer(unquote(token), cont, original, pos, state, unquote(quoted_mfa))
      end
    end
  end

  @compile {:inline, [maybe_buffer: 6]}

  def maybe_buffer(<<buffer::bits>>, cont, original, pos, state, {mod, fun, args}) do
    case do_buffer(cont) do
      :done ->
        apply(mod, fun, [buffer, :done, original, pos, state] ++ args)

      {:ok, {cont_bytes, next_cont}} ->
        buffer = [buffer | cont_bytes] |> IO.iodata_to_binary()
        original = [original | cont_bytes] |> IO.iodata_to_binary()
        apply(mod, fun, [buffer, next_cont, original, pos, state] ++ args)
    end
  end

  def maybe_commit(buffer, pos, :done, _max), do: {buffer, pos}

  def maybe_commit(buffer, pos, _cont, max) do
    buffer_size = byte_size(buffer)

    if buffer_size < max do
      {buffer, pos}
    else
      {binary_part(buffer, pos, buffer_size - pos), 0}
    end
  end

  defp do_buffer(cont) do
    case next_cont(cont) do
      {:suspended, next_bytes, reducer} ->
        next_cont = fn _, _ -> reducer.({:cont, :first}) end
        {:ok, {next_bytes, next_cont}}

      {:done, _} -> :done

      {:halted, _} -> :done
    end
  end

  defp next_cont(cont) do
    Enumerable.reduce(cont, {:cont, :first}, fn
      next_bytes, :first -> {:suspend, next_bytes}
      next_bytes, _ -> {:cont, next_bytes}
    end)
  end
end
