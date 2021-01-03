defmodule Saxy.BufferingHelper do
  @moduledoc false

  @doc """
  Define a named function that matches a token and returns the parsing context.
  """

  defmacro halt!(call) do
    {name, args} = Macro.decompose_call(call)
    context_fun = build_context_fun(name, args)
    state = List.keyfind(args, :state, 0)

    quote do
      {:halted, unquote(context_fun), unquote(state)}
    end
  end

  def utf8_binaries() do
    [
      quote(do: <<1::1, rest_of_first_byte::7>>),
      quote(do: <<1::1, 1::1, rest_of_first_byte::6, next_char::1-bytes>>),
      quote(do: <<1::1, 1::1, 1::1, rest_of_first_byte::5, next_two_chars::2-bytes>>)
    ]
  end

  defp build_context_fun(fun_name, [token, _more?, original, pos, _state | args]) do
    quote do
      fn cont_buffer, more?, state ->
        unquote(fun_name)(
          unquote(token) <> cont_buffer,
          more?,
          unquote(original) <> cont_buffer,
          unquote(pos),
          state,
          unquote_splicing(args)
        )
      end
    end
  end
end
