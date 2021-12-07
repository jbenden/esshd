# SPDX-License-Identifier: Apache-2.0
defmodule Sshd.KeyAuthentication do
  @moduledoc false

  @behaviour :ssh_server_key_api

  alias Sshd.Sessions
  require Record

  Record.defrecord(
    :RSAPublicKey,
    Record.extract(:RSAPublicKey, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :DSAPrivateKey,
    Record.extract(:DSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :"Dss-Parms",
    Record.extract(:"Dss-Parms", from_lib: "public_key/include/public_key.hrl")
  )

  @type public_key :: :public_key.public_key()
  @type private_key :: :public_key.private_key()
  @type public_key_algorithm :: :"ssh-rsa" | :"ssh-dss" | atom
  @type user :: charlist()
  @type daemon_options :: Keyword.t()

  require Logger

  @spec host_key(public_key_algorithm, daemon_options) ::
          {:ok, private_key} | {:error, any}
  def host_key(algorithm, daemon_options) do
    :ssh_file.host_key(algorithm, daemon_options)
  end

  @spec is_auth_key(term, user, daemon_options) :: boolean
  def is_auth_key(key, user, daemon_options) do
    public_key_module = Application.fetch_env!(:esshd, :public_key_authenticator)

    # credo:disable-for-next-line
    case apply(Module.concat([public_key_module]), :authenticate, [user, key, daemon_options]) do
      false ->
        false

      true ->
        Sessions.set_public_key(self(), key)
        true
    end
  end

  # server uses this to find individual keys for an individual user when
  # they try to log in with a public key
  @spec ssh_dir(:user | :system | {:remoteuser, user}, Keyword.t()) :: String.t()
  def ssh_dir({:remoteuser, user}, opts) do
    case Keyword.fetch(opts, :user_dir_fun) do
      :error ->
        case Keyword.fetch(opts, :user_dir) do
          {:ok, dir} -> dir
          :error -> default_user_dir()
        end

      {:ok, fun} ->
        # credo:disable-for-next-line
        apply(fun, [user])
    end
  end

  # server uses this to find server host keys
  def ssh_dir(:system, opts),
    do: Keyword.get(opts, :system_dir, "/etc/ssh")

  @perm700 0700

  @spec default_user_dir() :: binary
  def default_user_dir do
    {:ok, [[home | _]]} = :init.get_argument(:home)
    user_dir = Path.join(home, ".ssh")
    :ok = :filelib.ensure_dir(Path.join(user_dir, "dummy"))
    :ok = :file.change_mode(user_dir, @perm700)
    user_dir
  end
end
