defmodule Saxy.Parser.Prolog do
  @moduledoc false

  import Saxy.Guards

  import Saxy.Buffering, only: [buffering_parse_fun: 3]

  import Saxy.Parser.Element, only: [parse_element: 5]

  alias Saxy.Emitter

  alias Saxy.Parser.Utils

  def parse_prolog(<<"<?xml", rest::bits>>, cont, original, pos, state) do
    parse_xml_decl(rest, cont, original, pos + 5, state)
  end

  buffering_parse_fun(:parse_prolog, 5, "")
  buffering_parse_fun(:parse_prolog, 5, "<")
  buffering_parse_fun(:parse_prolog, 5, "<?")
  buffering_parse_fun(:parse_prolog, 5, "<?x")
  buffering_parse_fun(:parse_prolog, 5, "<?xm")

  def parse_prolog(<<buffer::bits>>, cont, original, pos, state) do
    parse_prolog_misc(buffer, cont, original, pos, state, [])
  end

  def parse_xml_decl(<<whitespace, rest::bits>>, cont, original, pos, state)
      when is_whitespace(whitespace) do
    parse_xml_decl(rest, cont, original, pos + 1, state)
  end

  def parse_xml_decl(<<"version", rest::bits>>, cont, original, pos, state) do
    parse_xml_ver_eq(rest, cont, original, pos + 7, state)
  end

  buffering_parse_fun(:parse_xml_decl, 5, "")
  buffering_parse_fun(:parse_xml_decl, 5, "v")
  buffering_parse_fun(:parse_xml_decl, 5, "ve")
  buffering_parse_fun(:parse_xml_decl, 5, "ver")
  buffering_parse_fun(:parse_xml_decl, 5, "vers")
  buffering_parse_fun(:parse_xml_decl, 5, "versi")
  buffering_parse_fun(:parse_xml_decl, 5, "versio")

  def parse_xml_decl(<<buffer::bits>>, _cont, _original, _pos, state) do
    Utils.syntax_error(buffer, state, {:token, :version})
  end

  def parse_xml_ver_eq(<<charcode::integer, rest::bits>>, cont, original, pos, state) when is_whitespace(charcode) do
    parse_xml_ver_eq(rest, cont, original, pos + 1, state)
  end

  def parse_xml_ver_eq(<<?=, rest::bits>>, cont, original, pos, state) do
    parse_xml_ver_quote(rest, cont, original, pos + 1, state)
  end

  buffering_parse_fun(:parse_xml_ver_eq, 5, "")

  def parse_xml_ver_quote(<<whitespace::integer, rest::bits>>, cont, original, pos, state)
      when is_whitespace(whitespace) do
    parse_xml_ver_quote(rest, cont, original, pos + 1, state)
  end

  def parse_xml_ver_quote(<<quote, rest::bits>>, cont, original, pos, state) when quote in '\'"' do
    parse_xml_ver_one_dot(rest, cont, original, pos + 1, state, quote)
  end

  buffering_parse_fun(:parse_xml_ver_quote, 5, "")

  def parse_xml_ver_quote(<<buffer::bits>>, _cont, _original, _pos, state) do
    Utils.syntax_error(buffer, state, {:token, :quote})
  end

  def parse_xml_ver_one_dot(<<"1.", rest::bits>>, cont, original, pos, state, quote) do
    parse_xml_ver_num(rest, cont, original, pos, state, quote, 2)
  end

  buffering_parse_fun(:parse_xml_ver_one_dot, 6, "")
  buffering_parse_fun(:parse_xml_ver_one_dot, 6, "1")

  def parse_xml_ver_one_dot(<<buffer::bits>>, _cont, _original, _pos, state, _quote) do
    Utils.syntax_error(buffer, state, {:token, :"1."})
  end

  def parse_xml_ver_num(<<quote, rest::bits>>, cont, original, pos, state, open_quote, len)
      when quote in '\'"' and quote == open_quote do
    version = binary_part(original, pos, len)
    prolog = [version: version]

    parse_encoding_decl(rest, cont, original, pos + len + 1, state, prolog)
  end

  def parse_xml_ver_num(<<charcode::integer, rest::bits>>, cont, original, pos, state, open_quote, len)
      when charcode in '0123456789' do
    parse_xml_ver_num(rest, cont, original, pos, state, open_quote, len + 1)
  end

  buffering_parse_fun(:parse_xml_ver_num, 7, "")

  def parse_xml_ver_num(<<buffer::bits>>, _cont, _original, _pos, state, _open_quote, _len) do
    Utils.syntax_error(buffer, state, {:token, :version_num})
  end

  def parse_encoding_decl(<<whitespace::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_encoding_decl(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_encoding_decl(<<"encoding", rest::bits>>, cont, original, pos, state, prolog) do
    parse_encoding_decl_eq(rest, cont, original, pos + 8, state, prolog)
  end

  buffering_parse_fun(:parse_encoding_decl, 6, "")
  buffering_parse_fun(:parse_encoding_decl, 6, "e")
  buffering_parse_fun(:parse_encoding_decl, 6, "en")
  buffering_parse_fun(:parse_encoding_decl, 6, "enc")
  buffering_parse_fun(:parse_encoding_decl, 6, "enco")
  buffering_parse_fun(:parse_encoding_decl, 6, "encod")
  buffering_parse_fun(:parse_encoding_decl, 6, "encodi")
  buffering_parse_fun(:parse_encoding_decl, 6, "encodin")

  def parse_encoding_decl(<<buffer::bits>>, cont, original, pos, state, prolog) do
    parse_standalone(buffer, cont, original, pos, state, prolog)
  end

  def parse_encoding_decl_eq(<<charcode::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(charcode) do
    parse_encoding_decl_eq(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_encoding_decl_eq(<<?=, rest::bits>>, cont, original, pos, state, prolog) do
    parse_encoding_decl_eq_quote(rest, cont, original, pos + 1, state, prolog)
  end

  buffering_parse_fun(:parse_encoding_decl_eq, 6, "")

  def parse_encoding_decl_eq(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :eq})
  end

  def parse_encoding_decl_eq_quote(<<charcode::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(charcode) do
    parse_encoding_decl_eq_quote(rest, cont, original, pos, state, prolog)
  end

  def parse_encoding_decl_eq_quote(<<?", rest::bits>>, cont, original, pos, state, prolog) do
    parse_encoding_decl_enc_name(rest, cont, original, pos + 1, state, prolog, ?", 0)
  end

  def parse_encoding_decl_eq_quote(<<?', rest::bits>>, cont, original, pos, state, prolog) do
    parse_encoding_decl_enc_name(rest, cont, original, pos + 1, state, prolog, ?', 0)
  end

  buffering_parse_fun(:parse_encoding_decl_eq_quote, 6, "")

  def parse_encoding_decl_eq_quote(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :quote})
  end

  def parse_encoding_decl_enc_name(<<charcode, rest::bits>>, cont, original, pos, state, prolog, open_quote, len)
      when charcode in '\'"' and open_quote == charcode do
    encoding = binary_part(original, pos, len)

    parse_standalone(rest, cont, original, pos + len + 1, state, [{:encoding, encoding} | prolog])
  end

  def parse_encoding_decl_enc_name(<<charcode::integer, rest::bits>>, cont, original, pos, state, prolog, open_quote, len)
       when charcode in ?A..?Z or charcode in ?a..?z or
            charcode in ?0..?9 or charcode in [?-, ?., ?_] do
    parse_encoding_decl_enc_name(rest, cont, original, pos, state, prolog, open_quote, len + 1)
  end

  buffering_parse_fun(:parse_encoding_decl_enc_name, 8, "")

  def parse_encoding_decl_enc_name(<<buffer::bits>>, _cont, _original, _pos, state, _prolog, _open_quote, _len) do
    Utils.syntax_error(buffer, state, {:token, :encoding_name})
  end

  def parse_standalone(<<whitespace::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_standalone(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_standalone(<<"standalone", rest::bits>>, cont, original, pos, state, prolog) do
    parse_standalone_eq(rest, cont, original, pos + 10, state, prolog)
  end

  buffering_parse_fun(:parse_standalone, 6, "")
  buffering_parse_fun(:parse_standalone, 6, "s")
  buffering_parse_fun(:parse_standalone, 6, "st")
  buffering_parse_fun(:parse_standalone, 6, "sta")
  buffering_parse_fun(:parse_standalone, 6, "stan")
  buffering_parse_fun(:parse_standalone, 6, "stand")
  buffering_parse_fun(:parse_standalone, 6, "standa")
  buffering_parse_fun(:parse_standalone, 6, "standal")
  buffering_parse_fun(:parse_standalone, 6, "standalo")
  buffering_parse_fun(:parse_standalone, 6, "standalon")

  def parse_standalone(<<buffer::bits>>, cont, original, pos, state, prolog) do
    parse_xml_decl_close(buffer, cont, original, pos, state, prolog)
  end

  def parse_standalone_eq(<<whitespace::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_standalone_eq(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_standalone_eq(<<?=, rest::bits>>, cont, original, pos, state, prolog) do
    parse_standalone_eq_quote(rest, cont, original, pos + 1, state, prolog)
  end

  buffering_parse_fun(:parse_standalone_eq, 6, "")

  def parse_standalone_eq(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :standalone})
  end

  def parse_standalone_eq_quote(<<quote, rest::bits>>, cont, original, pos, state, prolog)
      when quote in '\'"' do
    parse_standalone_bool(rest, cont, original, pos + 1, state, prolog, quote)
  end

  buffering_parse_fun(:parse_standalone_eq_quote, 6, "")

  def parse_standalone_eq_quote(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :quote})
  end

  def parse_standalone_bool(<<"yes", rest::bits>>, cont, original, pos, state, prolog, open_quote) do
    parse_standalone_end_quote(rest, cont, original, pos + 3, state, [{:standalone, true} | prolog], open_quote)
  end

  def parse_standalone_bool(<<"no", rest::bits>>, cont, original, pos, state, prolog, open_quote) do
    parse_standalone_end_quote(rest, cont, original, pos + 2, state, [{:standalone, false} | prolog], open_quote)
  end

  buffering_parse_fun(:parse_standalone_bool, 7, "")
  buffering_parse_fun(:parse_standalone_bool, 7, "y")
  buffering_parse_fun(:parse_standalone_bool, 7, "n")
  buffering_parse_fun(:parse_standalone_bool, 7, "ye")

  def parse_standalone_bool(<<buffer::bits>>, _cont, _original, _pos, state, _prolog, _open_quote) do
    Utils.syntax_error(buffer, state, {:token, :yes_or_no})
  end

  def parse_standalone_end_quote(<<quote, rest::bits>>, cont, original, pos, state, prolog, open_quote)
      when quote in '"\'' and open_quote == quote do
    parse_xml_decl_close(rest, cont, original, pos + 1, state, prolog)
  end

  buffering_parse_fun(:parse_standalone_end_quote, 7, "")

  def parse_standalone_end_quote(<<buffer::bits>>, _cont, _original, _pos, state, _prolog, _open_quote) do
    Utils.syntax_error(buffer, state, {:token, :quote})
  end

  def parse_xml_decl_close(<<whitespace::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_xml_decl_close(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_xml_decl_close(<<"?>", rest::bits>>, cont, original, pos, state, prolog) do
    parse_prolog_misc(rest, cont, original, pos + 2, state, prolog)
  end

  buffering_parse_fun(:parse_xml_decl_close, 6, "")
  buffering_parse_fun(:parse_xml_decl_close, 6, "?")

  def parse_xml_decl_close(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :xml_decl_close})
  end

  def parse_prolog_misc(<<whitespace::integer, rest::bits>>, cont, original, pos, state, prolog)
      when is_whitespace(whitespace) do
    parse_prolog_misc(rest, cont, original, pos + 1, state, prolog)
  end

  def parse_prolog_misc(<<"<!--", rest::bits>>, cont, original, pos, state, prolog) do
    parse_prolog_misc_comment(rest, cont, original, pos + 4, state, prolog, 0)
  end

  def parse_prolog_misc(<<"<?", rest::bits>>, cont, original, pos, state, prolog) do
    parse_prolog_processing_instruction(rest, cont, original, pos + 2, state, prolog)
  end

  buffering_parse_fun(:parse_prolog_misc, 6, "")
  buffering_parse_fun(:parse_prolog_misc, 6, "<")
  buffering_parse_fun(:parse_prolog_misc, 6, "<!")
  buffering_parse_fun(:parse_prolog_misc, 6, "<!-")

  def parse_prolog_misc(<<rest::bits>>, cont, original, pos, state, prolog) do
    state = %{state | prolog: prolog}

    case Emitter.emit(:start_document, prolog, state) do
      {:ok, state} ->
        parse_element(rest, cont, original, pos, state)

      {:stop, state} ->
        {:ok, state}

      {:error, other} ->
        Utils.bad_return_error(other)
    end
  end

  def parse_prolog_misc_comment(<<"--->", _::bits>>, _cont, _original, _pos, state, _prolog, _len) do
    Utils.syntax_error("--->", state, {:token, :comment})
  end

  def parse_prolog_misc_comment(<<"-->", rest::bits>>, cont, original, pos, state, prolog, len) do
    parse_prolog_misc(rest, cont, original, pos + len + 3, state, prolog)
  end

  buffering_parse_fun(:parse_prolog_misc_comment, 7, "")
  buffering_parse_fun(:parse_prolog_misc_comment, 7, "-")
  buffering_parse_fun(:parse_prolog_misc_comment, 7, "--")

  def parse_prolog_misc_comment(<<charcode, rest::bits>>, cont, original, pos, state, prolog, len)
      when is_ascii(charcode) do
    parse_prolog_misc_comment(rest, cont, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_misc_comment(<<charcode::utf8, rest::bits>>, cont, original, pos, state, prolog, len) do
    parse_prolog_misc_comment(rest, cont, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  def parse_prolog_processing_instruction(<<charcode, rest::bits>>, cont, original, pos, state, prolog)
       when is_name_start_char(charcode) do
    parse_prolog_pi_name(rest, cont, original, pos, state, prolog, 1)
  end

  def parse_prolog_processing_instruction(<<charcode::utf8, rest::bits>>, cont, original, pos, state, prolog)
       when is_name_start_char(charcode) do
    parse_prolog_pi_name(rest, cont, original, pos, state, prolog, Utils.compute_char_len(charcode))
  end

  buffering_parse_fun(:parse_prolog_processing_instruction, 6, "")

  def parse_prolog_processing_instruction(<<buffer::bits>>, _cont, _original, _pos, state, _prolog) do
    Utils.syntax_error(buffer, state, {:token, :processing_instruction})
  end

  def parse_prolog_pi_name(<<charcode, rest::bits>>, cont, original, pos, state, prolog, len)
       when is_name_char(charcode) do
    parse_prolog_pi_name(rest, cont, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_pi_name(<<charcode::utf8, rest::bits>>, cont, original, pos, state, prolog, len)
       when is_name_char(charcode) do
    parse_prolog_pi_name(rest, cont, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end

  buffering_parse_fun(:parse_prolog_pi_name, 7, "")

  def parse_prolog_pi_name(<<rest::bits>>, cont, original, pos, state, prolog, len) do
    pi_name = binary_part(original, pos, len)

    if Utils.valid_pi_name?(pi_name) do
      parse_prolog_pi_content(rest, cont, original, pos + len, state, prolog, 0)
    else
      Utils.syntax_error(rest, state, {:invalid_pi, pi_name})
    end
  end

  def parse_prolog_pi_content(<<"?>", rest::bits>>, cont, original, pos, state, prolog, len) do
    parse_prolog_misc(rest, cont, original, pos + len + 2, state, prolog)
  end

  buffering_parse_fun(:parse_prolog_pi_content, 7, "")
  buffering_parse_fun(:parse_prolog_pi_content, 7, "?")

  def parse_prolog_pi_content(<<charcode, rest::bits>>, cont, original, pos, state, prolog, len)
      when is_ascii(charcode) do
    parse_prolog_pi_content(rest, cont, original, pos, state, prolog, len + 1)
  end

  def parse_prolog_pi_content(<<charcode::utf8, rest::bits>>, cont, original, pos, state, prolog, len) do
    parse_prolog_pi_content(rest, cont, original, pos, state, prolog, len + Utils.compute_char_len(charcode))
  end
end
