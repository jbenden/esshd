use Mix.Config

config :logger,
    level: :debug

app_dir = File.cwd!()
priv_dir = Path.join([app_dir, "test", "priv"])

config :esshd,
  enabled: true,
  handler: "Sshd.ShellHandler.Example",
  port: 10_222,
  priv_dir: priv_dir,
  password_authenticator: "Sshd.PasswordAuthenticator.Test"
