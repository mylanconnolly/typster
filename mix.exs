defmodule Typster.MixProject do
  use Mix.Project

  @version "0.3.1"

  def project do
    [
      app: :typster,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Typster",
      description: "Elixir wrapper for Typst document preparation system",
      source_url: "https://github.com/mylanconnolly/typster",
      homepage_url: "https://github.com/mylanconnolly/typster",
      docs: docs(),
      package: package()
    ]
  end

  defp docs do
    [
      main: "Typster",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      groups_for_modules: [
        "Core API": [Typster],
        Exceptions: [Typster.CompileError],
        "Native Interface": [Typster.Native]
      ]
    ]
  end

  defp package do
    [
      name: "typster",
      files: ~w(lib native .formatter.exs mix.exs CHANGELOG.md README.md LICENSE checksum-*.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mylanconnolly/typster"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:rustler, "~> 0.37.1", optional: true},
      {:rustler_precompiled, "~> 0.8"},
      {:jason, "~> 1.0"},
      {:stream_data, "~> 1.1", only: [:test, :dev]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false}
    ]
  end
end
