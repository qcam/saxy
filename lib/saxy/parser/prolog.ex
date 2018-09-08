defmodule Saxy.Parser.Prolog do
  @moduledoc false

  import Saxy.Guards

  import Saxy.BufferingHelper, only: [defhalt: 3]

  import Saxy.Parser.Element, only: [parse_element: 5]

  alias Saxy.Emitter

  alias Saxy.Parser.Utils

  def parse_prolog(<<"<?xml", rest::bits>>, more?, original, pos, state) do
    parse_xml_decl(rest, more?, original, pos + 5, state)
  end

  defhalt(:parse_prolog, 5, "")
  defhalt(:parse_prolog, 5, "<")
  defhalt(:parse_prolog, 5, "<?")
  defhalt(:parse_prolog, 5, "<?x")
  defhalt(:parse_prolog, 5, "<?xm")

  def parse_prolog(<<buffer::bits>>, more?, original, pos, state) do
    parse_prolog_misc(buffer, more?, original, pos, state, [])
  end

  def parse_xml_decl(<<whitespace, rest::bits>>, more?, original, pos, state)
      when is_whitespace(whitespace) do
    parse_xml_decl(rest, more?, original, pos + 1, state)
  end

  def parse_xml_decl(<<"version", rest::bits>>, more?, original, pos, state) do
    parse_xml_ver_eq(rest, more?, original, pos + 7, state)
  end

  defhalt(:parse_xml_decl, 5, "")
  defhalt(:parse_xml_decl, 5, "v")
  defhalt(:parse_xml_decl, 5, "ve")
  defhalt(:parse_xml_decl, 5, "ver")
  defhalt(:parse_xml_decl, 5, "vers")
  defhalt(:parse_xml_decl, 5, "versi")
  defhalt(:parse_xml_decl, 5, "versio")

  def parse_xml_decl(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :version})
  end

  def parse_xml_ver_eq(<<charcode::integer, rest::bits>>, more?, original, pos, state) when is_whitespace(charcode) do
    parse_xml_ver_eq(rest, more?, original, pos + 1, state)
  end

  def parse_xml_ver_eq(<<?=, rest::bits>>, more?, original, pos, state) do
    parse_xml_ver_quote(rest, more?, original, pos + 1, state)
  end

  defhalt(:parse_xml_ver_eq, 5, "")

  def parse_xml_ver_quote(<<whitespace::integer, rest::bits>>, more?, original, pos, state)
      when is_whitespace(whitespace) do
    parse_xml_ver_quote(rest, more?, original, pos + 1, state)
  end

  def parse_xml_ver_quote(<<quote, rest::bits>>, more?, original, pos, state) when quote in '\'"' do
    parse_xml_ver_one_dot(rest, more?, original, pos + 1, state, quote)
  end

  defhalt(:parse_xml_ver_quote, 5, "")

  def parse_xml_ver_quote(<<_buffer::bits>>, _more?, original, pos, state) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  def parse_xml_ver_one_dot(<<"1.", rest::bits>>, more?, original, pos, state, quote) do
    parse_xml_ver_num(rest, more?, original, pos, state, quote, 2)
  end

  defhalt(:parse_xml_ver_one_dot, 6, "")
  defhalt(:parse_xml_ver_one_dot, 6, "1")

  def parse_xml_ver_one_dot(<<_buffer::bits>>, _more?, original, pos, state, _quote) do
    Utils.parse_error(original, pos, state, {:token, :"1."})
  end

  def parse_xml_ver_num(<<quote, rest::bits>>, more?, original, pos, state, open_quote, len)
      when quote in '\'"' and quote == open_quote do
    version = binary_part(original, pos, len)
    prolog = [version: version]

    parse_encoding_decl(rest, more?, original, pos + len + 1, state, prolog)
  end

  def parse_xml_ver_num(<<charcode::integer, rest::bits>>, more?, original, pos, state, open_quote, len)
      when charcode in '0123456789' do
    parse_xml_ver_num(rest, more?, original, pos, state, open_quote, len + 1)
  end

  defhalt(:parse_xml_ver_num, 7, "")

  def parse_xml_ver_num(<<_buffer::bits>>, _more?, original, pos, state, _open_quote, len) do
    Utils.parse_error(original, pos + len, state, {:token, :version_num})
  end

  def parse_encoding_decl(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_encoding_decl(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_encoding_decl(<<"encoding", rest::bits>>, more?, original, pos, state, prolog) do
    parse_encoding_decl_eq(rest, more?, original, pos + 8, state, prolog)
  end

  defhalt(:parse_encoding_decl, 6, "")
  defhalt(:parse_encoding_decl, 6, "e")
  defhalt(:parse_encoding_decl, 6, "en")
  defhalt(:parse_encoding_decl, 6, "enc")
  defhalt(:parse_encoding_decl, 6, "enco")
  defhalt(:parse_encoding_decl, 6, "encod")
  defhalt(:parse_encoding_decl, 6, "encodi")
  defhalt(:parse_encoding_decl, 6, "encodin")

  def parse_encoding_decl(<<buffer::bits>>, more?, original, pos, state, prolog) do
    parse_standalone(buffer, more?, original, pos, state, prolog)
  end

  def parse_encoding_decl_eq(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(charcode) do
    parse_encoding_decl_eq(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_encoding_decl_eq(<<?=, rest::bits>>, more?, original, pos, state, prolog) do
    parse_encoding_decl_eq_quote(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt(:parse_encoding_decl_eq, 6, "")

  def parse_encoding_decl_eq(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :eq})
  end

  def parse_encoding_decl_eq_quote(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(charcode) do
    parse_encoding_decl_eq_quote(rest, more?, original, pos, state, prolog)
  end

  def parse_encoding_decl_eq_quote(<<?", rest::bits>>, more?, original, pos, state, prolog) do
    parse_encoding_decl_enc_name(rest, more?, original, pos + 1, state, prolog, ?", 0)
  end

  def parse_encoding_decl_eq_quote(<<?', rest::bits>>, more?, original, pos, state, prolog) do
    parse_encoding_decl_enc_name(rest, more?, original, pos + 1, state, prolog, ?', 0)
  end

  defhalt(:parse_encoding_decl_eq_quote, 6, "")

  def parse_encoding_decl_eq_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  def parse_encoding_decl_enc_name(<<charcode, rest::bits>>, more?, original, pos, state, prolog, open_quote, len)
      when charcode in '\'"' and open_quote == charcode do
    encoding = binary_part(original, pos, len)

    if Utils.valid_encoding?(encoding) do
      parse_standalone(rest, more?, original, pos + len + 1, state, [{:encoding, encoding} | prolog])
    else
      Utils.parse_error(original, pos, state, {:invalid_encoding, encoding})
    end
  end

  def parse_encoding_decl_enc_name(<<charcode::integer, rest::bits>>, more?, original, pos, state, prolog, open_quote, len)
      when charcode in ?A..?Z or charcode in ?a..?z or charcode in ?0..?9 or charcode in [?-, ?., ?_] do
    parse_encoding_decl_enc_name(rest, more?, original, pos, state, prolog, open_quote, len + 1)
  end

  defhalt(:parse_encoding_decl_enc_name, 8, "")

  def parse_encoding_decl_enc_name(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote, len) do
    Utils.parse_error(original, pos + len, state, {:token, :encoding_name})
  end

  def parse_standalone(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_standalone(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_standalone(<<"standalone", rest::bits>>, more?, original, pos, state, prolog) do
    parse_standalone_eq(rest, more?, original, pos + 10, state, prolog)
  end

  defhalt(:parse_standalone, 6, "")
  defhalt(:parse_standalone, 6, "s")
  defhalt(:parse_standalone, 6, "st")
  defhalt(:parse_standalone, 6, "sta")
  defhalt(:parse_standalone, 6, "stan")
  defhalt(:parse_standalone, 6, "stand")
  defhalt(:parse_standalone, 6, "standa")
  defhalt(:parse_standalone, 6, "standal")
  defhalt(:parse_standalone, 6, "standalo")
  defhalt(:parse_standalone, 6, "standalon")

  def parse_standalone(<<buffer::bits>>, more?, original, pos, state, prolog) do
    parse_xml_decl_close(buffer, more?, original, pos, state, prolog)
  end

  def parse_standalone_eq(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_standalone_eq(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_standalone_eq(<<?=, rest::bits>>, more?, original, pos, state, prolog) do
    parse_standalone_eq_quote(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt(:parse_standalone_eq, 6, "")

  def parse_standalone_eq(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :standalone})
  end

  def parse_standalone_eq_quote(<<quote, rest::bits>>, more?, original, pos, state, prolog)
      when quote in '\'"' do
    parse_standalone_bool(rest, more?, original, pos + 1, state, prolog, quote)
  end

  defhalt(:parse_standalone_eq_quote, 6, "")

  def parse_standalone_eq_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  def parse_standalone_bool(<<"yes", rest::bits>>, more?, original, pos, state, prolog, open_quote) do
    parse_standalone_end_quote(rest, more?, original, pos + 3, state, [{:standalone, true} | prolog], open_quote)
  end

  def parse_standalone_bool(<<"no", rest::bits>>, more?, original, pos, state, prolog, open_quote) do
    parse_standalone_end_quote(rest, more?, original, pos + 2, state, [{:standalone, false} | prolog], open_quote)
  end

  defhalt(:parse_standalone_bool, 7, "")
  defhalt(:parse_standalone_bool, 7, "y")
  defhalt(:parse_standalone_bool, 7, "n")
  defhalt(:parse_standalone_bool, 7, "ye")

  def parse_standalone_bool(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote) do
    Utils.parse_error(original, pos, state, {:token, :yes_or_no})
  end

  def parse_standalone_end_quote(<<quote, rest::bits>>, more?, original, pos, state, prolog, open_quote)
      when quote in '"\'' and open_quote == quote do
    parse_xml_decl_close(rest, more?, original, pos + 1, state, prolog)
  end

  defhalt(:parse_standalone_end_quote, 7, "")

  def parse_standalone_end_quote(<<_buffer::bits>>, _more?, original, pos, state, _prolog, _open_quote) do
    Utils.parse_error(original, pos, state, {:token, :quote})
  end

  def parse_xml_decl_close(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_xml_decl_close(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_xml_decl_close(<<"?>", rest::bits>>, more?, original, pos, state, prolog) do
    parse_prolog_misc(rest, more?, original, pos + 2, state, prolog)
  end

  defhalt(:parse_xml_decl_close, 6, "")
  defhalt(:parse_xml_decl_close, 6, "?")

  def parse_xml_decl_close(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :xml_decl_close})
  end

  def parse_prolog_misc(<<whitespace::integer, rest::bits>>, more?, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_prolog_misc(rest, more?, original, pos + 1, state, prolog)
  end

  def parse_prolog_misc(<<"<!--", rest::bits>>, more?, original, pos, state, prolog) do
    parse_prolog_misc_comment(rest, more?, original, pos + 4, state, prolog, 0)
  end

  def parse_prolog_misc(<<"<?", rest::bits>>, more?, original, pos, state, prolog) do
    parse_prolog_processing_instruction(rest, more?, original, pos + 2, state, prolog)
  end

  defhalt(:parse_prolog_misc, 6, "")
  defhalt(:parse_prolog_misc, 6, "<")
  defhalt(:parse_prolog_misc, 6, "<!")
  defhalt(:parse_prolog_misc, 6, "<!-")

  def parse_prolog_misc(<<rest::bits>>, more?, original, pos, state, prolog) do
    state = %{state | prolog: prolog}

    case Emitter.emit(:start_document, prolog, state) do
      {:ok, state} ->
        parse_element(rest, more?, original, pos, state)

      {:stop, state} ->
        {:ok, state}

      {:error, other} ->
        Utils.bad_return_error(other)
    end
  end

  def parse_prolog_misc_comment(<<"--->", _rest::bits>>, _more?, original, pos, state, _prolog, len) do
    Utils.parse_error(original, pos + len, state, {:token, :comment})
  end

  def parse_prolog_misc_comment(<<"-->", rest::bits>>, more?, original, pos, state, prolog, len) do
    parse_prolog_misc(rest, more?, original, pos + len + 3, state, prolog)
  end

  defhalt(:parse_prolog_misc_comment, 7, "")
  defhalt(:parse_prolog_misc_comment, 7, "-")
  defhalt(:parse_prolog_misc_comment, 7, "--")

  def parse_prolog_misc_comment(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
      when is_ascii(charcode) do
    parse_prolog_misc_comment(rest, more?, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_misc_comment(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len) do
    parse_prolog_misc_comment(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  def parse_prolog_processing_instruction(<<charcode, rest::bits>>, more?, original, pos, state, prolog)
      when is_name_start_char(charcode) do
    parse_prolog_pi_name(rest, more?, original, pos, state, prolog, 1)
  end

  def parse_prolog_processing_instruction(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog)
      when is_name_start_char(charcode) do
    parse_prolog_pi_name(rest, more?, original, pos, state, prolog, Utils.compute_char_len(charcode))
  end

  defhalt(:parse_prolog_processing_instruction, 6, "")

  def parse_prolog_processing_instruction(<<_buffer::bits>>, _more?, original, pos, state, _prolog) do
    Utils.parse_error(original, pos, state, {:token, :processing_instruction})
  end

  def parse_prolog_pi_name(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
      when is_name_char(charcode) do
    parse_prolog_pi_name(rest, more?, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_pi_name(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len)
      when is_name_char(charcode) do
    parse_prolog_pi_name(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  defhalt(:parse_prolog_pi_name, 7, "")

  def parse_prolog_pi_name(<<rest::bits>>, more?, original, pos, state, prolog, len) do
    pi_name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(pi_name) do
      parse_prolog_pi_content(rest, more?, original, pos + len, state, prolog, 0)
    else
      Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
    end
  end

  def parse_prolog_pi_content(<<"?>", rest::bits>>, more?, original, pos, state, prolog, len) do
    parse_prolog_misc(rest, more?, original, pos + len + 2, state, prolog)
  end

  defhalt(:parse_prolog_pi_content, 7, "")
  defhalt(:parse_prolog_pi_content, 7, "?")

  def parse_prolog_pi_content(<<charcode, rest::bits>>, more?, original, pos, state, prolog, len)
      when is_ascii(charcode) do
    parse_prolog_pi_content(rest, more?, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_pi_content(<<charcode::utf8, rest::bits>>, more?, original, pos, state, prolog, len) do
    parse_prolog_pi_content(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end
end
