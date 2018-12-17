defmodule Saxy.BufferingHelper do
  @moduledoc false

  @doc """
  Define a named function that matches a token and returns the parsing context.
  """

  @parser_config Application.get_env(:saxy, :parser, [])

  defmacro defhalt(call) do
    if streaming_enabled?(@parser_config) do
      case Macro.decompose_call(call) do
        {name, args} ->
          context_fun = build_context_fun(name, args)

          quote do
            defp unquote(name)(unquote_splicing(args)) do
              {:halted, unquote(context_fun)}
            end
          end

        _invalid ->
          raise ArgumentError, "invalid syntax in defhalt #{Macro.to_string(call)}"
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

  defp streaming_enabled?(config) do
    Keyword.get(config, :streaming, true)
  end

  defp build_context_fun(fun_name, [token, _more?, original | args]) do
    quote do
      fn cont_buffer, more? ->
        unquote(fun_name)(
          unquote(token) <> cont_buffer,
          more?,
          unquote(original) <> cont_buffer,
          unquote_splicing(args)
        )
      end
    end
  end
end
