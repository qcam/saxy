defmodule Saxy.Parser.Prolog do
  @moduledoc false

  import Saxy.Guards

  import Saxy.BufferingHelper, only: [defhalt: 1]

  import Saxy.Emitter, only: [emit_event: 2]

  alias Saxy.Parser.{
    Element,
    Utils
  }

  def parse(<<buffer::bits>>, more?, original, pos, state) do
    prolog(buffer, more?, original, pos, state)
  end

  defp prolog(<<"<?xml", rest::bits>>, more?, original, pos, state) do
    xml_decl(rest, more?, original, pos + 5, state)
  end

  defhalt prolog(<<>>, true, original, pos, state)
  defhalt prolog(<<?<>>, true, original, pos, state)
  defhalt prolog(<<?<, ??>>, true, original, pos, state)
  defhalt prolog(<<?<, ??, ?x>>, true, original, pos, state)
  defhalt prolog(<<?<, ??, ?x, ?m>>, true, original, pos, state)

  defp prolog(<<buffer::bits>>, more?, original, pos, state) do
    prolog_misc(buffer, more?, original, pos, state, [])
  end

  defp xml_decl(<<whitespace, rest::bits>>, more?, original, pos, state)
       when is_whitespace(whitespace) do
    xml_decl(rest, more?, original, pos + 1, state)
  end

  defp xml_decl(<<"version", rest::bits>>, more?, original, pos, state) do
    xml_ver_eq(rest, more?, original, pos + 7, state)
  end

  defhalt xml_decl(<<>>, true, original, pos, state)
  defhalt xml_decl(<<?v>>, true, original, pos, state)
  defhalt xml_decl(<<?v, ?e>>, true, original, pos, state)
  defhalt xml_decl(<<?v, ?e, ?r>>, true, original, pos, state)
  defhalt xml_decl(<<?v, ?e, ?r, ?s>>, true, original, pos, state)
  defhalt xml_decl(<<?v, ?e, ?r, ?s, ?i>>, true, original, pos, state)
  defhalt xml_decl(<<?v, ?e, ?r, ?s, ?i, ?o>>, true, original, pos, state)

  defp xml_decl(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :version})
  end

  defp xml_ver_eq(<<charcode::integer, rest::bits>>, more?, original, pos, state) when is_whitespace(charcode) do
    xml_ver_eq(rest, more?, original, pos + 1, state)
  end

  defp xml_ver_eq(<<?=, rest::bits>>, more?, original, pos, state) do
    xml_ver_quote(rest, more?, original, pos + 1, state)
  end

  defhalt xml_ver_eq(<<>>, true, original, pos, state)

  defp xml_ver_quote(<<whitespace::integer, rest::bits>>, more?, original, pos, state)
       when is_whitespace(whitespace) do
    xml_ver_quote(rest, more?, original, pos + 1, state)
  end

  defp xml_ver_quote(<<quote, rest::bits>>, more?, original, pos, state) when quote in '\'"' do
    xml_ver_one_dot(rest, more?, original, pos + 1, state, quote)
  end

  defhalt xml_ver_quote(<<>>, true, original, pos, state)

  defp xml_ver_quote(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  defp xml_ver_one_dot(<<"1.", rest::bits>>, more?, original, pos, state, quote) do
    xml_ver_num(rest, more?, original, pos, state, quote, 2)
  end

  defhalt xml_ver_one_dot(<<>>, true, original, pos, state, quote)
  defhalt xml_ver_one_dot(<<?1>>, true, original, pos, state, quote)

  defp xml_ver_one_dot(<<_buffer::bits>>, _more?, original, pos, state, _quote) do
    Utils.parse_error(original, pos, state, {:token, :"1."})
  end

  defp xml_ver_num(<<quote, rest::bits>>, more?, original, pos, state, open_quote, len)
       when quote in '\'"' and quote == open_quote do
    version = binary_part(original, pos, len)
    prolog = [version: version]

    encoding_decl(rest, more?, original, pos + len + 1, state, prolog)
  end

  defp xml_ver_num(<<charcode::integer, rest::bits>>, more?, original, pos, state, open_quote, len)
       when charcode in '0123456789' do
    xml_ver_num(rest, more?, original, pos, state, open_quote, len + 1)
  end

  defhalt xml_ver_num(<<>>, true, original, pos, state, open_quote, len)

  defp xml_ver_num(<<_buffer::bits>>, _more?, original, pos, state, _open_quote, len) do
    Utils.parse_error(original, pos + len, state, {:token, :version_num})
  end

  defp encoding_decl(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(whitespace) do
    encoding_decl(rest, more?, original, pos + 1, state, prolog)
  end

  defp encoding_decl(<<"encoding", rest::bits>>, more?, original, pos, state, prolog) do
    encoding_decl_eq(rest, more?, original, pos + 8, state, prolog)
  end

  defhalt encoding_decl(<<>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n, ?c>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n, ?c, ?o>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n, ?c, ?o, ?d>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n, ?c, ?o, ?d, ?i>>, true, original, pos, state, prolog)
  defhalt encoding_decl(<<?e, ?n, ?c, ?o, ?d, ?i, ?n>>, true, original, pos, state, prolog)

  defp encoding_decl(<<buffer::bits>>, more?, original, pos, state, prolog) do
    standalone(buffer, more?, original, pos, state, prolog)
  end

  defp encoding_decl_eq(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(charcode) do
    encoding_decl_eq(rest, more?, original, pos + 1, state, prolog)
  end

  defp encoding_decl_eq(<<?=, rest::bits>>, more?, original, pos, state, prolog) do
    encoding_decl_eq_quote(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt encoding_decl_eq(<<>>, true, original, pos, state, prolog)

  defp encoding_decl_eq(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :eq})
  end

  defp encoding_decl_eq_quote(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(charcode) do
    encoding_decl_eq_quote(rest, more?, original, pos, state, prolog)
  end

  defp encoding_decl_eq_quote(<<?", rest::bits>>, more?, original, pos, state, prolog) do
    encoding_decl_enc_name(rest, more?, original, pos + 1, state, prolog, ?", 0)
  end

  defp encoding_decl_eq_quote(<<?', rest::bits>>, more?, original, pos, state, prolog) do
    encoding_decl_enc_name(rest, more?, original, pos + 1, state, prolog, ?', 0)
  end

  defhalt encoding_decl_eq_quote(<<>>, true, original, pos, state, prolog)

  defp encoding_decl_eq_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  defp encoding_decl_enc_name(<<charcode, rest::bits>>, more?, original, pos, state, prolog, open_quote, len)
       when charcode in '\'"' and open_quote == charcode do
    encoding = binary_part(original, pos, len)

    if Utils.valid_encoding?(encoding) do
      standalone(rest, more?, original, pos + len + 1, state, [{:encoding, encoding} | prolog])
    else
      Utils.parse_error(original, pos, state, {:invalid_encoding, encoding})
    end
  end

  defp encoding_decl_enc_name(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog, open_quote, len)
       when charcode in ?A..?Z or charcode in ?a..?z or charcode in ?0..?9 or charcode in [?-, ?., ?_] do
    encoding_decl_enc_name(rest, more?, original, pos, state, prolog, open_quote, len + 1)
  end

  defhalt encoding_decl_enc_name(<<>>, true, original, pos, state, prolog, open_quote, len)

  defp encoding_decl_enc_name(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote, len) do
    Utils.parse_error(original, pos + len, state, {:token, :encoding_name})
  end

  defp standalone(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(whitespace) do
    standalone(rest, more?, original, pos + 1, state, prolog)
  end

  defp standalone(<<"standalone", rest::bits>>, more?, original, pos, state, prolog) do
    standalone_eq(rest, more?, original, pos + 10, state, prolog)
  end

  defhalt standalone(<<>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n, ?d>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n, ?d, ?a>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n, ?d, ?a, ?l>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n, ?d, ?a, ?l, ?o>>, true, original, pos, state, prolog)
  defhalt standalone(<<?s, ?t, ?a, ?n, ?d, ?a, ?l, ?o, ?n>>, true, original, pos, state, prolog)

  defp standalone(<<buffer::bits>>, more?, original, pos, state, prolog) do
    xml_decl_close(buffer, more?, original, pos, state, prolog)
  end

  defp standalone_eq(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(whitespace) do
    standalone_eq(rest, more?, original, pos + 1, state, prolog)
  end

  defp standalone_eq(<<?=, rest::bits>>, more?, original, pos, state, prolog) do
    standalone_eq_quote(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt standalone_eq(<<>>, true, original, pos, state, prolog)

  defp standalone_eq(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :standalone})
  end

  defp standalone_eq_quote(<<quote, rest::bits>>, more?, original, pos, state, prolog)
       when quote in '\'"' do
    standalone_bool(rest, more?, original, pos + 1, state, prolog, quote)
  end

  defhalt standalone_eq_quote(<<>>, true, original, pos, state, prolog)

  defp standalone_eq_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  defp standalone_bool(<<"yes", rest::bits>>, more?, original, pos, state, prolog, open_quote) do
    standalone_end_quote(rest, more?, original, pos + 3, state, [{:standalone, true} | prolog], open_quote)
  end

  defp standalone_bool(<<"no", rest::bits>>, more?, original, pos, state, prolog, open_quote) do
    standalone_end_quote(rest, more?, original, pos + 2, state, [{:standalone, false} | prolog], open_quote)
  end

  defhalt standalone_bool(<<>>, true, original, pos, state, prolog, open_quote)
  defhalt standalone_bool(<<?y>>, true, original, pos, state, prolog, open_quote)
  defhalt standalone_bool(<<?n>>, true, original, pos, state, prolog, open_quote)
  defhalt standalone_bool(<<?y, ?e>>, true, original, pos, state, prolog, open_quote)

  defp standalone_bool(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote) do
    Utils.parse_error(original, pos, state, {:token, :yes_or_no})
  end

  defp standalone_end_quote(<<quote, rest::bits>>, more?, original, pos, state, prolog, open_quote)
       when quote in '"\'' and open_quote == quote do
    xml_decl_close(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt standalone_end_quote(<<>>, true, original, pos, state, prolog, open_quote)

  defp standalone_end_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  defp xml_decl_close(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(whitespace) do
    xml_decl_close(rest, more?, original, pos + 1, state, prolog)
  end

  defp xml_decl_close(<<"?>", rest::bits>>, more?, original, pos, state, prolog) do
    prolog_misc(rest, more?, original, pos + 2, state, prolog)
  end

  defhalt xml_decl_close(<<>>, true, original, pos, state, prolog)
  defhalt xml_decl_close(<<??>>, true, original, pos, state, prolog)

  defp xml_decl_close(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :xml_decl_close})
  end

  defp prolog_misc(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
       when is_whitespace(whitespace) do
    prolog_misc(rest, more?, original, pos + 1, state, prolog)
  end

  defp prolog_misc(<<"<!--", rest::bits>>, more?, original, pos, state, prolog) do
    prolog_misc_comment(rest, more?, original, pos + 4, state, prolog, 0)
  end

  defp prolog_misc(<<"<?", rest::bits>>, more?, original, pos, state, prolog) do
    prolog_processing_instruction(rest, more?, original, pos + 2, state, prolog)
  end

  defhalt prolog_misc(<<>>, true, original, pos, state, prolog)
  defhalt prolog_misc(<<?<>>, true, original, pos, state, prolog)
  defhalt prolog_misc(<<?<, ?!>>, true, original, pos, state, prolog)
  defhalt prolog_misc(<<?<, ?!, ?->>, true, original, pos, state, prolog)

  defp prolog_misc(<<rest::bits>>, more?, original, pos, state, prolog) do
    state = %{state | prolog: prolog}

    emit_event(state <- [:start_document, prolog, state]) do
      dtd(rest, more?, original, pos, state)
    end
  end

  defp prolog_misc_comment(<<"--->", _rest::bits>>, _more?, original, pos, state, _prolog, len) do
    Utils.parse_error(original, pos + len, state, {:token, :comment})
  end

  defp prolog_misc_comment(<<"-->", rest::bits>>, more?, original, pos, state, prolog, len) do
    prolog_misc(rest, more?, original, pos + len + 3, state, prolog)
  end

  defhalt prolog_misc_comment(<<>>, true, original, pos, state, prolog, len)
  defhalt prolog_misc_comment(<<?->>, true, original, pos, state, prolog, len)
  defhalt prolog_misc_comment(<<?-, ?->>, true, original, pos, state, prolog, len)

  defp prolog_misc_comment(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
       when is_ascii(charcode) do
    prolog_misc_comment(rest, more?, original, pos, state, prolog, len + 1)
  end

  defp prolog_misc_comment(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len) do
    prolog_misc_comment(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  defp prolog_processing_instruction(<<charcode, rest::bits>>, more?, original, pos, state, prolog)
       when is_name_start_char(charcode) do
    prolog_pi_name(rest, more?, original, pos, state, prolog, 1)
  end

  defp prolog_processing_instruction(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog)
       when is_name_start_char(charcode) do
    prolog_pi_name(rest, more?, original, pos, state, prolog, Utils.compute_char_len(charcode))
  end

  defhalt prolog_processing_instruction(<<>>, true, original, pos, state, prolog)

  defp prolog_processing_instruction(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :processing_instruction})
  end

  defp prolog_pi_name(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
       when is_name_char(charcode) do
    prolog_pi_name(rest, more?, original, pos, state, prolog, len + 1)
  end

  defp prolog_pi_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len)
       when is_name_char(charcode) do
    prolog_pi_name(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  defhalt prolog_pi_name(<<>>, true, original, pos, state, prolog, len)

  defp prolog_pi_name(<<rest::bits>>, more?, original, pos, state, prolog, len) do
    pi_name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(pi_name) do
      prolog_pi_content(rest, more?, original, pos + len, state, prolog, 0)
    else
      Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
    end
  end

  defp prolog_pi_content(<<"?>", rest::bits>>, more?, original, pos, state, prolog, len) do
    prolog_misc(rest, more?, original, pos + len + 2, state, prolog)
  end

  defhalt prolog_pi_content(<<>>, true, original, pos, state, prolog, len)
  defhalt prolog_pi_content(<<??>>, true, original, pos, state, prolog, len)

  defp prolog_pi_content(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
       when is_ascii(charcode) do
    prolog_pi_content(rest, more?, original, pos, state, prolog, len + 1)
  end

  defp prolog_pi_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len) do
    prolog_pi_content(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  defp dtd(<<"<!DOCTYPE", rest::bits>>, more?, original, pos, state) do
    dtd_content(rest, more?, original, pos + 9, state, 0, 1)
  end

  defhalt dtd(<<>>, true, original, pos, state)
  defhalt dtd(<<?<>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D, ?O>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D, ?O, ?C>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D, ?O, ?C, ?T>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D, ?O, ?C, ?T, ?Y>>, true, original, pos, state)
  defhalt dtd(<<?<, ?!, ?D, ?O, ?C, ?T, ?Y, ?P>>, true, original, pos, state)

  defp dtd(<<rest::bits>>, more?, original, pos, state) do
    Element.parse(rest, more?, original, pos, state)
  end

  defp dtd_content(<<?>, rest::bits>>, more?, original, pos, state, len, 1) do
    dtd_misc(rest, more?, original, pos + len + 1, state)
  end

  defp dtd_content(<<?>, rest::bits>>, more?, original, pos, state, len, count) do
    dtd_content(rest, more?, original, pos, state, len + 1, count - 1)
  end

  defp dtd_content(<<?<, rest::bits>>, more?, original, pos, state, len, count) do
    dtd_content(rest, more?, original, pos, state, len + 1, count + 1)
  end

  defp dtd_content(<<charcode, rest::bits>>, more?, original, pos, state, len, count)
       when is_ascii(charcode) do
    dtd_content(rest, more?, original, pos, state, len + 1, count)
  end

  defp dtd_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len, count) do
    dtd_content(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode), count)
  end

  defhalt dtd_content(<<>>, true, original, pos, state, len, count)

  defp dtd_content(<<_::bits>>, _more?, original, pos, state, _len, _count) do
    Utils.parse_error(original, pos, state, {:token, :dtd_content})
  end

  defp dtd_misc(<<whitespace::integer, rest::bits>>, more?, original, pos, state)
       when is_whitespace(whitespace) do
    dtd_misc(rest, more?, original, pos + 1, state)
  end

  defp dtd_misc(<<"<!--", rest::bits>>, more?, original, pos, state) do
    dtd_misc_comment(rest, more?, original, pos + 4, state, 0)
  end

  defp dtd_misc(<<"<?", rest::bits>>, more?, original, pos, state) do
    dtd_processing_instruction(rest, more?, original, pos + 2, state)
  end

  defhalt dtd_misc(<<>>, true, original, pos, state)
  defhalt dtd_misc(<<?<>>, true, original, pos, state)
  defhalt dtd_misc(<<?<, ?!>>, true, original, pos, state)
  defhalt dtd_misc(<<?<, ?!, ?->>, true, original, pos, state)

  defp dtd_misc(<<rest::bits>>, more?, original, pos, state) do
    Element.parse(rest, more?, original, pos, state)
  end

  defp dtd_misc_comment(<<"--->", _rest::bits>>, _more?, original, pos, state, len) do
    Utils.parse_error(original, pos + len, state, {:token, :comment})
  end

  defp dtd_misc_comment(<<"-->", rest::bits>>, more?, original, pos, state, len) do
    dtd_misc(rest, more?, original, pos + len + 3, state)
  end

  defhalt dtd_misc_comment(<<>>, true, original, pos, state, len)
  defhalt dtd_misc_comment(<<?->>, true, original, pos, state, len)
  defhalt dtd_misc_comment(<<?-, ?->>, true, original, pos, state, len)

  defp dtd_misc_comment(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    dtd_misc_comment(rest, more?, original, pos, state, len + 1)
  end

  defp dtd_misc_comment(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    dtd_misc_comment(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defp dtd_processing_instruction(<<charcode, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    dtd_pi_name(rest, more?, original, pos, state, 1)
  end

  defp dtd_processing_instruction(<<charcode::utf8, rest::bits>>, more?, original, pos, state)
       when is_name_start_char(charcode) do
    dtd_pi_name(rest, more?, original, pos, state, Utils.compute_char_len(charcode))
  end

  defhalt dtd_processing_instruction(<<>>, true, original, pos, state)

  defp dtd_processing_instruction(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :processing_instruction})
  end

  defp dtd_pi_name(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    dtd_pi_name(rest, more?, original, pos, state, len + 1)
  end

  defp dtd_pi_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len)
       when is_name_char(charcode) do
    dtd_pi_name(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end

  defhalt dtd_pi_name(<<>>, true, original, pos, state, len)

  defp dtd_pi_name(<<rest::bits>>, more?, original, pos, state, len) do
    pi_name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(pi_name) do
      dtd_pi_content(rest, more?, original, pos + len, state, 0)
    else
      Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
    end
  end

  defp dtd_pi_content(<<"?>", rest::bits>>, more?, original, pos, state, len) do
    dtd_misc(rest, more?, original, pos + len + 2, state)
  end

  defhalt dtd_pi_content(<<>>, true, original, pos, state, len)
  defhalt dtd_pi_content(<<??>>, true, original, pos, state, len)

  defp dtd_pi_content(<<charcode, rest::bits>>, more?, original, pos, state, len)
       when is_ascii(charcode) do
    dtd_pi_content(rest, more?, original, pos, state, len + 1)
  end

  defp dtd_pi_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, len) do
    dtd_pi_content(rest, more?, original, pos, state, len + Utils.compute_char_len(charcode))
  end
end
