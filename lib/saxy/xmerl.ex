defmodule Saxy.Xmerl do
  @moduledoc """
  Provides functions to parse a XML document to
  [xmerl format](https://github.com/erlang/otp/blob/master/lib/xmerl/include/xmerl.hrl)
  data structure.

  See "Types" section for more information.
  """

  import Saxy.Xmerl.Records

  @type position() :: integer()

  @type name() :: atom()

  @type expanded_name() :: charlist()

  @type content() :: [text() | element()]

  @type parent() :: {name(), position()}

  @type namespace_info() :: {charlist(), charlist()}

  @type value() :: [iolist() | atom() | integer()]

  @type language() :: charlist()

  @type namespace() ::
          record(:xmlNamespace,
            default: [],
            nodes: []
          )

  @type text() ::
          record(:xmlText,
            value: value(),
            pos: position(),
            parents: [parent()],
            language: language()
          )

  @type attribute() ::
          record(:xmlAttribute,
            name: name(),
            expanded_name: expanded_name(),
            nsinfo: namespace_info(),
            namespace: namespace(),
            pos: position(),
            value: value(),
            normalized: boolean()
          )

  @type element() ::
          record(:xmlElement,
            name: name(),
            expanded_name: expanded_name(),
            nsinfo: namespace_info(),
            namespace: namespace(),
            attributes: [attribute()],
            pos: position(),
            content: [content()],
            parents: [parent()]
          )

  @doc """
  Parses XML document into Erlang [xmerl](http://erlang.org/doc/man/xmerl.html) format.

  Xmerl format requires tag and attribute names to be atoms. By default Saxy uses
  `String.to_existing_atom/1` to avoid creating atoms at runtime. You could override
  this behaviour by specifying `:atom_fun` option to `String.to_atom/1`.

  Warning: However, `String.to_atom/1` function creates atoms dynamically and atoms are not
  garbage-collected. Therefore, you should not use this if the input XML cannot be trusted,
  such as input received from a socket or during a web request.

  ## Examples

      iex> string = File.read!("./test/support/fixture/foo.xml")
      iex> Saxy.Xmerl.parse_string(string)
      {:ok,
       {:xmlElement,
        :foo,
        :foo,
        [],
        {:xmlNamespace, [], []},
        [],
        1,
        [{:xmlAttribute, :bar, :bar, [], [], [], 1, [], 'value', :undefined}],
        [],
        [],
        [],
        :undeclared}}

  ## Options

  * `:atom_fun` - The function to convert string to atom. Defaults to `String.to_existing_atom/1`.
  * `:expand_entity` - specifies how external entity references should be handled. Three supported strategies respectively are:
    * `:keep` - keep the original binary, for example `Orange &reg;` will be expanded to `"Orange &reg;"`, this is the default strategy.
    * `:skip` - skip the original binary, for example `Orange &reg;` will be expanded to `"Orange "`.
    * `{mod, fun, args}` - take the applied result of the specified MFA.

  """

  @spec parse_string(data :: binary()) :: {:ok, element()} | {:error, Saxy.ParseError.t()}
  def parse_string(data, options \\ []) do
    {atom_fun, options} = Keyword.pop(options, :atom_fun, &String.to_existing_atom/1)
    state = %Saxy.Xmerl.State{atom_fun: atom_fun}

    case Saxy.parse_string(data, __MODULE__.Handler, state, options) do
      {:ok, %{stack: [document]}} ->
        {:ok, document}

      {:error, _reason} = error ->
        error
    end
  end
end
