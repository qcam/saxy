defmodule Saxy.Buffering do
  @moduledoc false

  defmacro buffering_parse_fun(fun_name, arity, token) do
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
        5 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state))
        6 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state, acc1))
        7 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2))
        8 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3))
        9 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3, acc4))
        10 -> quote(do: &unquote(fun_name)(&1, &2, &3, pos, state, acc1, acc2, acc3, acc4, acc5))
      end

    if token == :utf8 do
      quote do
        # 2-byte/3-byte/4-byte unicode
        def unquote(fun_name)(
              <<1::size(1), rest::size(7)>>,
              :buffering,
              unquote_splicing(params_splice)
            ) do
          {
            :halted,
            <<1::size(1), rest::size(7)>>,
            original,
            unquote(context_fun)
          }
        end

        # 3-byte/4-byte unicode
        def unquote(fun_name)(
              <<1::size(1), 1::size(1), rest::6-bits, next_char::1-bytes>>,
              :buffering,
              unquote_splicing(params_splice)
            ) do
          {
            :halted,
            <<1::size(1), 1::size(1), rest::6-bits, next_char::binary>>,
            original,
            unquote(context_fun)
          }
        end

        # # 4-byte unicode
        def unquote(fun_name)(
              <<1::size(1), 1::size(1), 1::size(1), rest::5-bits, next_char::2-bytes>>,
              :buffering,
              unquote_splicing(params_splice)
            ) do
          {
            :halted,
            <<1::size(1), 1::size(1), 1::size(1), rest::5-bits, next_char::binary>>,
            original,
            unquote(context_fun)
          }
        end
      end
    else
      quote do
        def unquote(fun_name)(unquote(token), :buffering, unquote_splicing(params_splice)) do
          {
            :halted,
            unquote(token),
            original,
            unquote(context_fun)
          }
        end
      end
    end
  end
end
