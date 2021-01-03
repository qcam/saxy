defmodule Saxy.Parser do
  @moduledoc false

  defmodule Binary do
    @moduledoc false

    use Saxy.Parser.Builder, streaming?: false
  end

  defmodule Stream do
    @moduledoc false

    use Saxy.Parser.Builder, streaming?: true
  end
end
