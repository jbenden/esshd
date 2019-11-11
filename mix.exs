defmodule Sshd.Mixfile do
  use Mix.Project

  @version "0.1.1"

  def project do
    [app: :esshd,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     description: "A simple way to add SSH server capabilities to your Elixir or Erlang application",
     name: "esshd",
     source_url: "https://github.com/jbenden/esshd",
     docs: docs(),
     dialyzer: [
        plt_add_deps: :apps_direct,
        flags: [:unmatched_returns, :error_handling, :race_conditions, :no_opaque]
     ],
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test, "coveralls.json": :test],
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :public_key, :ssh],
     mod: {Sshd.Application, []},
     env: [
       enabled: true,
       parallel_login: false,
       max_sessions: 50,
       idle_time: 86_400_000 * 3,
       negotiation_timeout: 11_000,
       preferred_algorithms: nil,
       password_authenticator: "Sshd.PasswordAuthenticator.Default",
       access_list: "Sshd.AccessList.Default",
       public_key_authenticator: "Sshd.PublicKeyAuthenticator.Default",
       subsystems: [],
     ]]
  end

  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:cortex, "~> 0.1", only: [:dev, :test]},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.4", only: [:dev, :test], runtime: false},
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
