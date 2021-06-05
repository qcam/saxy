defmodule Saxy.Parser.Builder do
  @moduledoc false

  import Saxy.Parser.Lookahead
  import Saxy.BufferingHelper
  import Saxy.Emitter
  import Saxy.Guards

  alias Saxy.Parser.Utils
  alias Saxy.Emitter

  defmacro __using__(options) do
    streaming? = Keyword.fetch!(options, :streaming?)

    quote do
      @streaming unquote(streaming?)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      def parse_prolog(<<buffer::bits>>, more?, original, pos, state) do
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
            parse_element(buffer, more?, original, pos, state)
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
            parse_element(buffer, more?, original, pos, state)
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

      defp parse_element(<<rest::bits>>, more?, original, pos, state) do
        element(rest, more?, original, pos, state)
      end

      defp element(<<buffer::bits>>, more?, original, pos, state) do
        lookahead(buffer, @streaming) do
          "<" <> rest ->
            open_tag(rest, more?, original, pos + 1, state)

          _ in [""] when more? ->
            halt!(element("", more?, original, pos, state))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :lt})
        end
      end

      defp open_tag(<<buffer::bits>>, more?, original, pos, state) do
        lookahead(buffer, @streaming) do
          char <> rest when is_ascii_name_start_char(char) ->
            open_tag_name(rest, more?, original, pos, state, 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(open_tag(token, more?, original, pos, state))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            open_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            halt!(open_tag("", more?, original, pos, state))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :name_start_char})
        end
      end

      defp open_tag_name(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead(buffer, @streaming) do
          char <> rest when is_ascii_name_char(char) ->
            open_tag_name(rest, more?, original, pos, state, len + 1)

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            open_tag_name(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          token in unquote(utf8_binaries()) when more? ->
            halt!(open_tag_name(token, more?, original, pos, state, len))

          _ in [""] when more? ->
            halt!(open_tag_name("", more?, original, pos, state, len))

          _ ->
            name = binary_part(original, pos, len)
            %{stack: stack} = state
            state = %{state | stack: [name | stack]}
            sattribute(buffer, more?, original, pos + len, state, [])
        end
      end

      defp sattribute(<<buffer::bits>>, more?, original, pos, state, attributes) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            attribute_name(rest, more?, original, pos, state, attributes, 1)

          ">" <> rest ->
            %{stack: [tag_name | _]} = state
            event_data = {tag_name, Enum.reverse(attributes)}
            pos = pos + 1

            with {:cont, state} <- emit(:start_element, event_data, state, {original, pos}) do
              element_content(rest, more?, original, pos, state)
            end

          "/>" <> rest ->
            %{stack: [tag_name | stack]} = state
            pos = pos + 2

            state = %{state | stack: stack}
            event_data = {tag_name, Enum.reverse(attributes)}
            on_halt_data = {original, pos}

            with {:cont, state} <- emit(:start_element, event_data, state, on_halt_data),
                 {:cont, state} <- emit(:end_element, tag_name, state, on_halt_data) do
              case stack do
                [] ->
                  element_misc(rest, more?, original, pos, state)

                _ ->
                  {original, pos} = maybe_trim(more?, original, pos)
                  element_content(rest, more?, original, pos, state)
              end
            end

          token in unquote(utf8_binaries()) when more? ->
            halt!(sattribute(token, more?, original, pos, state, attributes))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            attribute_name(rest, more?, original, pos, state, attributes, Utils.compute_char_len(codepoint))

          whitespace <> rest when is_whitespace(whitespace) ->
            sattribute(rest, more?, original, pos + 1, state, attributes)

          token in unquote(edge_ngrams("/")) when more? ->
            halt!(sattribute(token, more?, original, pos, state, attributes))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :name_start_char})
        end
      end

      defp attribute_name(<<buffer::bits>>, more?, original, pos, state, attributes, len) do
        lookahead(buffer, @streaming) do
          char <> rest when is_ascii_name_char(char) ->
            attribute_name(rest, more?, original, pos, state, attributes, len + 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(attribute_name(token, more?, original, pos, state, attributes, len))

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            attribute_name(rest, more?, original, pos, state, attributes, len + Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            halt!(attribute_name("", more?, original, pos, state, attributes, len))

          _ ->
            attribute_name = binary_part(original, pos, len)
            attribute_eq(buffer, more?, original, pos + len, state, attributes, attribute_name)
        end
      end

      defp attribute_eq(<<buffer::bits>>, more?, original, pos, state, attributes, att_name) do
        lookahead(buffer, @streaming) do
          "=" <> rest ->
            attribute_quote(rest, more?, original, pos + 1, state, attributes, att_name)

          whitespace <> rest when is_whitespace(whitespace) ->
            attribute_eq(rest, more?, original, pos + 1, state, attributes, att_name)

          _ in [""] when more? ->
            halt!(attribute_eq("", more?, original, pos, state, attributes, att_name))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :eq})
        end
      end

      defp attribute_quote(<<buffer::bits>>, more?, original, pos, state, attributes, att_name) do
        lookahead buffer, @streaming do
          open_quote <> rest when open_quote in [?", ?'] ->
            att_value(rest, more?, original, pos + 1, state, attributes, open_quote, att_name, "", 0)

          whitespace <> rest when is_whitespace(whitespace) ->
            attribute_quote(rest, more?, original, pos + 1, state, attributes, att_name)

          _ in [""] when more? ->
            halt!(attribute_quote("", more?, original, pos, state, attributes, att_name))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :quote})
        end
      end

      defp att_value(<<buffer::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, len) do
        lookahead(buffer, @streaming) do
          ^open_quote <> rest ->
            att_value = [acc | binary_part(original, pos, len)] |> IO.iodata_to_binary()
            attributes = [{att_name, att_value} | attributes]

            sattribute(rest, more?, original, pos + len + 1, state, attributes)

          token in unquote(edge_ngrams("&#")) when more? ->
            halt!(att_value(token, more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          "&#x" <> rest ->
            att_value = binary_part(original, pos, len)
            acc = [acc | att_value]
            pos = pos + len + 3
            att_value_char_hex_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, 0)

          "&#" <> rest ->
            att_value = binary_part(original, pos, len)
            acc = [acc | att_value]
            pos = pos + len + 2
            att_value_char_dec_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, 0)

          "&" <> rest ->
            att_value = binary_part(original, pos, len)
            acc = [acc | att_value]
            pos = pos + len + 1
            att_value_entity_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, 0)

          char <> rest when is_ascii(char) ->
            att_value(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len + 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(att_value(token, more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          <<codepoint::utf8>> <> rest ->
            len = len + Utils.compute_char_len(codepoint)
            att_value(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len)

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :att_value})
        end
      end

      defp att_value_entity_ref(<<buffer::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, 0) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            att_value_entity_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(att_value_entity_ref(token, more?, original, pos, state, attributes, open_quote, att_name, acc, 0))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            att_value_entity_ref(
              rest,
              more?,
              original,
              pos,
              state,
              attributes,
              open_quote,
              att_name,
              acc,
              Utils.compute_char_len(codepoint)
            )

          _ in [""] when more? ->
            halt!(att_value_entity_ref("", more?, original, pos, state, attributes, open_quote, att_name, acc, 0))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :name_start_char})
        end
      end

      defp att_value_entity_ref(<<buffer::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_char(char) ->
            att_value_entity_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len + 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(att_value_entity_ref(token, more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            len = len + Utils.compute_char_len(codepoint)
            att_value_entity_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len)

          ";" <> rest ->
            name = binary_part(original, pos, len)
            converted = Emitter.convert_entity_reference(name, state)
            acc = [acc | converted]

            att_value(rest, more?, original, pos + len + 1, state, attributes, open_quote, att_name, acc, 0)

          _ in [""] when more? ->
            halt!(att_value_entity_ref("", more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :entity_ref})
        end
      end

      defp att_value_char_dec_ref(<<buffer::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, len) do
        lookahead buffer, @streaming do
          digit <> rest when digit in ?0..?9 ->
            att_value_char_dec_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len + 1)

          ";" <> rest ->
            codepoint = original |> binary_part(pos, len) |> String.to_integer(10)
            pos = pos + len + 1
            att_value(rest, more?, original, pos, state, attributes, open_quote, att_name, [acc | <<codepoint::utf8>>], 0)

          _ in [""] when more? ->
            halt!(att_value_char_dec_ref("", more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :char_ref})
        end
      end

      defp att_value_char_hex_ref(<<buffer::bits>>, more?, original, pos, state, attributes, open_quote, att_name, acc, len) do
        lookahead buffer, @streaming do
          char <> rest when char in ?0..?9 or char in ?A..?F or char in ?a..?f ->
            att_value_char_hex_ref(rest, more?, original, pos, state, attributes, open_quote, att_name, acc, len + 1)

          ";" <> rest ->
            codepoint = original |> binary_part(pos, len) |> String.to_integer(16)
            pos = pos + len + 1

            att_value(rest, more?, original, pos, state, attributes, open_quote, att_name, [acc | <<codepoint::utf8>>], 0)

          _ in [""] when more? ->
            halt!(att_value_char_hex_ref("", more?, original, pos, state, attributes, open_quote, att_name, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :char_ref})
        end
      end

      defp element_content(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii(char) ->
            case char do
              ?< ->
                element_content_rest(rest, more?, original, pos + 1, state)

              ?& ->
                element_content_reference(rest, more?, original, pos + 1, state, <<>>)

              whitespace when is_whitespace(whitespace) ->
                chardata_whitespace(rest, more?, original, pos, state, 1)

              _ ->
                chardata(rest, more?, original, pos, state, "", 1)
            end

          _ in [""] when more? ->
            halt!(element_content("", more?, original, pos, state))

          token in unquote(utf8_binaries()) when more? ->
            halt!(element_content(token, more?, original, pos, state))

          <<codepoint::utf8>> <> rest ->
            chardata(rest, more?, original, pos, state, "", Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :content})
        end
      end

      defp element_content_rest(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            open_tag_name(rest, more?, original, pos, state, 1)

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            open_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

          "/" <> rest ->
            close_tag_name(rest, more?, original, pos + 1, state, 0)

          "![CDATA[" <> rest ->
            element_cdata(rest, more?, original, pos + 8, state, 0)

          "!--" <> rest ->
            element_content_comment(rest, more?, original, pos + 3, state, 0)

          "?" <> rest ->
            element_processing_instruction(rest, more?, original, pos + 1, state, 0)

          token in unquote(Enum.uniq(edge_ngrams("![CDATA") ++ edge_ngrams("!-"))) when more? ->
            halt!(element_content_rest(token, more?, original, pos, state))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :lt})
        end
      end

      defp element_cdata(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          "]]>" <> rest ->
            cdata = binary_part(original, pos, len)
            pos = pos + len + 3

            if state.cdata_as_characters do
              with {:cont, state} <- emit(:characters, cdata, state, {original, pos}) do
                element_content(rest, more?, original, pos, state)
              end
            else
              with {:cont, state} <- emit(:cdata, cdata, state, {original, pos}) do
                element_content(rest, more?, original, pos, state)
              end
            end

          token in unquote(edge_ngrams("]]")) when more? ->
            halt!(element_cdata(token, more?, original, pos, state, len))

          char <> rest when is_ascii(char) ->
            element_cdata(rest, more?, original, pos, state, len + 1)

          <<codepoint::utf8>> <> rest ->
            element_cdata(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :"]]"})
        end
      end

      defp chardata_whitespace(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii(char) ->
            case char do
              whitespace when is_whitespace(whitespace) ->
                chardata_whitespace(rest, more?, original, pos, state, len + 1)

              ?< ->
                chars = binary_part(original, pos, len)
                pos = pos + len + 1

                with {:cont, state} <- emit(:characters, chars, state, {original, pos - 1}) do
                  element_content_rest(rest, more?, original, pos, state)
                end

              ?& ->
                chars = binary_part(original, pos, len)
                element_content_reference(rest, more?, original, pos + len + 1, state, chars)

              _ ->
                chardata(rest, more?, original, pos, state, "", len + 1)
            end

          token in unquote(utf8_binaries()) when more? ->
            halt!(chardata_whitespace(token, more?, original, pos, state, len))

          <<codepoint::utf8>> <> rest ->
            chardata(rest, more?, original, pos, state, "", len + Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            halt!(chardata_whitespace("", more?, original, pos, state, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :chardata})
        end
      end

      defp chardata(<<buffer::bits>>, more?, original, pos, state, acc, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii(char) ->
            case char do
              ?< ->
                chars = IO.iodata_to_binary([acc | binary_part(original, pos, len)])
                pos = pos + len + 1

                with {:cont, state} <- emit(:characters, chars, state, {original, pos - 1}) do
                  element_content_rest(rest, more?, original, pos, state)
                end

              ?& ->
                chars = binary_part(original, pos, len)

                element_content_reference(rest, more?, original, pos + len + 1, state, [acc | chars])

              _ ->
                chardata(rest, more?, original, pos, state, acc, len + 1)
            end

          token in unquote(utf8_binaries()) when more? ->
            halt!(chardata(token, more?, original, pos, state, acc, len))

          <<codepoint::utf8>> <> rest ->
            chardata(rest, more?, original, pos, state, acc, len + Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            %{character_data_max_length: max_length} = state

            if max_length != :infinity and len >= max_length do
              chars = IO.iodata_to_binary([acc | binary_part(original, pos, len)])
              pos = pos + len

              with {:cont, state} <- emit(:characters, chars, state, {original, pos}) do
                {original, pos} = maybe_trim(true, original, pos)
                chardata(<<>>, true, original, pos, state, <<>>, 0)
              end
            else
              halt!(chardata("", more?, original, pos, state, acc, len))
            end

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :chardata})
        end
      end

      defp element_content_reference(<<buffer::bits>>, more?, original, pos, state, acc) do
        lookahead buffer, @streaming do
          token in ["", "#"] when more? ->
            halt!(element_content_reference(token, more?, original, pos, state, acc))

          char <> rest when is_ascii_name_start_char(char) ->
            element_entity_ref(rest, more?, original, pos, state, acc, 1)

          <<codepoint::utf8>> <> rest when is_ascii_name_start_char(codepoint) ->
            element_entity_ref(rest, more?, original, pos, state, acc, Utils.compute_char_len(codepoint))

          "#x" <> rest ->
            element_char_hex_ref(rest, more?, original, pos + 2, state, acc, 0)

          "#" <> rest ->
            element_char_dec_ref(rest, more?, original, pos + 1, state, acc, 0)

          _ ->
            Utils.parse_error(original, pos, state, {:token, :reference})
        end
      end

      defp element_entity_ref(<<buffer::bits>>, more?, original, pos, state, acc, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_char(char) ->
            element_entity_ref(rest, more?, original, pos, state, acc, len + 1)

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            element_entity_ref(rest, more?, original, pos, state, acc, len + Utils.compute_char_len(codepoint))

          ";" <> rest ->
            name = binary_part(original, pos, len)
            char = Emitter.convert_entity_reference(name, state)
            chardata(rest, more?, original, pos + len + 1, state, [acc | char], 0)

          _ in [""] when more? ->
            halt!(element_entity_ref("", more?, original, pos, state, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :entity_ref})
        end
      end

      defp element_char_dec_ref(<<buffer::bits>>, more?, original, pos, state, acc, len) do
        lookahead buffer, @streaming do
          ";" <> rest ->
            if len == 0 do
              Utils.parse_error(original, pos, state, {:token, :char_ref})
            else
              char = original |> binary_part(pos, len) |> String.to_integer(10)

              chardata(rest, more?, original, pos + len + 1, state, [acc | <<char::utf8>>], 0)
            end

          char <> rest when char in ?0..?9 ->
            element_char_dec_ref(rest, more?, original, pos, state, acc, len + 1)

          _ in [""] when more? ->
            halt!(element_char_dec_ref("", more?, original, pos, state, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :char_ref})
        end
      end

      defp element_char_hex_ref(<<buffer::bits>>, more?, original, pos, state, acc, len) do
        lookahead buffer, @streaming do
          ";" <> rest ->
            if len == 0 do
              Utils.parse_error(original, pos, state, [])
            else
              char = original |> binary_part(pos, len) |> String.to_integer(16)

              chardata(rest, more?, original, pos + len + 1, state, [acc | <<char::utf8>>], 0)
            end

          char <> rest when char in ?0..?9 or char in ?A..?F or char in ?a..?f ->
            element_char_hex_ref(rest, more?, original, pos, state, acc, len + 1)

          _ in [""] when more? ->
            halt!(element_char_hex_ref("", more?, original, pos, state, acc, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :char_ref})
        end
      end

      defp element_processing_instruction(<<buffer::bits>>, more?, original, pos, state, 0) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            element_processing_instruction(rest, more?, original, pos, state, 1)

          token in unquote(utf8_binaries() ++ [""]) when more? ->
            halt!(element_processing_instruction(token, more?, original, pos, state, 0))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            element_processing_instruction(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :processing_instruction})
        end
      end

      defp element_processing_instruction(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_char(char) ->
            element_processing_instruction(rest, more?, original, pos, state, len + 1)

          token in unquote(["" | utf8_binaries()]) when more? ->
            halt!(element_processing_instruction(token, more?, original, pos, state, len))

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            element_processing_instruction(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            pi_name = binary_part(original, pos, len)

            if Utils.valid_pi_name?(pi_name) do
              element_processing_instruction_content(buffer, more?, original, pos + len, state, pi_name, 0)
            else
              Utils.parse_error(original, pos, state, {:invalid_pi, pi_name})
            end
        end
      end

      defp element_processing_instruction_content(<<buffer::bits>>, more?, original, pos, state, name, len) do
        lookahead buffer, @streaming do
          "?>" <> rest ->
            element_content(rest, more?, original, pos + len + 2, state)

          token in ["", "?"] when more? ->
            halt!(element_processing_instruction_content(token, more?, original, pos, state, name, len))

          char <> rest when is_ascii(char) ->
            element_processing_instruction_content(rest, more?, original, pos, state, name, len + 1)

          token in unquote(["" | utf8_binaries()]) when more? ->
            halt!(element_processing_instruction_content(token, more?, original, pos, state, name, len))

          <<codepoint::utf8>> <> rest ->
            element_processing_instruction_content(
              rest,
              more?,
              original,
              pos,
              state,
              name,
              len + Utils.compute_char_len(codepoint)
            )

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :processing_instruction})
        end
      end

      defp element_content_comment(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          "-->" <> rest ->
            element_content(rest, more?, original, pos + len + 3, state)

          token in unquote(edge_ngrams("---")) when more? ->
            halt!(element_content_comment(token, more?, original, pos, state, len))

          "--->" <> _rest ->
            Utils.parse_error(original, pos + len, state, {:token, :comment})

          char <> rest when is_ascii(char) ->
            element_content_comment(rest, more?, original, pos, state, len + 1)

          <<codepoint::utf8>> <> rest ->
            element_content_comment(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :comment})
        end
      end

      defp close_tag_name(<<buffer::bits>>, more?, original, pos, state, 0) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            close_tag_name(rest, more?, original, pos, state, 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(close_tag_name(token, more?, original, pos, state, 0))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            close_tag_name(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            halt!(close_tag_name("", more?, original, pos, state, 0))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :end_tag})
        end
      end

      defp close_tag_name(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          ">" <> rest ->
            [open_tag | stack] = state.stack
            ending_tag = binary_part(original, pos, len)
            pos = pos + len + 1

            if open_tag == ending_tag do
              with {:cont, state} <- emit(:end_element, ending_tag, state, {original, pos}) do
                state = %{state | stack: stack}

                case stack do
                  [] ->
                    element_misc(rest, more?, original, pos, state)

                  [_parent | _stack] ->
                    {original, pos} = maybe_trim(more?, original, pos)
                    element_content(rest, more?, original, pos, state)
                end
              end
            else
              Utils.parse_error(original, pos, state, {:wrong_closing_tag, open_tag, ending_tag})
            end

          char <> rest when is_ascii_name_char(char) ->
            close_tag_name(rest, more?, original, pos, state, len + 1)

          token in unquote(utf8_binaries()) when more? ->
            halt!(close_tag_name(token, more?, original, pos, state, len))

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            close_tag_name(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ in [""] when more? ->
            halt!(close_tag_name("", more?, original, pos, state, len))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :end_tag})
        end
      end

      defp element_misc(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          "" ->
            if more? do
              halt!(element_misc("", more?, original, pos, state))
            else
              with {:cont, state} <- emit(:end_document, {}, state, {original, pos}) do
                {:ok, state}
              end
            end

          whitespace <> rest when is_whitespace(whitespace) ->
            element_misc(rest, more?, original, pos + 1, state)

          "<" <> rest ->
            element_misc_rest(rest, more?, original, pos + 1, state)

          _ ->
            Utils.parse_error(original, pos, state, {:token, :misc})
        end
      end

      defp element_misc_rest(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          _ in [""] when more? ->
            halt!(element_misc_rest("", more?, original, pos, state))

          "!" <> rest ->
            element_misc_comment(rest, more?, original, pos + 1, state)

          "?" <> rest ->
            element_misc_pi(rest, more?, original, pos + 1, state)

          _ ->
            Utils.parse_error(original, pos, state, {:token, :misc})
        end
      end

      defp element_misc_comment(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          token in ["", "-"] when more? ->
            halt!(element_misc_comment(token, more?, original, pos, state))

          "--" <> rest ->
            element_misc_comment_char(rest, more?, original, pos + 2, state, 0)

          _ ->
            Utils.parse_error(original, pos, state, {:token, :--})
        end
      end

      defp element_misc_comment_char(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          token in unquote(edge_ngrams("---")) when more? ->
            halt!(element_misc_comment_char(token, more?, original, pos, state, len))

          "--->" <> _ ->
            Utils.parse_error(original, pos + len, state, {:token, :comment})

          "-->" <> rest ->
            element_misc(rest, more?, original, pos + len + 3, state)

          char <> rest when is_ascii(char) ->
            element_misc_comment_char(rest, more?, original, pos, state, len + 1)

          <<codepoint::utf8>> <> rest ->
            element_misc_comment_char(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :"-->"})
        end
      end

      defp element_misc_pi(<<buffer::bits>>, more?, original, pos, state) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_start_char(char) ->
            element_misc_pi_name(rest, more?, original, pos, state, 1)

          token in unquote(["" | utf8_binaries()]) when more? ->
            halt!(element_misc_pi(token, more?, original, pos, state))

          <<codepoint::utf8>> <> rest when is_utf8_name_start_char(codepoint) ->
            element_misc_pi_name(rest, more?, original, pos, state, Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos, state, {:token, :processing_instruction})
        end
      end

      defp element_misc_pi_name(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          char <> rest when is_ascii_name_char(char) ->
            element_misc_pi_name(rest, more?, original, pos, state, len + 1)

          token in unquote(["" | utf8_binaries()]) when more? ->
            halt!(element_misc_pi_name(token, more?, original, pos, state, len))

          <<codepoint::utf8>> <> rest when is_utf8_name_char(codepoint) ->
            element_misc_pi_name(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            name = binary_part(original, pos, len)

            if Utils.valid_pi_name?(name) do
              element_misc_pi_content(buffer, more?, original, pos + len, state, 0)
            else
              Utils.parse_error(original, pos, state, {:invalid_pi, name})
            end
        end
      end

      defp element_misc_pi_content(<<buffer::bits>>, more?, original, pos, state, len) do
        lookahead buffer, @streaming do
          token in ["", "?"] when more? ->
            halt!(element_misc_pi_content(token, more?, original, pos, state, len))

          "?>" <> rest ->
            element_misc(rest, more?, original, pos + len + 2, state)

          char <> rest when is_ascii(char) ->
            element_misc_pi_content(rest, more?, original, pos, state, len + 1)

          <<codepoint::utf8>> <> rest ->
            element_misc_pi_content(rest, more?, original, pos, state, len + Utils.compute_char_len(codepoint))

          _ ->
            Utils.parse_error(original, pos + len, state, {:token, :processing_instruction})
        end
      end

      @compile {:inline, [maybe_trim: 3]}

      if @streaming do
        defp maybe_trim(true, binary, pos) do
          binary_size = byte_size(binary)

          {binary_part(binary, pos, binary_size - pos), 0}
        end

        defp maybe_trim(_more?, binary, pos) do
          {binary, pos}
        end
      else
        defp maybe_trim(_, binary, pos), do: {binary, pos}
      end
    end
  end
end
