defmodule Saxy.MixProject do
  use Mix.Project

  @version "1.1.0"

  def project() do
    [
      app: :saxy,
      version: @version,
      elixir: "~> 1.6",
      consolidate_protocols: Mix.env() != :test,
      description: description(),
      deps: deps(),
      package: package(),
      name: "Saxy",
      docs: docs(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application(), do: []

  defp description() do
    "Saxy is an XML parser and encoder in Elixir that focuses on speed and standard compliance."
  end

  defp package() do
    [
      maintainers: ["Cẩm Huỳnh"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/qcam/saxy"}
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:stream_data, "~> 0.4.2", only: :test},
      {:credo, "~>1.2", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12.3", only: :test, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp docs() do
    [
      main: "Saxy",
      extras: [
        "guides/getting-started-with-sax.md"
      ],
      source_ref: "v#{@version}",
      source_url: "https://github.com/qcam/saxy"
    ]
  end
end
