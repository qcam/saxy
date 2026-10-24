defmodule Bench.MixProject do
  use Mix.Project

  def project() do
    [
      app: :bench,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: true,
      deps: deps()
    ]
  end

  def application(), do: [extra_applications: [:xmerl]]

  defp deps() do
    [
      {:benchee, "~> 1.0"},
      {:saxy, path: ".."},
      {:erlsom, ">= 0.0.0"},
      {:exomler, github: "erlangbureau/exomler"},
      {:xml_builder, "~> 2.1"}
    ]
  end
end
