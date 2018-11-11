defmodule Saxy.Xmerl.Records do
  @moduledoc false

  require Record

  Record.defrecord(:xmlAttribute, Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl"))
  Record.defrecord(:xmlNamespace, Record.extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl"))
  Record.defrecord(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))
  Record.defrecord(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))
end
