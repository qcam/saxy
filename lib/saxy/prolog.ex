defmodule Saxy.Prolog do
  defstruct [
    :version,
    :encoding,
    :standalone
  ]

  @type t() :: %__MODULE__{
          version: String.t(),
          encoding: atom() | String.t(),
          standalone: boolean()
        }

  def from_keyword(prolog) do
    version = Keyword.get(prolog, :version, "1.0")
    encoding = Keyword.get(prolog, :encoding)
    standalone = Keyword.get(prolog, :standalone)

    %__MODULE__{
      version: version,
      encoding: encoding,
      standalone: standalone
    }
  end
end
