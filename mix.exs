defmodule Saxy.MixProject do
  use Mix.Project

  @source_url "https://github.com/qcam/saxy"
  @version "1.4.0"

  def project() do
    [
      app: :saxy,
      version: @version,
      elixir: "~> 1.6",
      name: "Saxy",
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application(), do: []

  defp package() do
    [
      description:
        "Saxy is an XML parser and encoder in Elixir that focuses on speed " <>
          "and standard compliance.",
      maintainers: ["Cẩm Huỳnh"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/saxy/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:stream_data, "~> 0.5", only: [:dev, :test]}
    ]
  end

  defp docs() do
    [
      extras: [
        "CHANGELOG.md",
        {:"LICENSE.md", [title: "License"]},
        "README.md",
        "guides/getting-started-with-sax.md"
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      assets: "assets",
      formatters: ["html"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
