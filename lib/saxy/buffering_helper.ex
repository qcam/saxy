defmodule Saxy.BufferingHelper do
  @moduledoc false

  @doc """
  Define a named function that matches a token and returns the parsing context.
  """

  defmacro defhalt(fun_name, arity, token) do
    params_splice = build_params_splice(token, arity)
    context_fun = build_context_fun(fun_name, token, arity)

    quote do
      def unquote(fun_name)(unquote_splicing(params_splice)) do
        {:halted, unquote(context_fun)}
      end
    end
  end

  def utf8_binaries() do
    [
      quote(do: <<1::1, rest_of_first_byte::7>>),
      quote(do: <<1::1, 1::1, rest_of_first_byte::6, next_char::1-bytes>>),
      quote(do: <<1::1, 1::1, 1::1, rest_of_first_byte::5, next_two_chars::2-bytes>>)
    ]
  end

  defp build_context_fun(fun_name, token, arity) do
    default_params =
      quote(do: [unquote(token) <> cont_buffer, more?, original <> cont_buffer, pos, state])

    params = append_acc_variables(default_params, arity)

    quote do
      fn cont_buffer, more? ->
        unquote(fun_name)(unquote_splicing(params))
      end
    end
  end

  defp build_params_splice(token, arity) do
    default_params = quote(do: [unquote(token), true, original, pos, state])

    append_acc_variables(default_params, arity)
  end

  defp append_acc_variables(vars, arity) do
    acc_count = arity - length(vars)

    for(i <- 0..acc_count, i > 0, into: vars, do: Macro.var(:"acc#{i}", __MODULE__))
  end
end
