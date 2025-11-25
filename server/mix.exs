# SPDX-License-Identifier: MIT OR Apache-2.0
# Copyright (c) 2024 Laniakea Contributors

defmodule Laniakea.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/laniakea/laniakea"

  def project do
    [
      app: :laniakea,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description(),
      name: "Laniakea",
      source_url: @source_url,
      homepage_url: "https://laniakea.dev",
      dialyzer: dialyzer(),
      preferred_cli_env: preferred_cli_env(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {Laniakea.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},

      # Database (optional)
      {:ecto_sql, "~> 3.11", optional: true},
      {:postgrex, "~> 0.17", optional: true},

      # HTTP
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:cors_plug, "~> 3.0"},

      # Telemetry
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_exporter, "~> 1.6"},

      # Security
      {:plug_crypto, "~> 2.0"},

      # Development & Testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 0.6", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},

      # Benchmarking
      {:benchee, "~> 1.2", only: :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["cmd npm install --prefix ../client"],
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "rsr.check": ["run --no-start -e 'Laniakea.RSR.verify()'"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "../README.adoc",
        "../CHANGELOG.md",
        "../CONTRIBUTING.md",
        "../docs/wiki/Architecture.md",
        "../docs/wiki/CRDTs.md"
      ],
      groups_for_modules: [
        CRDTs: [
          Laniakea.CRDT,
          Laniakea.CRDT.GCounter,
          Laniakea.CRDT.PNCounter,
          Laniakea.CRDT.ORSet,
          Laniakea.CRDT.LWWRegister
        ],
        Transport: [
          Laniakea.Transport,
          Laniakea.Transport.Channel
        ],
        Policy: [
          Laniakea.Policy,
          Laniakea.Policy.Capabilities
        ]
      ]
    ]
  end

  defp package do
    [
      name: "laniakea",
      licenses: ["MIT", "Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp description do
    """
    Distributed state architecture for browser-as-peer web applications.
    CRDT-based state convergence with Phoenix Channels.
    """
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit],
      flags: [
        :error_handling,
        :underspecs,
        :unknown,
        :unmatched_returns
      ]
    ]
  end

  defp preferred_cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end
end
