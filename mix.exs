defmodule Sshd.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :esshd,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     description: "A simple way to add SSHd capabilities to your Elixir application",
     name: "Sshd",
     docs: docs(),
     dialyzer: [
        plt_add_deps: :apps_direct,
        flags: [:unmatched_returns, :error_handling, :race_conditions, :no_opaque]
     ]]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Sshd.Application, []},
     env: [
       enabled: true,
       port: 10_022,
       handler: "Sshd.Simple"
     ]]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:cortex, "~> 0.1", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.14", only: [:dev], runtime: false},
    ]
  end

  defp docs do
    [source_ref: "v#{@version}",
     source_url: "https://github.com/jbenden/esshd",
     extras: ["README.md", "CHANGELOG.md"]]
  end

  defp package do
    [maintainers: ["Joseph Benden"],
     licenses: ["Apache-2.0"],
     links: %{github: "https://github.com/jbenden/esshd"},
     files: ~w(lib config) ++ ~w(README.md CHANGELOG.md LICENSE mix.exs)]
  end
end
