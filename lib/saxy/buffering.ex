defmodule Saxy.Buffering do
  @moduledoc false

  defmacro defhalt(fun_name, arity, token) do
    params_splice =
      case arity do
        5 -> quote(do: [original, pos, state])
        6 -> quote(do: [original, pos, state, acc1])
        7 -> quote(do: [original, pos, state, acc1, acc2])
        8 -> quote(do: [original, pos, state, acc1, acc2, acc3])
        9 -> quote(do: [original, pos, state, acc1, acc2, acc3, acc4])
        10 -> quote(do: [original, pos, state, acc1, acc2, acc3, acc4, acc5])
      end

    context_fun =
      case arity do
        5 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state))
        6 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state, acc1))
        7 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state, acc1, acc2))
        8 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state, acc1, acc2, acc3))
        9 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state, acc1, acc2, acc3, acc4))
        10 -> quote(do: &unquote(fun_name)(unquote(token) <> &1, &2, original <> &1, pos, state, acc1, acc2, acc3, acc4, acc5))
      end

    quote do
      def unquote(fun_name)(unquote(token), true, unquote_splicing(params_splice)) do
        {
          :halted,
          unquote(context_fun)
        }
      end
    end
  end

  def utf8_binaries() do
    [
      quote(do: <<1::size(1), rest::size(7)>>),
      quote(do: <<1::size(1), 1::size(1), rest::size(6), next_char::1-bytes>>),
      quote(do: <<1::size(1), 1::size(1), 1::size(1), rest::size(5), next_chars::2-bytes>>)
    ]
  end
end
