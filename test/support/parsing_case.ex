defmodule SaxyTest.ParsingCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnitProperties

      import SaxyTest.Utils
    end
  end
end
