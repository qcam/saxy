defmodule Saxy.Parser.Element do
  @moduledoc false

  import Saxy.Guards

  import Saxy.BufferingHelper, only: [defhalt: 3, utf8_binaries: 0]

  alias Saxy.Emitter

  alias Saxy.Parser.Utils

  def parse(<<rest::bits>>, more?, original, pos, state) do
    element(rest, more?, original, pos, state)
  end

  defp element(<<?<, rest::bits>>, more?, original, pos, state) do
    open_tag(rest, more?, original, pos + 1, state)
  end

  defhalt(:element, 5, "")

  defp element(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :lt})
  end

  defp open_tag(<<charcode, rest::bits>>, more?, original, pos, state)
       when is_ascii(charcode) and is_name_start_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, 1)
  end

  defp open_tag(<<charcode::utf8, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defhalt(:open_tag, 5, "")

  defp open_tag(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :name_start_char})
  end

  defp open_tag_name(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) and is_name_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, len + 1)
  end

  defp open_tag_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defhalt(:open_tag_name, 6, "")

  defp open_tag_name(<<buffer::bits>>, more?, original, pos, state, len) do
    name = binary_part(original, pos, len)
    state = %{state | stack: [name | state.stack]}
    sattribute(buffer, more?, original, pos + len, state, [])
  end

  defp sattribute(<<?>, rest::bits>>, more?, original, pos, state, attributes) do
    [tag_name | _] = state.stack
    attributes = Enum.reverse(attributes)

    case Emitter.emit(:start_element, {tag_name, attributes}, state) do
      {:stop, state} ->
        {:ok, state}

      {:ok, state} ->
        element_content(rest, more?, original, pos + 1, state)

      {:error, reason} ->
        Utils.bad_return_error(reason)
    end
  end

  defp sattribute(<<"/>", rest::bits>>, more?, original, pos, state, attributes) do
    [tag_name | stack] = state.stack

    state = %{state | stack: stack}
    attributes = Enum.reverse(attributes)

    with {:ok, state} <- Emitter.emit(:start_element, {tag_name, attributes}, state),
         {:ok, state} <- Emitter.emit(:end_element, tag_name, state) do
      case stack do
        [] ->
          element_misc(rest, more?, original, pos + 2, state)

        _ ->
          {original, pos} = maybe_trim(more?, original, pos)
          element_content(rest, more?, original, pos + 2, state)
      end
    else
      {:stop, state} ->
        {:ok, state}

      {:error, other} ->
        Utils.bad_return_error(other)
    end
  end

  defp sattribute(<<charcode, rest::bits>>, more?, original, pos, state, attributes)
       when is_ascii(charcode) and is_name_start_char(charcode) do
    attribute_name(rest, more?, original, pos, state, attributes, 1)
  end

  defp sattribute(<<charcode::utf8, rest::bits>>, more?, original, pos, state, attributes)
       when is_name_start_char(charcode) do
    attribute_name(rest, more?, original, pos, state, attributes, Utils.compute_char_len(charcode))
  end

  defp sattribute(<<whitespace, rest::bits>>, more?, original, pos, state, attributes)
       when is_whitespace(whitespace) do
    sattribute(rest, more?, original, pos + 1, state, attributes)
  end

  defhalt(:sattribute, 6, "")
  defhalt(:sattribute, 6, "/")

  defp sattribute(<<_buffer::bits>>, _more?, original, pos, state, _attributes) do
    Utils.parse_error(original, pos, state, {:token, :name_start_char})
  end

  defp attribute_name(<<charcode, rest::bits>>, more?, original, pos, state, attributes, len)
       when is_ascii(charcode) and is_name_char(charcode) do
    attribute_name(rest, more?, original, pos, state, attributes, len + 1)
  end

  defp attribute_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, attributes, len)
       when is_name_char(charcode) do
    attribute_name(rest, more?, original, pos, state, attributes, len + Utils.compute_char_len(charcode))
  end

  defhalt(:attribute_name, 7, "")

  defp attribute_name(<<rest::bits>>, more?, original, pos, state, attributes, len) do
    att_name = binary_part(original, pos, len)
    attribute_eq(rest, more?, original, pos + len, state, attributes, att_name)
  end

  defp attribute_eq(<<whitespace::integer, rest::bits>>, more?, original, pos, state, attributes, att_name)
       when is_whitespace(whitespace) do
    attribute_eq(rest, more?, original, pos + 1, state, attributes, att_name)
  end

  defp attribute_eq(<<?=, rest::bits>>, more?, original, pos, state, attributes, att_name) do
    attribute_quote(rest, more?, original, pos + 1, state, attributes, att_name)
  end

  defhalt(:attribute_eq, 7, "")

  defp attribute_eq(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _att_name) do
    Utils.parse_error(original, pos, state, {:token, :eq})
  end

  defp attribute_quote(<<whitespace::integer, rest::bits>>, more?, original, pos, state, attributes, att_name)
       when is_whitespace(whitespace) do
    attribute_quote(rest, more?, original, pos + 1, state, attributes, att_name)
  end

  defp attribute_quote(<<quote, rest::bits>>, more?, original, pos, state, attributes, att_name)
       when quote in '"\'' do
    att_value(rest, more?, original, pos + 1, state, attributes, quote, att_name, "", 0)
  end

  defhalt(:attribute_quote, 7, "")

  defp attribute_quote(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _att_name) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  defp att_value(<<quote, rest::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, len)
       when quote == open_quote do
    att_value = [acc | binary_part(original, pos, len)] |> IO.iodata_to_binary()
    attributes = [{att_name, att_value} | attributes]

    sattribute(rest, more?, original, pos + len + 1, state, attributes)
  end

  defhalt(:att_value, 10, "")
  defhalt(:att_value, 10, "&")
  defhalt(:att_value, 10, "&#")

  defp att_value(<<"&#x", rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    att_value = binary_part(original, pos, len)
    acc = [acc | att_value]
    att_value_char_hex_ref(rest, more?, original, pos + len + 3, state, attributes, q, att_name, acc, 0)
  end

  defp att_value(<<"&#", rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    att_value = binary_part(original, pos, len)
    acc = [acc | att_value]
    att_value_char_dec_ref(rest, more?, original, pos + len + 2, state, attributes, q, att_name, acc, 0)
  end

  defp att_value(<<?&, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    att_value = binary_part(original, pos, len)
    acc = [acc | att_value]
    att_value_entity_ref(rest, more?, original, pos + len + 1, state, attributes, q, att_name, acc, 0)
  end

  defp att_value(<<charcode, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len)
       when is_ascii(charcode) do
    att_value(rest, more?, original, pos, state, attributes, q, att_name, acc, len + 1)
  end

  Enum.each(utf8_binaries(), &defhalt(:att_value, 10, unquote(&1)))

  defp att_value(<<charcode::utf8, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    att_value(rest, more?, original, pos, state, attributes, q, att_name, acc, len + Utils.compute_char_len(charcode))
  end

  defp att_value(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _q, _att_name, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :att_value})
  end

  defp att_value_entity_ref(<<charcode, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, 0)
       when is_ascii(charcode) and is_name_start_char(charcode) do
    att_value_entity_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, 1)
  end

  defp att_value_entity_ref(<<charcode::utf8, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, 0)
       when is_name_start_char(charcode) do
    att_value_entity_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, Utils.compute_char_len(charcode))
  end

  defp att_value_entity_ref(<<charcode, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len)
       when is_ascii(charcode) and is_name_char(charcode) do
    att_value_entity_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, len + 1)
  end

  defp att_value_entity_ref(<<charcode::utf8, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len)
       when is_name_char(charcode) do
    len = len + Utils.compute_char_len(charcode)
    att_value_entity_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, len)
  end

  defp att_value_entity_ref(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _q, _att_name, _acc, 0) do
    Utils.parse_error(original, pos, state, {:token, :name_start_char})
  end

  defp att_value_entity_ref(<<?;, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    name = binary_part(original, pos, len)
    converted = Emitter.convert_entity_reference(name, state)
    acc = [acc | converted]

    att_value(rest, more?, original, pos + len + 1, state, attributes, q, att_name, acc, 0)
  end

  defhalt(:att_value_entity_ref, 10, "")

  defp att_value_entity_ref(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _q, _att_name, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :entity_ref})
  end

  defp att_value_char_dec_ref(<<charcode, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len)
       when charcode in ?0..?9 do
    att_value_char_dec_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, len + 1)
  end

  defp att_value_char_dec_ref(<<?;, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    char = original |> binary_part(pos, len) |> String.to_integer(10)

    att_value(rest, more?, original, pos + len + 1, state, attributes, q, att_name, [acc | <<char::utf8>>], 0)
  end

  defhalt(:att_value_char_dec_ref, 10, "")

  defp att_value_char_dec_ref(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _q, _att_name, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :char_ref})
  end

  defp att_value_char_hex_ref(<<charcode, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len)
       when charcode in ?0..?9 or charcode in ?A..?F or charcode in ?a..?f do
    att_value_char_hex_ref(rest, more?, original, pos, state, attributes, q, att_name, acc, len + 1)
  end

  defp att_value_char_hex_ref(<<?;, rest::bits>>, more?, original, pos, state, attributes, q, att_name, acc, len) do
    char = original |> binary_part(pos, len) |> String.to_integer(16)

    att_value(rest, more?, original, pos + len + 1, state, attributes, q, att_name, [acc | <<char::utf8>>], 0)
  end

  defhalt(:att_value_char_hex_ref, 10, "")

  defp att_value_char_hex_ref(<<_buffer::bits>>, _more?, original, pos, state, _attributes, _q, _att_name, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :char_ref})
  end

  defp element_content(<<?<, rest::bits>>, more?, original, pos, state) do
    element_content_rest(rest, more?, original, pos + 1, state)
  end

  defp element_content(<<?&, rest::bits>>, more?, original, pos, state) do
    element_content_reference(rest, more?, original, pos + 1, state, <<>>)
  end

  defp element_content(<<whitespace::integer, rest::bits>>, more?, original, pos, state)
       when is_whitespace(whitespace) do
    chardata_whitespace(rest, more?, original, pos, state, 1)
  end

  defhalt(:element_content, 5, "")

  defp element_content(<<charcode, rest::bits>>, more?, original, pos, state)
       when is_ascii(charcode) do
    chardata(rest, more?, original, pos, state, "", 1)
  end

  Enum.each(utf8_binaries(), &defhalt(:element_content, 5, unquote(&1)))

  defp element_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state) do
    chardata(rest, more?, original, pos, state, "", Utils.compute_char_len(charcode))
  end

  defp element_content(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :content})
  end

  defp element_content_rest(<<charcode, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, 1)
  end

  defp element_content_rest(<<charcode::utf8, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    open_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defp element_content_rest(<<?/, rest::bits>>, more?, original, pos, state) do
    close_tag_name(rest, more?, original, pos + 1, state, 0)
  end

  defp element_content_rest(<<"![CDATA[", rest::bits>>, more?, original, pos, state) do
    element_cdata(rest, more?, original, pos + 8, state, 0)
  end

  defp element_content_rest(<<"!--", buffer::bits>>, more?, original, pos, state) do
    element_content_comment(buffer, more?, original, pos + 3, state, 0)
  end

  defp element_content_rest(<<??, buffer::bits>>, more?, original, pos, state) do
    element_processing_instruction(buffer, more?, original, pos + 1, state, 0)
  end

  defhalt(:element_content_rest, 5, "")
  defhalt(:element_content_rest, 5, "!")
  defhalt(:element_content_rest, 5, "!-")
  defhalt(:element_content_rest, 5, "![")
  defhalt(:element_content_rest, 5, "![C")
  defhalt(:element_content_rest, 5, "![CD")
  defhalt(:element_content_rest, 5, "![CDA")
  defhalt(:element_content_rest, 5, "![CDAT")
  defhalt(:element_content_rest, 5, "![CDATA")

  defp element_content_rest(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :lt})
  end

  defp element_cdata(<<"]]>", rest::bits>>, more?, original, pos, state, len) do
    cdata = binary_part(original, pos, len)

    case Emitter.emit(:characters, cdata, state) do
      {:ok, state} ->
        element_content(rest, more?, original, pos + len + 3, state)

      {:stop, state} ->
        {:ok, state}

      {:error, other} ->
        Utils.bad_return_error(other)
    end
  end

  defhalt(:element_cdata, 6, "")
  defhalt(:element_cdata, 6, "]")
  defhalt(:element_cdata, 6, "]]")

  defp element_cdata(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    element_cdata(rest, more?, original, pos, state, len + 1)
  end

  defp element_cdata(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    element_cdata(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp element_cdata(<<_buffer::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :"]]"})
  end

  defp chardata_whitespace(<<whitespace::integer, rest::bits>>, more?, original, pos, state, len)
       when is_whitespace(whitespace) do
    chardata_whitespace(rest, more?, original, pos, state, len + 1)
  end

  defp chardata_whitespace(<<?<, rest::bits>>, more?, original, pos, state, len) do
    element_content_rest(rest, more?, original, pos + len + 1, state)
  end

  defp chardata_whitespace(<<?&, rest::bits>>, more?, original, pos, state, len) do
    chars = binary_part(original, pos, len)
    element_content_reference(rest, more?, original, pos + len + 1, state, chars)
  end

  defp chardata_whitespace(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    chardata(rest, more?, original, pos, state, "", len + 1)
  end

  Enum.each(utf8_binaries(), &defhalt(:chardata_whitespace, 6, unquote(&1)))

  defp chardata_whitespace(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    chardata(rest, more?, original, pos, state, "", len + Utils.compute_char_len(charcode))
  end

  defhalt(:chardata_whitespace, 6, "")

  defp chardata_whitespace(<<_buffer::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :chardata})
  end

  defp chardata(<<?<, rest::bits>>, more?, original, pos, state, acc, len) do
    chars = IO.iodata_to_binary([acc | binary_part(original, pos, len)])

    case Emitter.emit(:characters, chars, state) do
      {:ok, state} ->
        element_content_rest(rest, more?, original, pos + len + 1, state)

      {:stop, state} ->
        {:ok, state}

      {:error, other} ->
        Utils.bad_return_error(other)
    end
  end

  defp chardata(<<?&, rest::bits>>, more?, original, pos, state, acc, len) do
    chars = binary_part(original, pos, len)

    element_content_reference(rest, more?, original, pos + len + 1, state, [acc | chars])
  end

  defp chardata(<<charcode, rest::bits>>, more?, original, pos, state, acc, len)
       when is_ascii(charcode) do
    chardata(rest, more?, original, pos, state, acc, len + 1)
  end

  Enum.each(utf8_binaries(), &defhalt(:chardata, 7, unquote(&1)))

  defp chardata(<<charcode::utf8, rest::bits>>, more?, original, pos, state, acc, len) do
    chardata(rest, more?, original, pos, state, acc, len + Utils.compute_char_len(charcode))
  end

  defhalt(:chardata, 7, "")

  defp chardata(<<_buffer::bits>>, _more?, original, pos, state, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :chardata})
  end

  defhalt(:element_content_reference, 6, "")
  defhalt(:element_content_reference, 6, "#")

  defp element_content_reference(<<charcode, rest::bits>>, more?, original, pos, state, acc)
       when is_name_start_char(charcode) do
    element_entity_ref(rest, more?, original, pos, state, acc, 1)
  end

  defp element_content_reference(<<charcode::utf8, rest::bits>>, more?, original, pos, state, acc)
       when is_name_start_char(charcode) do
    element_entity_ref(rest, more?, original, pos, state, acc, Utils.compute_char_len(charcode))
  end

  defp element_content_reference(<<?#, ?x, rest::bits>>, more?, original, pos, state, acc) do
    element_char_hex_ref(rest, more?, original, pos + 2, state, acc, 0)
  end

  defp element_content_reference(<<?#, rest::bits>>, more?, original, pos, state, acc) do
    element_char_dec_ref(rest, more?, original, pos + 1, state, acc, 0)
  end

  defp element_content_reference(<<_buffer::bits>>, _more?, original, pos, state, _acc) do
    Utils.parse_error(original, pos, state, {:token, :reference})
  end

  defp element_entity_ref(<<charcode, rest::bits>>, more?, original, pos, state, acc, len)
       when is_name_char(charcode) do
    element_entity_ref(rest, more?, original, pos, state, acc, len + 1)
  end

  defp element_entity_ref(<<charcode::utf8, rest::bits>>, more?, original, pos, state, acc, len)
       when is_name_char(charcode) do
    element_entity_ref(rest, more?, original, pos, state, acc, len + Utils.compute_char_len(charcode))
  end

  defp element_entity_ref(<<?;, rest::bits>>, more?, original, pos, state, acc, len) do
    name = binary_part(original, pos, len)
    char = Emitter.convert_entity_reference(name, state)
    chardata(rest, more?, original, pos + len + 1, state, [acc | char], 0)
  end

  defhalt(:element_entity_ref, 7, "")

  defp element_entity_ref(<<_buffer::bits>>, _more?, original, pos, state, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :entity_ref})
  end

  defp element_char_dec_ref(<<?;, _rest::bits>>, _more?, original, pos, state, _acc, 0) do
    Utils.parse_error(original, pos, state, {:token, :char_ref})
  end

  defp element_char_dec_ref(<<?;, rest::bits>>, more?, original, pos, state, acc, len) do
    char = original |> binary_part(pos, len) |> String.to_integer(10)

    chardata(rest, more?, original, pos + len + 1, state, [acc | <<char::utf8>>], 0)
  end

  defp element_char_dec_ref(<<charcode::integer, rest::bits>>, more?, original, pos, state, acc, len)
       when charcode in ?0..?9 do
    element_char_dec_ref(rest, more?, original, pos, state, acc, len + 1)
  end

  defhalt(:element_char_dec_ref, 7, "")

  defp element_char_dec_ref(<<_buffer::bits>>, _more?, original, pos, state, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :char_ref})
  end

  defp element_char_hex_ref(<<?;, _rest::bits>>, _more?, original, pos, state, _acc, 0) do
    Utils.parse_error(original, pos, state, [])
  end

  defp element_char_hex_ref(<<?;, rest::bits>>, more?, original, pos, state, acc, len) do
    char = original |> binary_part(pos, len) |> String.to_integer(16)

    chardata(rest, more?, original, pos + len + 1, state, [acc | <<char::utf8>>], 0)
  end

  defp element_char_hex_ref(<<charcode::integer, rest::bits>>, more?, original, pos, state, acc, len)
       when charcode in ?0..?9 or charcode in ?A..?F or charcode in ?a..?f do
    element_char_hex_ref(rest, more?, original, pos, state, acc, len + 1)
  end

  defhalt(:element_char_hex_ref, 7, "")

  defp element_char_hex_ref(<<_buffer::bits>>, _more?, original, pos, state, _acc, len) do
    Utils.parse_error(original, pos + len, state, {:token, :char_ref})
  end

  defp element_processing_instruction(<<charcode, rest::bits>>, more?, original, pos, state, 0)
       when is_name_start_char(charcode) do
    element_processing_instruction(rest, more?, original, pos, state, 1)
  end

  defp element_processing_instruction(<<charcode::utf8, rest::bits>>, more?, original, pos, state, 0)
       when is_name_start_char(charcode) do
    element_processing_instruction(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defhalt(:element_processing_instruction, 6, "")

  defp element_processing_instruction(<<_buffer::bits>>, _more?, original, pos, state, 0) do
    Utils.parse_error(original, pos, state, {:token, :processing_instruction})
  end

  defp element_processing_instruction(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    element_processing_instruction(rest, more?, original, pos, state, len + 1)
  end

  defp element_processing_instruction(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    element_processing_instruction(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp element_processing_instruction(<<buffer::bits>>, more?, original, pos, state, len) do
    pi_name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(pi_name) do
      element_processing_instruction_content(buffer, more?, original, pos + len, state, pi_name, 0)
    else
      Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
    end
  end

  defp element_processing_instruction_content(<<"?>", rest::bits>>, more?, original, pos, state, _name, len) do
    element_content(rest, more?, original, pos + len + 2, state)
  end

  defhalt(:element_processing_instruction_content, 7, "")
  defhalt(:element_processing_instruction_content, 7, "?")

  defp element_processing_instruction_content(<<charcode, rest::bits>>, more?, original, pos, state, name, len)
       when is_ascii(charcode) do
    element_processing_instruction_content(rest, more?, original, pos, state, name, len + 1)
  end

  defp element_processing_instruction_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, name, len) do
    element_processing_instruction_content(rest, more?, original, pos, state, name, len + Utils.compute_char_len(charcode))
  end

  defp element_processing_instruction_content(<<_buffer::bits>>, _more?, original, pos, state, _name, len) do
    Utils.parse_error(original, pos + len, state, {:token, :processing_instruction})
  end

  defp element_content_comment(<<"-->", rest::bits>>, more?, original, pos, state, len) do
    element_content(rest, more?, original, pos + len + 3, state)
  end

  defhalt(:element_content_comment, 6, "")
  defhalt(:element_content_comment, 6, "-")
  defhalt(:element_content_comment, 6, "--")
  defhalt(:element_content_comment, 6, "---")

  defp element_content_comment(<<"--->", _rest::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :comment})
  end

  defp element_content_comment(<<charcode, rest::bits>>, more?, original, pos, state, len) when is_ascii(charcode) do
    element_content_comment(rest, more?, original, pos, state, len + 1)
  end

  defp element_content_comment(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    element_content_comment(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp close_tag_name(<<charcode, rest::bits>>, more?, original, pos, state, 0)
       when is_ascii(charcode) and is_name_start_char(charcode) do
    close_tag_name(rest, more?, original, pos, state, 1)
  end

  defp close_tag_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, 0)
       when is_name_start_char(charcode) do
    close_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defhalt(:close_tag_name, 6, "")

  defp close_tag_name(<<_buffer::bits>>, _more?, original, pos, state, 0) do
    Utils.parse_error(original, pos, state, {:token, :end_tag})
  end

  defp close_tag_name(<<?>, rest::bits>>, more?, original, pos, state, len) do
    [open_tag | stack] = state.stack
    ending_tag = binary_part(original, pos, len)

    if open_tag == ending_tag do
      case Emitter.emit(:end_element, ending_tag, state) do
        {:ok, state} ->
          state = %{state | stack: stack}

          case stack do
            [] ->
              element_misc(rest, more?, original, pos + len + 1, state)

            [_parent | _stack] ->
              {original, pos} = maybe_trim(more?, original, pos)
              element_content(rest, more?, original, pos + len + 1, state)
          end

        {:stop, state} ->
          {:ok, state}

        {:error, other} ->
          Utils.bad_return_error(other)
      end
    else
      Utils.parse_error(original, pos, state, {:wrong_closing_tag, open_tag, ending_tag})
    end
  end

  defp close_tag_name(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) and is_name_char(charcode) do
    close_tag_name(rest, more?, original, pos, state, len + 1)
  end

  defp close_tag_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    close_tag_name(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp close_tag_name(<<_buffer::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :end_tag})
  end

  defhalt(:element_misc, 5, "")

  defp element_misc(<<>>, _more?, _original, _pos, state) do
    case Emitter.emit(:end_document, {}, state) do
      {:ok, state} -> {:ok, state}
      {:stop, state} -> {:stop, state}
      {:error, other} -> Utils.bad_return_error(other)
    end
  end

  defp element_misc(<<whitespace::integer, rest::bits>>, more?, original, pos, state)
       when is_whitespace(whitespace) do
    element_misc(rest, more?, original, pos + 1, state)
  end

  defp element_misc(<<?<, rest::bits>>, more?, original, pos, state) do
    element_misc_rest(rest, more?, original, pos + 1, state)
  end

  defhalt(:element_misc_rest, 5, "")

  defp element_misc_rest(<<?!, rest::bits>>, more?, original, pos, state) do
    element_misc_comment(rest, more?, original, pos + 1, state)
  end

  defp element_misc_rest(<<??, rest::bits>>, more?, original, pos, state) do
    element_misc_pi(rest, more?, original, pos + 1, state)
  end

  defhalt(:element_misc_comment, 5, "")
  defhalt(:element_misc_comment, 5, "-")

  defp element_misc_comment(<<"--", rest::bits>>, more?, original, pos, state) do
    element_misc_comment_char(rest, more?, original, pos + 2, state, 0)
  end

  defp element_misc_comment(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :--})
  end

  defhalt(:element_misc_comment_char, 6, "")
  defhalt(:element_misc_comment_char, 6, "-")
  defhalt(:element_misc_comment_char, 6, "--")
  defhalt(:element_misc_comment_char, 6, "---")

  defp element_misc_comment_char(<<"--->", _rest::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :comment})
  end

  defp element_misc_comment_char(<<"-->", rest::bits>>, more?, original, pos, state, len) do
    element_misc(rest, more?, original, pos + len + 3, state)
  end

  defp element_misc_comment_char(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    element_misc_comment_char(rest, more?, original, pos, state, len + 1)
  end

  defp element_misc_comment_char(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    element_misc_comment_char(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp element_misc_comment_char(<<_buffer::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :"-->"})
  end

  defhalt(:element_misc_pi, 5, "")

  defp element_misc_pi(<<char, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(char) do
    element_misc_pi_name(rest, more?, original, pos, state, 1)
  end

  defp element_misc_pi(<<charcode::utf8, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    element_misc_pi_name(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defp element_misc_pi(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :processing_instruction})
  end

  defp element_misc_pi_name(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    element_misc_pi_name(rest, more?, original, pos, state, len + 1)
  end

  defp element_misc_pi_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    element_misc_pi_name(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp element_misc_pi_name(<<rest::bits>>, more?, original, pos, state, len) do
    name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(name) do
      element_misc_pi_content(rest, more?, original, pos + len, state, 0)
    else
      Utils.parse_error(original, pos, state, {:invalid_pi, name})
    end
  end

  defhalt(:element_misc_pi_content, 6, "")
  defhalt(:element_misc_pi_content, 6, "?")

  defp element_misc_pi_content(<<"?>", rest::bits>>, more?, original, pos, state, len) do
    element_misc(rest, more?, original, pos + len + 2, state)
  end

  defp element_misc_pi_content(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    element_misc_pi_content(rest, more?, original, pos, state, len + 1)
  end

  defp element_misc_pi_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    element_misc_pi_content(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp element_misc_pi_content(<<_buffer::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :processing_instruction})
  end

  @compile {:inline, [maybe_trim: 3]}

  defp maybe_trim(true, binary, pos) do
    binary_size = byte_size(binary)

    {binary_part(binary, pos, binary_size - pos), 0}
  end

  defp maybe_trim(_more?, binary, pos) do
    {binary, pos}
  end
end
