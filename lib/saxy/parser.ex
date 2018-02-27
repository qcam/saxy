defmodule Saxy.Parser do
  @moduledoc false

  alias Saxy.{Buffering, Emitter}

  @maximum_unicode_character 0x10FFFF

  def match(buffer, position, :document, state) do
    with {:ok, {:prolog, prolog}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :prolog, state),
         new_state <- %{new_state | prolog: prolog},
         new_state <- Emitter.emit(:start_document, prolog, new_state),
         {:ok, {:element, _}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :element, new_state),
         {:ok, {:Misc, _}, {new_buffer, new_pos}, new_state} <-
           zero_or_more(new_buffer, new_pos, :Misc, new_state, []) do
      new_state = Emitter.emit(:end_document, {}, new_state)
      {:ok, {:document, {}}, {new_buffer, new_pos}, new_state}
    else
      match_error -> handle_match_error(match_error)
    end
  end

  def match(buffer, position, :prolog, state) do
    with {:ok, {:XMLDecl, xml}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(buffer, position, :XMLDecl, state, []),
         {:ok, {:Misc, _}, {new_buffer, new_pos}, new_state} <-
           zero_or_more(new_buffer, new_pos, :Misc, new_state, []) do
      {:ok, {:prolog, xml}, {new_buffer, new_pos}, new_state}
    else
      match_error -> handle_match_error(match_error)
    end
  end

  def match(buffer, position, :XMLDecl, state) do
    with {:ok, {:"<?xml", _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :"<?xml", state),
         {:ok, {:VersionInfo, version}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :VersionInfo, new_state),
         {:ok, {:EncodingDecl, encoding}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :EncodingDecl, new_state, "UTF-8"),
         {:ok, {:SDDecl, standalone?}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :SDDecl, new_state, false),
         {:ok, {:S, _tval}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :S, new_state),
         {:ok, {:"?>", _tval}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :"?>", new_state) do
      if valid_encoding?(encoding) do
        xml = [version: version, encoding: encoding, standalone: standalone?]
        {:ok, {:XMLDecl, xml}, {new_buffer, new_pos}, new_state}
      else
        throw({:error, {:unsupported_encoding, encoding}})
      end
    else
      {:error, :"<?xml", {new_buffer, new_pos}, new_state} ->
        {:error, :XMLDecl, {new_buffer, new_pos}, new_state}

      {:error, :VersionInfo, {new_buffer, new_pos}, _new_state} ->
        raise_bad_syntax(:XMLDecl, new_buffer, new_pos)

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :VersionInfo, state) do
    with {:ok, {:S, _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :S, state),
         {:ok, {:version, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :version, new_state),
         {:ok, {:Eq, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :Eq, new_state),
         {:ok, {:quote, open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state),
         {:ok, {:VersionNum, num}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :VersionNum, new_state),
         {:ok, {:quote, ^open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state) do
      {:ok, {:VersionInfo, num}, {new_buffer, new_pos}, new_state}
    else
      {:ok, {:quote, _wrong_quote}, {new_buffer, new_pos}, _new_state} ->
        raise_bad_syntax(:VersionInfo, new_buffer, new_pos)

      {:error, mismatched_token, {new_buffer, new_pos}, new_state} ->
        cond do
          mismatched_token in [:Eq, :quote, :VersionNum] ->
            raise_bad_syntax(:VersionInfo, new_buffer, new_pos)

          mismatched_token in [:S, :version] ->
            {:error, :VersionInfo, {new_buffer, new_pos}, new_state}
        end

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :VersionNum, state) do
    with {:ok, {:"1.", _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :"1.", state),
         {:ok, {:DecChar, chars}, {new_buffer, new_pos}, new_state} <-
           one_or_more(new_buffer, new_pos, :DecChar, new_state, <<>>) do
      {:ok, {:VersionNum, "1." <> chars}, {new_buffer, new_pos}, new_state}
    else
      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :EncodingDecl, state) do
    with {:ok, {:S, _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :S, state),
         {:ok, {:encoding, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :encoding, new_state),
         {:ok, {:Eq, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :Eq, new_state),
         {:ok, {:quote, open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state),
         {:ok, {:EncName, encoding}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :EncName, new_state),
         {:ok, {:quote, ^open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state) do
      {:ok, {:EncodingDecl, encoding}, {new_buffer, new_pos}, new_state}
    else
      {:error, :S, {new_buffer, _new_pos}, new_state} ->
        {:error, :EncodingDecl, {new_buffer, position}, new_state}

      {:error, :encoding, {new_buffer, _new_pos}, new_state} ->
        {:error, :EncodingDecl, {new_buffer, position}, new_state}

      {:error, _error, {new_buffer, new_pos}, _new_state} ->
        raise_bad_syntax(:EncodingDecl, new_buffer, new_pos)

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :EncName, state) do
    case match(buffer, position, :EncNameStartChar, state) do
      {:ok, {:EncNameStartChar, start_char}, {new_buffer, new_pos}, new_state} ->
        case zero_or_more(new_buffer, new_pos, :EncNameChar, new_state, <<>>) do
          {:ok, {:EncNameChar, chars}, {new_buffer, new_pos}, new_state} ->
            {:ok, {:EncName, start_char <> chars}, {new_buffer, new_pos}, new_state}
        end

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :SDDecl, state) do
    with {:ok, {:S, _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :S, state),
         {:ok, {:standalone, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :standalone, new_state),
         {:ok, {:Eq, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :Eq, new_state),
         {:ok, {:quote, open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state),
         {:ok, {:YesNo, standalone}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :YesNo, new_state),
         {:ok, {:quote, ^open_quote_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :quote, new_state) do
      case yes?(standalone) do
        :error ->
          raise_bad_syntax(:YesNo, buffer, position)

        {:ok, standalone?} ->
          {:ok, {:SDDecl, standalone?}, {new_buffer, new_pos}, new_state}
      end
    else
      {:error, :S, {new_buffer, _new_pos}, new_state} ->
        {:error, :SDDecl, {new_buffer, position}, new_state}

      {:error, :standalone, {new_buffer, _new_pos}, new_state} ->
        {:error, :SDDecl, {new_buffer, position}, new_state}

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :element, state) do
    with {:ok, {:<, _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :<, state),
         {:ok, {:Name, tag_name}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :Name, new_state),
         {:ok, {:SAttribute, attributes}, {new_buffer, new_pos}, new_state} <-
           zero_or_more(new_buffer, new_pos, :SAttribute, new_state, []),
         {:ok, {:S, _s_char}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :S, new_state) do
      case match(new_buffer, new_pos, :"/>", new_state) do
        {:ok, {:"/>", _tval}, {new_buffer, new_pos}, new_state} ->
          new_state = Emitter.emit(:start_element, {tag_name, attributes}, new_state)
          new_state = Emitter.emit(:end_element, {tag_name}, new_state)

          {:ok, {:element, {tag_name, attributes}}, {new_buffer, new_pos}, new_state}

        {:error, :"/>", {new_buffer, new_pos}, new_state} ->
          case match(new_buffer, new_pos, :>, new_state) do
            {:ok, {:>, _tval}, {new_buffer, new_pos}, new_state} ->
              new_state = Emitter.emit(:start_element, {tag_name, attributes}, new_state)

              case match(new_buffer, new_pos, :content, new_state) do
                {:ok, {:content, _content}, {new_buffer, new_pos}, new_state} ->
                  case match(new_buffer, new_pos, :ETag, new_state) do
                    {:ok, {:ETag, ^tag_name}, {new_buffer, new_pos}, new_state} ->
                      new_state = Emitter.emit(:end_element, {tag_name}, new_state)
                      {:ok, {:element, {tag_name, attributes}}, {new_buffer, new_pos}, new_state}

                    {:ok, {:ETag, mismatched_tag}, {_new_buffer, _new_pos}, _new_state} ->
                      throw({:error, {:wrong_closing_tag, {tag_name, mismatched_tag}}})
                  end
              end

            match_error ->
              handle_match_error(match_error)
          end
      end
    else
      {:error, :<, {new_buffer, new_pos}, new_state} ->
        {:error, :element, {new_buffer, new_pos}, new_state}

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :content, state) do
    case zero_or_one(buffer, position, :CharData, state) do
      {:ok, {:CharData, chars}, {new_buffer, new_pos}, new_state} ->
        new_state = Emitter.emit(:characters, chars, new_state)

        case zero_or_more(new_buffer, new_pos, :ContentComponent, new_state, []) do
          {:ok, {:ContentComponent, _}, {new_buffer, new_pos}, new_state} ->
            {:ok, {:content, []}, {new_buffer, new_pos}, new_state}

          {:error, :ContentComponent, {new_buffer, new_pos}, new_state} ->
            {:error, :content, {new_buffer, new_pos}, new_state}
        end
    end
  end

  def match(buffer, position, :CharData, state) do
    case zero_or_more(buffer, position, :CharDataChar, state, <<>>) do
      {:ok, {:CharDataChar, chars}, {new_buffer, new_pos}, new_state} ->
        {:ok, {:CharData, chars}, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :ContentComponent, state) do
    {:ok, buffer, position, next_cont} = Buffering.maybe_buffer(buffer, position, state.cont)
    state = %{state | cont: next_cont}

    {buffer, position} = Buffering.maybe_commit(buffer, position)

    Buffering.subbuffer(buffer, position)
    |> case do
      <<"<!--", _rest::bits>> ->
        match(buffer, position, :Comment, state)

      <<"<![CDATA[", _rest::bits>> ->
        match(buffer, position, :CDSect, state)

      <<"<?", _rest::bits>> ->
        match(buffer, position, :PI, state)

      <<"&", _rest::bits>> ->
        match(buffer, position, :Reference, state)

      <<"</", _rest::bits>> ->
        {:error, :ContentComponent, {buffer, position}, state}

      <<"<", _rest::bits>> ->
        match(buffer, position, :element, state)

      _other ->
        {:error, :ContentComponent, {buffer, position}, state}
    end
    |> case do
      {:ok, matched_rule, {new_buffer, new_pos}, new_state} ->
        new_state =
          case matched_rule do
            {:CDSect, cdata} ->
              Emitter.emit(:characters, cdata, new_state)

            {:Reference, ref} ->
              Emitter.emit(:characters, ref, new_state)

            _ ->
              new_state
          end

        case zero_or_one(new_buffer, new_pos, :CharData, new_state) do
          {:ok, {:CharData, chars}, {new_buffer, new_pos}, new_state} ->
            new_state = Emitter.emit(:characters, chars, new_state)

            {:ok, {:ContentComponent, []}, {new_buffer, new_pos}, new_state}
        end

      {:error, _, {new_buffer, _new_pos}, new_state} ->
        {:error, :ContentComponent, {new_buffer, position}, new_state}
    end
  end

  def match(buffer, position, :CDSect, state) do
    with {:ok, {:CDStart, _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :CDStart, state),
         {:ok, {:CData, cdata}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :CData, new_state),
         {:ok, {:CDEnd, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :CDEnd, new_state) do
      {:ok, {:CDSect, cdata}, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :CData, state) do
    case zero_or_more(buffer, position, :CDataChar, state, <<>>) do
      {:ok, {:CDataChar, chars}, {new_buffer, new_pos}, new_state} ->
        {:ok, {:CData, chars}, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :ETag, state) do
    with {:ok, {:"</", _tval}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :"</", state),
         {:ok, {:Name, tag_name}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :Name, new_state),
         {:ok, {:S, _s_char}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :S, new_state),
         {:ok, {:>, _tval}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :>, new_state) do
      {:ok, {:ETag, tag_name}, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :Name, state) do
    case match(buffer, position, :NameStartChar, state) do
      {:ok, {:NameStartChar, start_char}, {new_buffer, new_pos}, new_state} ->
        case zero_or_more(new_buffer, new_pos, :NameChar, new_state, <<>>) do
          {:ok, {:NameChar, name_chars}, {new_buffer, new_pos}, new_state} ->
            {:ok, {:Name, start_char <> name_chars}, {new_buffer, new_pos}, new_state}
        end

      {:error, :NameStartChar, {new_buffer, new_pos}, new_state} ->
        {:error, :Name, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :SAttribute, state) do
    case match(buffer, position, :S, state) do
      {:ok, {:S, _}, {new_buffer, s_pos}, new_state} ->
        case match(new_buffer, s_pos, :Attribute, new_state) do
          {:ok, {:Attribute, attribute}, {new_buffer, new_pos}, new_state} ->
            {:ok, {:SAttribute, attribute}, {new_buffer, new_pos}, new_state}

          {:error, :Attribute, {new_buffer, _new_pos}, new_state} ->
            {:error, :SAttribute, {new_buffer, s_pos}, new_state}
        end

      {:error, :S, {new_buffer, new_pos}, new_state} ->
        {:error, :SAttribute, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :Attribute, state) do
    case match(buffer, position, :Name, state) do
      {:ok, {:Name, name}, {new_buffer, new_pos}, new_state} ->
        case match(new_buffer, new_pos, :Eq, new_state) do
          {:ok, {:Eq, _}, {new_buffer, new_pos}, new_state} ->
            case match(new_buffer, new_pos, :AttValue, new_state) do
              {:ok, {:AttValue, att_val}, {new_buffer, new_pos}, new_state} ->
                {:ok, {:Attribute, {name, att_val}}, {new_buffer, new_pos}, new_state}

              {:error, :AttValue, {new_buffer, new_pos}, _new_state} ->
                raise_bad_syntax(:Attribute, new_buffer, new_pos)
            end
        end

      {:error, :Name, {new_buffer, new_pos}, new_state} ->
        {:error, :Attribute, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :AttValue, state) do
    case match(buffer, position, :quote, state) do
      {:ok, {:quote, open_quote}, {new_buffer, new_pos}, new_state} ->
        rule = {:AttValueComponent, open_quote}

        case zero_or_more(new_buffer, new_pos, rule, new_state, <<>>) do
          {:ok, {^rule, att_value}, {new_buffer, new_pos}, new_state} ->
            case match(new_buffer, new_pos, :quote, new_state) do
              {:ok, {:quote, ^open_quote}, {new_buffer, new_pos}, new_state} ->
                {:ok, {:AttValue, att_value}, {new_buffer, new_pos}, new_state}
            end
        end
    end
  end

  def match(buffer, position, {:AttValueComponent, quote_val}, state) do
    {:ok, buffer, position, next_cont} = Buffering.maybe_buffer(buffer, position, state.cont)
    state = %{state | cont: next_cont}

    case Buffering.subbuffer(buffer, position) do
      <<"&", _rest::bits>> ->
        case match(buffer, position, :Reference, state) do
          {:ok, {:Reference, ref}, {new_buffer, new_pos}, new_state} ->
            {:ok, {{:AttValueComponent, quote_val}, ref}, {new_buffer, new_pos}, new_state}
        end

      <<_any::bits>> ->
        case match(buffer, position, {:AttValueChar, quote_val}, state) do
          {:ok, {{:AttValueChar, _qval}, char}, {new_buffer, new_pos}, new_state} ->
            {:ok, {{:AttValueComponent, quote_val}, char}, {new_buffer, new_pos}, new_state}

          {:error, {:AttValueChar, _qval}, {new_buffer, new_pos}, new_state} ->
            {:error, {:AttValueComponent, quote_val}, {new_buffer, new_pos}, new_state}
        end
    end
  end

  def match(buffer, position, :Reference, state) do
    {:ok, buffer, position, next_cont} = Buffering.maybe_buffer(buffer, position, state.cont)
    state = %{state | cont: next_cont}

    buffer
    |> Buffering.subbuffer(position)
    |> match_reference(buffer, position, state)
    |> case do
      {:ok, {rule, ref_chars}, {new_buffer, new_pos}, new_state}
      when rule in [:DecChar, :HexChar, :Name] ->
        case convert_reference(rule, ref_chars) do
          {:ok, char} ->
            case match(new_buffer, new_pos, :";", new_state) do
              {:ok, {:";", _tval}, {new_buffer, new_pos}, new_state} ->
                {:ok, {:Reference, char}, {new_buffer, new_pos}, new_state}

              match_error ->
                handle_match_error(match_error)
            end

          :error ->
            {:error, :Reference, {new_buffer, new_pos}, new_state}
        end

      match_error ->
        handle_match_error(match_error)
    end
  end

  def match(buffer, position, :Misc, state) do
    case match(buffer, position, :Comment, state) do
      {:ok, {:Comment, _comment}, {new_buffer, new_pos}, new_state} ->
        {:ok, {:Misc, []}, {new_buffer, new_pos}, new_state}

      {:error, :Comment, {new_buffer, new_pos}, new_state} ->
        case match(new_buffer, new_pos, :PI, new_state) do
          {:ok, {:PI, _pi}, {new_buffer, new_pos}, new_state} ->
            {:ok, {:Misc, []}, {new_buffer, new_pos}, new_state}

          {:error, :PI, {new_buffer, new_pos}, new_state} ->
            case match(new_buffer, new_pos, :S, new_state) do
              {:ok, {:S, _s}, {new_buffer, new_pos}, new_state} ->
                {:ok, {:Misc, []}, {new_buffer, new_pos}, new_state}

              {:error, :S, {new_buffer, new_pos}, new_state} ->
                {:error, :Misc, {new_buffer, new_pos}, new_state}
            end
        end
    end
  end

  def match(buffer, position, :Comment, state) do
    with {:ok, {:"<!--", _token_val}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :"<!--", state),
         {:ok, {:CommentChar, chars}, {new_buffer, new_pos}, new_state} <-
           zero_or_more(new_buffer, new_pos, :CommentChar, new_state, <<>>),
         {:ok, {:"-->", _token_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :"-->", new_state) do
      {:ok, {:Comment, chars}, {new_buffer, new_pos}, new_state}
    else
      {:error, :"<!--", {new_buffer, new_pos}, new_state} ->
        {:error, :Comment, {new_buffer, new_pos}, new_state}

      {:error, _token_name, {new_buffer, new_pos}, _new_state} ->
        raise_bad_syntax(:Comment, new_buffer, new_pos)
    end
  end

  def match(buffer, position, :S, state) do
    case one_or_more(buffer, position, :whitespace, state, []) do
      {:ok, {:whitespace, whitespaces}, {new_buffer, new_pos}, state} ->
        {:ok, {:S, whitespaces}, {new_buffer, new_pos}, state}

      {:error, _, {new_buffer, new_pos}, new_state} ->
        {:error, :S, {new_buffer, new_pos}, new_state}
    end
  end

  def match(buffer, position, :PI, state) do
    with {:ok, {:"<?", _token_val}, {new_buffer, new_pos}, new_state} <-
           match(buffer, position, :"<?", state),
         {:ok, {:PITarget, pi_name}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :PITarget, new_state),
         {:ok, {:PIContent, chars}, {new_buffer, new_pos}, new_state} <-
           zero_or_one(new_buffer, new_pos, :PIContent, new_state, <<>>),
         {:ok, {:"?>", _token_val}, {new_buffer, new_pos}, new_state} <-
           match(new_buffer, new_pos, :"?>", new_state) do
      {:ok, {:PI, {pi_name, chars}}, {new_buffer, new_pos}, new_state}
    else
      {:error, :"<?", {new_buffer, new_pos}, new_state} ->
        {:error, :PI, {new_buffer, new_pos}, new_state}

      {:error, _token_name, {new_buffer, new_pos}, _new_state} ->
        raise_bad_syntax(:PI, new_buffer, new_pos)
    end
  end

  def match(buffer, position, :PITarget, state) do
    case match(buffer, position, :Name, state) do
      {:ok, {:Name, pi_name}, {new_buffer, new_pos}, new_state} ->
        if valid_pi_name?(pi_name) do
          {:ok, {:PITarget, pi_name}, {new_buffer, new_pos}, new_state}
        else
          raise_bad_syntax(:PITarget, buffer, position)
        end

      {:error, :Name, {_new_buffer, _new_pos}, _new_state} ->
        raise_bad_syntax(:PITarget, buffer, position)
    end
  end

  def match(buffer, position, :PIContent, state) do
    with {:ok, {:S, _}, {new_buffer, new_pos}, new_state} <- match(buffer, position, :S, state),
         {:ok, {:PIChar, chars}, {new_buffer, new_pos}, new_state} <-
           zero_or_more(new_buffer, new_pos, :PIChar, new_state, <<>>) do
      {:ok, {:PIContent, chars}, {new_buffer, new_pos}, new_state}
    else
      {:error, :S, {new_buffer, new_pos}, new_state} ->
        {:error, :PIContent, {new_buffer, new_pos}, new_state}
    end
  end

  @tokens [
    :"<?xml",
    :version,
    :encoding,
    :standalone,
    :YesNo,
    :"?>",
    :"<!--",
    :"-->",
    :<,
    :>,
    :"/>",
    :"</",
    :"&#",
    :"&#x",
    :&,
    :";",
    :"1.",
    :EncNameStartChar,
    :EncNameChar,
    :CommentChar,
    :whitespace,
    :NameStartChar,
    :NameChar,
    :Eq,
    :quote,
    :CharDataChar,
    :CDStart,
    :CDEnd,
    :CDataChar,
    :DecChar,
    :HexChar,
    :PIChar,
    :"<?"
  ]

  Enum.each(@tokens, fn token ->
    def match(buffer, position, unquote(token), state) do
      {:ok, buffer, position, next_cont} = Buffering.maybe_buffer(buffer, position, state.cont)
      state = %{state | cont: next_cont}

      case match_token(Buffering.subbuffer(buffer, position), unquote(token)) do
        {:ok, {tval, tlen}} ->
          {:ok, {unquote(token), tval}, {buffer, position + tlen}, state}

        :error ->
          {:error, unquote(token), {buffer, position}, state}
      end
    end
  end)

  def match(buffer, position, {:AttValueChar, quote_val}, state) do
    {:ok, buffer, position, next_cont} = Buffering.maybe_buffer(buffer, position, state.cont)
    state = %{state | cont: next_cont}

    case match_token(Buffering.subbuffer(buffer, position), {:AttValueChar, quote_val}) do
      {:ok, {tval, tlen}} ->
        {:ok, {{:AttValueChar, quote_val}, tval}, {buffer, position + tlen}, state}

      :error ->
        {:error, {:AttValueChar, quote_val}, {buffer, position}, state}
    end
  end

  def match(buffer, position, rule) do
    raise_bad_syntax(rule, buffer, position)
  end

  defp zero_or_one(buffer, position, rule, state, default \\ nil) do
    case match(buffer, position, rule, state) do
      {:ok, {^rule, value}, {new_buffer, new_pos}, new_state} ->
        {:ok, {rule, value}, {new_buffer, new_pos}, new_state}

      {:error, ^rule, {new_buffer, new_pos}, new_state} ->
        {:ok, {rule, default}, {new_buffer, new_pos}, new_state}
    end
  end

  defp one_or_more(buffer, position, rule, state, acc) do
    case zero_or_more(buffer, position, rule, state, acc) do
      {:ok, {^rule, acc}, {new_buffer, new_pos}, new_state} ->
        if acc_size(acc) > 0 do
          {:ok, {rule, acc}, {new_buffer, new_pos}, new_state}
        else
          {:error, rule, {new_buffer, new_pos}, new_state}
        end
    end
  end

  defp zero_or_more(buffer, position, rule, state, acc) do
    case match(buffer, position, rule, state) do
      {:ok, {^rule, value}, {new_buffer, current_pos}, new_state} ->
        zero_or_more(new_buffer, current_pos, rule, new_state, acc(acc, value))

      {:error, ^rule, {new_buffer, mismatch_pos}, new_state} ->
        {:ok, {rule, acc}, {new_buffer, mismatch_pos}, new_state}
    end
  end

  defp acc_size(acc) when is_list(acc), do: length(acc)
  defp acc_size(acc) when is_binary(acc), do: byte_size(acc)

  defp acc(acc, value) when is_list(acc), do: [value | acc]
  defp acc(acc, value) when is_binary(acc), do: acc <> value

  defp match_token(<<0xA, _rest::bits>>, :whitespace), do: {:ok, {<<0xA>>, 1}}
  defp match_token(<<0x9, _rest::bits>>, :whitespace), do: {:ok, {<<0x9>>, 1}}
  defp match_token(<<0xD, _rest::bits>>, :whitespace), do: {:ok, {<<0xD>>, 1}}
  defp match_token(<<0x20, _rest::bits>>, :whitespace), do: {:ok, {<<0x20>>, 1}}
  defp match_token(<<_::bits>>, :whitespace), do: :error

  defp match_token(<<"<", _rest::bits>>, :<), do: {:ok, {"<", 1}}
  defp match_token(<<_::bits>>, :<), do: :error

  defp match_token(<<">", _rest::bits>>, :>), do: {:ok, {">", 1}}
  defp match_token(<<_::bits>>, :>), do: :error

  defp match_token(<<"/>", _rest::bits>>, :"/>"), do: {:ok, {"/>", 2}}
  defp match_token(<<_::bits>>, :"/>"), do: :error

  defp match_token(<<"</", _rest::bits>>, :"</"), do: {:ok, {"</", 2}}
  defp match_token(<<_::bits>>, :"</"), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :NameStartChar) do
    if name_start_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<charcode::utf8, _rest::bits>>, :NameChar) do
    if name_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<?", _rest::bits>>, {:AttValueChar, "\""}), do: :error
  defp match_token(<<?', _rest::bits>>, {:AttValueChar, "'"}), do: :error
  defp match_token(<<?<, _rest::bits>>, {:AttValueChar, _}), do: :error
  defp match_token(<<?&, _rest::bits>>, {:AttValueChar, _}), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, {:AttValueChar, _}) do
    char = <<charcode::utf8>>
    {:ok, {char, byte_size(char)}}
  end

  defp match_token(<<?=, _rest::bits>>, :Eq), do: {:ok, {"=", 1}}
  defp match_token(<<_::bits>>, :Eq), do: :error

  defp match_token(<<_::bits>>, :NameChar), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :DecChar) when charcode in ?0..?9 do
    char = <<charcode::utf8>>
    {:ok, {char, byte_size(char)}}
  end

  defp match_token(<<_::bits>>, :DecChar), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :EncNameStartChar) do
    if enc_name_start_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<_::bits>>, :EncNameStartChar), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :EncNameChar) do
    if enc_name_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<_::bits>>, :EncNameChar), do: :error

  defp match_token(<<?", _rest::bits>>, :quote), do: {:ok, {"\"", 1}}
  defp match_token(<<?', _rest::bits>>, :quote), do: {:ok, {"'", 1}}
  defp match_token(<<_::bits>>, :quote), do: :error

  defp match_token(<<"]]>", _rest::bits>>, :CharDataChar) do
    :error
  end

  defp match_token(<<"<", _rest::bits>>, :CharDataChar) do
    :error
  end

  defp match_token(<<"&", _rest::bits>>, :CharDataChar) do
    :error
  end

  defp match_token(<<charcode::utf8, _rest::bits>>, :CharDataChar) do
    char = <<charcode::utf8>>
    {:ok, {char, byte_size(char)}}
  end

  defp match_token(<<"<![CDATA[", _rest::bits>>, :CDStart) do
    {:ok, {"<![CDATA[", 9}}
  end

  defp match_token(<<_::bits>>, :CDStart), do: :error

  defp match_token(<<"]]>", _rest::bits>>, :CDEnd) do
    {:ok, {"]]>", 3}}
  end

  defp match_token(<<_::bits>>, :CDEnd), do: :error

  defp match_token(<<"]]>", _rest::bits>>, :CDataChar), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :CDataChar) do
    if cdata_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<_::bits>>, :CDataChar), do: :error

  defp match_token(<<"<!--", _rest::bits>>, :"<!--"), do: {:ok, {"<!--", 4}}
  defp match_token(<<_::bits>>, :"<!--"), do: :error

  defp match_token(<<"-->", _rest::bits>>, :"-->"), do: {:ok, {"-->", 3}}
  defp match_token(<<_::bits>>, :"-->"), do: :error

  defp match_token(<<"-->", _rest::bits>>, :CommentChar), do: :error

  defp match_token(<<char::utf8, _rest::bits>>, :CommentChar),
    do: {:ok, {<<char::utf8>>, byte_size(<<char::utf8>>)}}

  defp match_token(<<?&, _rest::bits>>, :&), do: {:ok, {"&", 1}}
  defp match_token(<<_::bits>>, :&), do: :error

  defp match_token(<<?;, _rest::bits>>, :";"), do: {:ok, {";", 1}}
  defp match_token(<<_::bits>>, :";"), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :HexChar) do
    if hex_char?(charcode) do
      char = <<charcode::utf8>>
      {:ok, {char, byte_size(char)}}
    else
      :error
    end
  end

  defp match_token(<<_::bits>>, :HexChar), do: :error

  defp match_token(<<"<?xml", _rest::bits>>, :"<?xml"), do: {:ok, {"<?xml", 5}}
  defp match_token(<<_::bits>>, :"<?xml"), do: :error

  defp match_token(<<"encoding", _rest::bits>>, :encoding), do: {:ok, {"encoding", 8}}
  defp match_token(<<_::bits>>, :encoding), do: :error

  defp match_token(<<"standalone", _rest::bits>>, :standalone), do: {:ok, {"standalone", 10}}
  defp match_token(<<_::bits>>, :standalone), do: :error

  defp match_token(<<"yes", _rest::bits>>, :YesNo), do: {:ok, {"yes", 3}}
  defp match_token(<<"no", _rest::bits>>, :YesNo), do: {:ok, {"no", 2}}
  defp match_token(<<_::bits>>, :YesNo), do: :error

  defp match_token(<<"version", _rest::bits>>, :version), do: {:ok, {"version", 7}}
  defp match_token(<<_::bits>>, :version), do: :error

  defp match_token(<<"1.", _rest::bits>>, :"1."), do: {:ok, {"1.", 2}}
  defp match_token(<<_::bits>>, :"1."), do: :error

  defp match_token(<<"?>", _rest::bits>>, :"?>"), do: {:ok, {"?>", 2}}
  defp match_token(<<_::bits>>, :"?>"), do: :error

  defp match_token(<<"<?", _rest::bits>>, :"<?"), do: {:ok, {"<?", 2}}
  defp match_token(<<_::bits>>, :"<?"), do: :error

  defp match_token(<<"?>", _rest::bits>>, :PIChar), do: :error

  defp match_token(<<charcode::utf8, _rest::bits>>, :PIChar) do
    char = <<charcode::utf8>>
    {:ok, {char, byte_size(char)}}
  end

  defp match_token(_buffer, _token), do: :error

  defp match_reference(<<"&#x", _rest::bits>>, buffer, position, state) do
    one_or_more(buffer, position + 3, :HexChar, state, <<>>)
  end

  defp match_reference(<<"&#", _rest::bits>>, buffer, position, state) do
    one_or_more(buffer, position + 2, :DecChar, state, <<>>)
  end

  defp match_reference(<<"&", _rest::bits>>, buffer, position, state) do
    match(buffer, position + 1, :Name, state)
  end

  defp name_start_char?(charcode) do
    cond do
      charcode == ?: -> true
      charcode in ?A..?Z -> true
      charcode == ?_ -> true
      charcode in ?a..?z -> true
      charcode in 0xC0..0xD6 -> true
      charcode in 0xD8..0xF6 -> true
      charcode in 0xF8..0x2FF -> true
      charcode in 0x370..0x37D -> true
      charcode in 0x37F..0x1FFF -> true
      charcode in 0x200C..0x200D -> true
      charcode in 0x2070..0x218F -> true
      charcode in 0x2C00..0x2FEF -> true
      charcode in 0x3001..0xD7FF -> true
      charcode in 0xF900..0xFDCF -> true
      charcode in 0xFDF0..0xFFFD -> true
      charcode in 0x10000..0xEFFFF -> true
      true -> false
    end
  end

  defp name_char?(charcode) do
    cond do
      name_start_char?(charcode) -> true
      charcode == ?- -> true
      charcode == ?. -> true
      charcode in ?0..?9 -> true
      charcode == 0xB7 -> true
      charcode in 0x0300..0x036F -> true
      charcode in 0x203F..0x2040 -> true
      true -> false
    end
  end

  defp cdata_char?(charcode) do
    cond do
      charcode in [0x9, 0xA, 0xD] -> true
      charcode in 0x20..0xD7FF -> true
      charcode in 0xE000..0xFFFD -> true
      charcode in 0x10000..0x10FFFF -> true
      true -> false
    end
  end

  defp hex_char?(charcode) do
    cond do
      charcode in ?0..?9 -> true
      charcode in ?a..?f -> true
      charcode in ?A..?F -> true
      true -> false
    end
  end

  defp enc_name_start_char?(charcode) do
    cond do
      charcode in ?A..?Z -> true
      charcode in ?a..?z -> true
      true -> false
    end
  end

  defp enc_name_char?(charcode) do
    cond do
      enc_name_start_char?(charcode) -> true
      charcode in ?0..?9 -> true
      charcode == ?. -> true
      charcode == ?_ -> true
      charcode == ?- -> true
      true -> false
    end
  end

  defp yes?("yes"), do: {:ok, true}
  defp yes?("no"), do: {:ok, false}
  defp yes?(_other), do: :error

  defp valid_pi_name?(<<a::utf8, b::utf8, c::utf8>>) do
    cond do
      not (a in [?x, ?X]) -> true
      not (b in [?m, ?M]) -> true
      not (c in [?l, ?L]) -> true
      true -> false
    end
  end

  defp valid_pi_name?(<<_any::bits>>), do: true

  defp valid_encoding?("utf-8"), do: true
  defp valid_encoding?("UTF-8"), do: true
  defp valid_encoding?(_other), do: false

  defp convert_reference(:Name, name) do
    case Saxy.Entities.convert(name) do
      {:ok, character} -> {:ok, character}
      :error -> {:ok, "&#{name};"}
    end
  end

  defp convert_reference(:HexChar, hex) do
    case Integer.parse(hex, 16) do
      {charcode, <<>>} when charcode <= @maximum_unicode_character ->
        {:ok, <<charcode::utf8>>}

      _other ->
        :error
    end
  end

  defp convert_reference(:DecChar, dec) do
    case Integer.parse(dec) do
      {charcode, <<>>} when charcode <= @maximum_unicode_character ->
        {:ok, <<charcode::utf8>>}

      _other ->
        :error
    end
  end

  defp handle_match_error({:error, rule, {buffer, position}, _state}) do
    raise_bad_syntax(rule, buffer, position)
  end

  defp raise_bad_syntax(rule, buffer, pos) do
    throw({:error, {:bad_syntax, {rule, {buffer, pos}}}})
  end
end
