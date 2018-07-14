defmodule Saxy.MixProject do
  use Mix.Project

  @version "0.7.0"

  def project() do
    [
      app: :saxy,
      version: @version,
      elixir: "~> 1.3",
      consolidate_protocols: Mix.env() != :test,
      description: description(),
      deps: deps(),
      package: package(),
      name: "Saxy",
      docs: docs()
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
      {:stream_data, "~> 0.4.2", only: :test}
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
