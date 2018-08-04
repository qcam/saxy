defmodule Saxy.Buffering do
  @moduledoc false

  defmacro buffering_parse_fun(fun_name, arity, token \\ "")
  defmacro buffering_parse_fun(fun_name, arity, token) do
    params_splice =
      case arity do
        5 -> quote(do: [cont, original, pos, state])
        6 -> quote(do: [cont, original, pos, state, acc1])
        7 -> quote(do: [cont, original, pos, state, acc1, acc2])
        8 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3])
        9 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3, acc4])
        10 -> quote(do: [cont, original, pos, state, acc1, acc2, acc3, acc4, acc5])
      end

    context_fun =
      case arity do
        5 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state)))
        6 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state, acc1)))
        7 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2)))
        8 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3)))
        9 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3, acc4)))
        10 -> quote(do: &(unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3, acc4, acc5)))
      end

    if token == :utf8 do
      quote do
        # 2-byte/3-byte/4-byte unicode
        def unquote(fun_name)(<<1::size(1), rest::size(7)>>, unquote_splicing(params_splice))
            when cont != :done do
          Saxy.Buffering.maybe_buffer(<<1::size(1), rest::size(7)>>, cont, original, unquote(context_fun))
        end

        # 3-byte/4-byte unicode
        def unquote(fun_name)(<<1::size(1), 1::size(1), rest::6-bits, next_char::1-bytes>>, unquote_splicing(params_splice))
            when cont != :done do
          Saxy.Buffering.maybe_buffer(<<1::size(1), 1::size(1), rest::6-bits, next_char::binary>>, cont, original, unquote(context_fun))
        end

        # # 4-byte unicode
        def unquote(fun_name)(<<1::size(1), 1::size(1), 1::size(1), rest::5-bits, next_char::2-bytes>>, unquote_splicing(params_splice))
            when cont != :done do
          Saxy.Buffering.maybe_buffer(<<1::size(1), 1::size(1), 1::size(1), rest::5-bits, next_char::binary>>, cont, original, unquote(context_fun))
        end
      end
    else
      quote do
        def unquote(fun_name)(unquote(token), unquote_splicing(params_splice))
            when cont != :done do
          Saxy.Buffering.maybe_buffer(unquote(token), cont, original, unquote(context_fun))
        end
      end
    end
  end

  @compile {:inline, [maybe_buffer: 4]}

  def maybe_buffer(<<buffer::bits>>, cont, original, context_fun) do
    case do_buffer(cont) do
      :done ->
        context_fun.(buffer, :done, original)

      {:ok, {cont_bytes, next_cont}} ->
        buffer = [buffer | cont_bytes] |> IO.iodata_to_binary()
        original = [original | cont_bytes] |> IO.iodata_to_binary()
        context_fun.(buffer, next_cont, original)
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
