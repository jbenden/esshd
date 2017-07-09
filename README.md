# Sshd

A very simple way to add SSHd capabilities to a Mix application.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `esshd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:esshd, "~> 0.1.0"}]
end
```

After adding `esshd` as a dependency, ensure it is started before your own
application in `mix.exs`:

```elixir
def application do
  [extra_applications: [:esshd]]
end
```

## Usage

Create your own module that implements the behaviour `Sshd.GenSshd` and ensure
it is registered before your own application starts, by way of your applications
configuration inside `config/config.exs`:

```elixir
config :esshd, handler: "MyApplication.GenSshd"
```
