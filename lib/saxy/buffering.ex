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
    quoted_fun =
      case arity do
        5 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5)))
        6 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5, acc1)))
        7 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5, acc1, acc2)))
        8 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5, acc1, acc2, acc3)))
        9 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5, acc1, acc2, acc3, acc4)))
        10 -> quote(do: &(unquote(fun_name)(&1, &2, &3, &4, &5, acc1, acc2, acc3, acc4, acc5)))
      end

    quote do
      def unquote(fun_name)(unquote(token), unquote_splicing(quoted_params))
          when cont != :done do
        Saxy.Buffering.maybe_buffer(unquote(token), cont, original, pos, state, unquote(quoted_fun))
      end
    end
  end

  @compile {:inline, [maybe_buffer: 6]}

  def maybe_buffer(<<buffer::bits>>, cont, original, pos, state, fun) do
    case do_buffer(cont) do
      :done ->
        fun.(buffer, :done, original, pos, state)

      {:ok, {cont_bytes, next_cont}} ->
        buffer = [buffer | cont_bytes] |> IO.iodata_to_binary()
        original = [original | cont_bytes] |> IO.iodata_to_binary()
        fun.(buffer, next_cont, original, pos, state)
    end
  end

  @compile {:inline, [maybe_commit: 2]}

  def maybe_commit(buffer, pos) do
    buffer_size = byte_size(buffer)

    binary_part(buffer, pos, buffer_size - pos)
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
