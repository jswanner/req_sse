defmodule ReqSSE.MixProject do
  use Mix.Project

  @source_url "https://github.com/jswanner/req_sse"
  @version "0.1.0"

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.8", only: :test},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false, warn_if_outdated: true},
      {:plug, "~> 1.18", only: :test},
      {:req, "~> 0.5.0"},
      {:req_test_bandit, "~> 0.1.0", only: :test}
    ]
  end

  def project do
    [
      app: :req_sse,
      deps: deps(),
      docs: [
        source_url: @source_url,
        source_ref: "v#{@version}",
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ],
      elixir: "~> 1.14",
      package: [
        description:
          "Req plugin for parsing text/event-stream messages (aka server-sent events).",
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source_url
        }
      ],
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs
      ],
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end
end
