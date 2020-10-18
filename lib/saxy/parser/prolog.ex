defmodule Saxy.Parser.Prolog do
  @moduledoc false

  import Saxy.Guards
  import Saxy.BufferingHelper
  import Saxy.Emitter, only: [emit: 4]
  import Saxy.Parser.Lookahead

  alias Saxy.Parser.{
    Element,
    Utils
  }

  @streaming :saxy
             |> Application.get_env(:parser, [])
             |> Keyword.get(:streaming, true)

  def parse(<<buffer::bits>>, more?, original, pos, state) do
    prolog(buffer, more?, original, pos, state)
  end

  defp prolog(<<buffer::bits>>, more?, original, pos, state) do
    lookahead(buffer, @streaming) do
      "<?xml" <> rest ->
        xml_decl(rest, more?, original, pos + 5, state)

      token in unquote(edge_ngrams("<?xm")) when more? ->
        halt!(prolog(token, more?, original, pos, state))

      _ ->
        prolog_misc(buffer, more?, original, pos, state, [])
    end
  end

  defp xml_decl(<<buffer::bits>>, more?, original, pos, state) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        xml_decl(rest, more?, original, pos + 1, state)

      "version" <> rest ->
        xml_ver_eq(rest, more?, original, pos + 7, state)

      token in unquote(edge_ngrams("versio")) when more? ->
        halt!(xml_decl(token, more?, original, pos, state))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :version})
    end
  end

  defp xml_ver_eq(<<buffer::bits>>, more?, original, pos, state) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        xml_ver_eq(rest, more?, original, pos + 1, state)

      "=" <> rest ->
        xml_ver_quote(rest, more?, original, pos + 1, state)

      _ in [""] when more? ->
        halt!(xml_ver_eq("", more?, original, pos, state))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :=})
    end
  end

  defp xml_ver_quote(<<buffer::bits>>, more?, original, pos, state) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        xml_ver_quote(rest, more?, original, pos + 1, state)

      open_quote <> rest when open_quote in [?', ?"] ->
        xml_ver_one_dot(rest, more?, original, pos + 1, state, open_quote)

      _ in [""] when more? ->
        halt!(xml_ver_quote("", more?, original, pos, state))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :quote})
    end
  end

  defp xml_ver_one_dot(<<buffer::bits>>, more?, original, pos, state, open_quote) do
    lookahead(buffer, @streaming) do
      "1." <> rest ->
        xml_ver_num(rest, more?, original, pos, state, open_quote, 2)

      token in unquote(edge_ngrams("1")) when more? ->
        halt!(xml_ver_one_dot(token, more?, original, pos, state, open_quote))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :"1."})
    end
  end

  defp xml_ver_num(<<buffer::bits>>, more?, original, pos, state, open_quote, len) do
    lookahead(buffer, @streaming) do
      ^open_quote <> rest when len > 2 ->
        version = binary_part(original, pos, len)
        prolog = [version: version]

        encoding_decl(rest, more?, original, pos + len + 1, state, prolog)

      char <> rest when char in '0123456789' ->
        xml_ver_num(rest, more?, original, pos, state, open_quote, len + 1)

      _ in [""] when more? ->
        halt!(xml_ver_num("", more?, original, pos, state, open_quote, len))

      _ ->
        Utils.parse_error(original, pos + len, state, {:token, :version_num})
    end
  end

  defp encoding_decl(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      "encoding" <> rest ->
        encoding_decl_eq(rest, more?, original, pos + 8, state, prolog)

      whitespace <> rest when is_whitespace(whitespace) ->
        encoding_decl(rest, more?, original, pos + 1, state, prolog)

      token in unquote(edge_ngrams("encodin")) when more? ->
        halt!(encoding_decl(token, more?, original, pos, state, prolog))

      _ ->
        standalone(buffer, more?, original, pos, state, prolog)
    end
  end

  defp encoding_decl_eq(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        encoding_decl_eq(rest, more?, original, pos + 1, state, prolog)

      "=" <> rest ->
        encoding_decl_eq_quote(rest, more?, original, pos + 1, state, prolog)

      _ in [""] when more? ->
        halt!(encoding_decl_eq("", more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :eq})
    end
  end

  defp encoding_decl_eq_quote(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        encoding_decl_eq_quote(rest, more?, original, pos + 1, state, prolog)

      open_quote <> rest when open_quote in [?', ?"] ->
        encoding_decl_enc_name(rest, more?, original, pos + 1, state, prolog, open_quote, 0)

      _ in [""] when more? ->
        halt!(encoding_decl_eq_quote("", more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :quote})
    end
  end

  defp encoding_decl_enc_name(<<buffer::bits>>, more?, original, pos, state, prolog, open_quote, len) do
    lookahead(buffer, @streaming) do
      ^open_quote <> rest ->
        encoding = binary_part(original, pos, len)

        if Utils.valid_encoding?(encoding) do
          standalone(rest, more?, original, pos + len + 1, state, [{:encoding, encoding} | prolog])
        else
          Utils.parse_error(original, pos, state, {:invalid_encoding, encoding})
        end

      char <> rest when char in ?A..?Z or char in ?a..?z or char in ?0..?9 or char in [?-, ?., ?_] ->
        encoding_decl_enc_name(rest, more?, original, pos, state, prolog, open_quote, len + 1)

      _ in [""] when more? ->
        halt!(encoding_decl_enc_name("", more?, original, pos, state, prolog, open_quote, len))

      _ ->
        Utils.parse_error(original, pos + len, state, {:token, :encoding_name})
    end
  end

  defp standalone(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        standalone(rest, more?, original, pos + 1, state, prolog)

      "standalone" <> rest ->
        standalone_eq(rest, more?, original, pos + 10, state, prolog)

      token in unquote(edge_ngrams("standalon")) when more? ->
        halt!(standalone(token, more?, original, pos, state, prolog))

      _ ->
        xml_decl_close(buffer, more?, original, pos, state, prolog)
    end
  end

  defp standalone_eq(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        standalone_eq(rest, more?, original, pos + 1, state, prolog)

      "=" <> rest ->
        standalone_eq_quote(rest, more?, original, pos + 1, state, prolog)

      _ in [""] when more? ->
        halt!(standalone_eq("", more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :standalone})
    end
  end

  defp standalone_eq_quote(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        standalone_eq_quote(rest, more?, original, pos + 1, state, prolog)

      open_quote <> rest when open_quote in [?', ?"] ->
        standalone_bool(rest, more?, original, pos + 1, state, prolog, open_quote)

      _ in [""] when more? ->
        halt!(standalone_eq_quote("", more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :quote})
    end
  end

  defp standalone_bool(<<buffer::bits>>, more?, original, pos, state, prolog, open_quote) do
    lookahead(buffer, @streaming) do
      "yes" <> rest ->
        standalone_end_quote(rest, more?, original, pos + 3, state, [{:standalone, true} | prolog], open_quote)

      "no" <> rest ->
        standalone_end_quote(rest, more?, original, pos + 2, state, [{:standalone, false} | prolog], open_quote)

      token in unquote(edge_ngrams("n")) when more? ->
        halt!(standalone_bool(token, more?, original, pos, state, prolog, open_quote))

      token in unquote(edge_ngrams("ye")) when more? ->
        halt!(standalone_bool(token, more?, original, pos, state, prolog, open_quote))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :yes_or_no})
    end
  end

  defp standalone_end_quote(<<buffer::bits>>, more?, original, pos, state, prolog, open_quote) do
    lookahead(buffer, @streaming) do
      ^open_quote <> rest ->
        xml_decl_close(rest, more?, original, pos + 1, state, prolog)

      _ in [""] when more? ->
        halt!(standalone_end_quote("", more?, original, pos, state, prolog, open_quote))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :quote})
    end
  end

  defp xml_decl_close(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        xml_decl_close(rest, more?, original, pos + 1, state, prolog)

      "?>" <> rest ->
        prolog_misc(rest, more?, original, pos + 2, state, prolog)

      token in unquote(edge_ngrams("?")) when more? ->
        halt!(xml_decl_close(token, more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :xml_decl_close})
    end
  end

  defp prolog_misc(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      whitespace <> rest when is_whitespace(whitespace) ->
        prolog_misc(rest, more?, original, pos + 1, state, prolog)

      "<!--" <> rest ->
        prolog_misc_comment(rest, more?, original, pos + 4, state, prolog, 0)

      "<?" <> rest ->
        prolog_processing_instruction(rest, more?, original, pos + 2, state, prolog)

      token in unquote(edge_ngrams("<!-")) when more? ->
        halt!(prolog_misc(token, more?, original, pos, state, prolog))

      _ ->
        state = %{state | prolog: prolog}

        with {:cont, state} <- emit(:start_document, prolog, state, {original, pos}) do
          dtd(buffer, more?, original, pos, state)
        end
    end
  end

  defp prolog_misc_comment(<<buffer::bits>>, more?, original, pos, state, prolog, len) do
    lookahead(buffer, @streaming) do
      "-->" <> rest ->
        prolog_misc(rest, more?, original, pos + len + 3, state, prolog)

      "--->" <> _rest ->
        Utils.parse_error(original, pos + len, state, {:token, :comment})

      token in unquote(edge_ngrams("--")) when more? ->
        halt!(prolog_misc_comment(token, more?, original, pos, state, prolog, len))

      char <> rest when is_ascii(char) ->
        prolog_misc_comment(rest, more?, original, pos, state, prolog, len + 1)

      <<codepoint::utf8>> <> rest ->
        prolog_misc_comment(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(codepoint))
    end
  end

  defp prolog_processing_instruction(<<buffer::bits>>, more?, original, pos, state, prolog) do
    lookahead(buffer, @streaming) do
      char <> rest when is_ascii_name_start_char(char) ->
        prolog_pi_name(rest, more?, original, pos, state, prolog, 1)

      <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
        prolog_pi_name(rest, more?, original, pos, state, prolog, Utils.compute_char_len(codepoint))

      _ in [""] when more? ->
        halt!(prolog_processing_instruction("", more?, original, pos, state, prolog))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :processing_instruction})
    end
  end

  defp prolog_pi_name(<<buffer::bits>>, more?, original, pos, state, prolog, len) do
    lookahead buffer, @streaming do
      char <> rest when is_ascii_name_char(char) ->
        prolog_pi_name(rest, more?, original, pos, state, prolog, len + 1)

      <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
        prolog_pi_name(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(codepoint))

      token in [""] when more? ->
        halt!(prolog_pi_name(token, more?, original, pos, state, prolog, len))

      _ ->
        pi_name = binary_part(original, pos, len)

        if Utils.valid_pi_name?(pi_name) do
          prolog_pi_content(buffer, more?, original, pos + len, state, prolog, 0)
        else
          Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
        end
    end
  end

  defp prolog_pi_content(<<buffer::bits>>, more?, original, pos, state, prolog, len) do
    lookahead buffer, @streaming do
      "?>" <> rest ->
        prolog_misc(rest, more?, original, pos + len + 2, state, prolog)

      token in unquote(edge_ngrams("?")) when more? ->
        halt!(prolog_pi_content(token, more?, original, pos, state, prolog, len))

      char <> rest when is_ascii(char) ->
        prolog_pi_content(rest, more?, original, pos, state, prolog, len + 1)

      <<codepoint::utf8>> <> rest ->
        prolog_pi_content(rest, more?, original, pos, state, prolog, len + Utils.compute_char_len(codepoint))
    end
  end

  defp dtd(<<buffer::bits>>, more?, original, pos, state) do
    lookahead buffer, @streaming do
      "<!DOCTYPE" <> rest ->
        dtd_content(rest, more?, original, pos + 9, state, 0, 1)

      token in unquote(edge_ngrams("<!DOCTYP")) when more? ->
        halt!(dtd(token, more?, original, pos, state))

      _ ->
        Element.parse(buffer, more?, original, pos, state)
    end
  end

  # We skips every content in DTD, though we care about the quotes.
  defp dtd_content(<<buffer::bits>>, more?, original, pos, state, len, count) do
    lookahead buffer, @streaming do
      ">" <> rest ->
        if count == 1 do
          dtd_misc(rest, more?, original, pos + len + 1, state)
        else
          dtd_content(rest, more?, original, pos, state, len + 1, count - 1)
        end

      "<" <> rest ->
        dtd_content(rest, more?, original, pos, state, len + 1, count + 1)

      _ <> rest ->
        dtd_content(rest, more?, original, pos, state, len + 1, count)

      token in [""] when more? ->
        halt!(dtd_content(token, more?, original, pos, state, len, count))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :dtd_content})
    end
  end

  defp dtd_misc(<<buffer::bits>>, more?, original, pos, state) do
    lookahead buffer, @streaming do
      whitespace <> rest when is_whitespace(whitespace) ->
        dtd_misc(rest, more?, original, pos + 1, state)

      "<!--" <> rest ->
        dtd_misc_comment(rest, more?, original, pos + 4, state, 0)

      "<?" <> rest ->
        dtd_processing_instruction(rest, more?, original, pos + 2, state)

      token in unquote(edge_ngrams("<!-")) when more? ->
        halt!(dtd_misc(token, more?, original, pos, state))

      _ ->
        Element.parse(buffer, more?, original, pos, state)
    end
  end

  defp dtd_misc_comment(<<buffer::bits>>, more?, original, pos, state, len) do
    lookahead buffer, @streaming do
      "--->" <> _rest ->
        Utils.parse_error(original, pos + len, state, {:token, :comment})

      "-->" <> rest ->
        dtd_misc(rest, more?, original, pos + len + 3, state)

      token in unquote(edge_ngrams("--")) when more? ->
        halt!(dtd_misc_comment(token, more?, original, pos, state, len))

      char <> rest when is_ascii(char) ->
        dtd_misc_comment(rest, more?, original, pos, state, len + 1)

      <<codepoint::utf8>> <> rest ->
        dtd_misc_comment(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

      _ ->
        Utils.parse_error(original, pos + len, state, {:token, :comment})
    end
  end

  defp dtd_processing_instruction(<<buffer::bits>>, more?, original, pos, state) do
    lookahead buffer, @streaming do
      char <> rest when is_ascii_name_start_char(char) ->
        dtd_pi_name(rest, more?, original, pos, state, 1)

      <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
        dtd_pi_name(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

      token in [""] when more? ->
        halt!(dtd_processing_instruction(token, more?, original, pos, state))

      _ ->
        Utils.parse_error(original, pos, state, {:token, :processing_instruction})
    end
  end

  defp dtd_pi_name(<<buffer::bits>>, more?, original, pos, state, len) do
    lookahead buffer, @streaming do
      char <> rest when is_ascii_name_char(char) ->
        dtd_pi_name(rest, more?, original, pos, state, len + 1)

      <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
        dtd_pi_name(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

      token in [""] when more? ->
        halt!(dtd_pi_name(token, more?, original, pos, state, len))

      _ ->
        pi_name = binary_part(original, pos, len)

        if Utils.valid_pi_name?(pi_name) do
          dtd_pi_content(buffer, more?, original, pos + len, state, 0)
        else
          Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
        end
    end
  end

  defp dtd_pi_content(<<buffer::bits>>, more?, original, pos, state, len) do
    lookahead buffer, @streaming do
      "?>" <> rest ->
        dtd_misc(rest, more?, original, pos + len + 2, state)

      token in unquote(edge_ngrams("?")) when more? ->
        halt!(dtd_pi_content(token, more?, original, pos, state, len))

      char <> rest when is_ascii(char) ->
        dtd_pi_content(rest, more?, original, pos, state, len + 1)

      <<codepoint::utf8>> <> rest ->
        dtd_pi_content(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))
    end
  end
end
