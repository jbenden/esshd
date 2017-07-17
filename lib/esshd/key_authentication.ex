defmodule Sshd.KeyAuthentication do
  @moduledoc false

  @behaviour :ssh_server_key_api

  alias Sshd.Sessions
  require Record

  Record.defrecord :RSAPublicKey,  Record.extract(:RSAPublicKey, from_lib: "public_key/include/public_key.hrl")
  Record.defrecord :RSAPrivateKey, Record.extract(:RSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  Record.defrecord :DSAPrivateKey, Record.extract(:DSAPrivateKey, from_lib: "public_key/include/public_key.hrl")
  Record.defrecord :'Dss-Parms',   Record.extract(:'Dss-Parms', from_lib: "public_key/include/public_key.hrl")

  @type public_key :: :public_key.public_key()
  @type private_key :: map | map | term
  @type public_key_algorithm :: :'ssh-rsa'| :'ssh-dss' | atom
  @type user :: charlist()
  @type daemon_options :: Keyword.t

  require Logger

  @spec host_key(public_key_algorithm, daemon_options) ::
    {:ok, private_key} | {:error, any}
  def host_key(algorithm, daemon_options) do
    file = file_name(:system, file_base_name(algorithm), daemon_options)
    password =
      case Keyword.fetch(daemon_options, identity_pass_phrase(algorithm)) do
        {:ok, value} -> value
        :error -> nil
      end
    decode(file, password)
  end

  @spec is_auth_key(binary, user, daemon_options) :: boolean
  def is_auth_key(key, user, daemon_options) do
    public_key_module =
      Application.fetch_env!(:esshd, :public_key_authenticator)

    case apply(Module.concat([public_key_module]),
               :authenticate, [user, key, daemon_options]) do
      false -> false
      true  ->
        Sessions.set_public_key(self(), key)
        true
    end
  end

  defp file_base_name(:"ssh-rsa"), do: "ssh_host_rsa_key"
  defp file_base_name(:"rsa-sha2-256"), do: "ssh_host_rsa_key"
  defp file_base_name(:"rsa-sha2-384"), do: "ssh_host_rsa_key"
  defp file_base_name(:"rsa-sha2-512"), do: "ssh_host_rsa_key"
  defp file_base_name(:"ssh-dss"), do: "ssh_host_dsa_key"
  defp file_base_name(:"ecdsa-sha2-nistp256"), do: "ssh_host_ecdsa_key"
  defp file_base_name(:"ecdsa-sha2-nistp384"), do: "ssh_host_ecdsa_key"
  defp file_base_name(:"ecdsa-sha2-nistp521"), do: "ssh_host_ecdsa_key"
  defp file_base_name(_), do: "ssh_host_key"

  defp identity_pass_phrase("ssh-dss"), do: :dsa_pass_phrase
  defp identity_pass_phrase("ssh-rsa"), do: :rsa_pass_phrase
  defp identity_pass_phrase("rsa-sha2-256"), do: :rsa_pass_phrase
  defp identity_pass_phrase("rsa-sha2-384"), do: :rsa_pass_phrase
  defp identity_pass_phrase("rsa-sha2-512"), do: :rsa_pass_phrase
  defp identity_pass_phrase("ecdsa-sha2-" <> _), do: :ecdsa_pass_phrase
  defp identity_pass_phrase(p) when is_atom(p),
    do: identity_pass_phrase(Atom.to_string(p))

  defp decode(file, password) do
    {:ok, decode_ssh_file(read_ssh_file(file), password)}
  rescue
      e -> {:error, e.message()}
  end

  defp read_ssh_file(file) do
    {:ok, bin} = File.read(file)
    bin
  end

  @spec decode_ssh_file(binary, atom) :: binary
  # Public Key
  defp decode_ssh_file(ssh_bin, :public_key),
    do: :public_key.ssh_decode(ssh_bin, :public_key)
  # Private Key
  defp decode_ssh_file(pem, password) do
    case :public_key.pem_decode(pem) do
      [{_, _, :not_encrypted} = entry] ->
        :public_key.pem_entry_decode(entry)
      [entry] when password != :ignore ->
        :public_key.pem_entry_decode(entry, password)
      _ ->
        throw "No pass phrase provided for private key file"
    end
  end

  # server uses this to find individual keys for an individual user when
  # they try to log in with a public key
  @spec ssh_dir(:user | :system | {:remoteuser, user}, Keyword.t) :: String.t
  def ssh_dir({:remoteuser, user}, opts) do
    case Keyword.fetch(opts, :user_dir_fun) do
      :error ->
        case Keyword.fetch(opts, :user_dir) do
          {:ok, dir} -> dir
          :error -> default_user_dir()
        end
      {:ok, fun} -> apply(fun, [user])
    end
  end

  # client uses this to find client ssh keys
  #def ssh_dir(:user, opts) do
  #  case Keyword.fetch(opts, :user_dir) do
  #    {:ok, dir} -> dir
  #    :error     -> default_user_dir()
  #  end
  #end

  # server uses this to find server host keys
  def ssh_dir(:system, opts) do
    case Keyword.fetch(opts, :system_dir) do
      {:ok, dir} -> dir
      :error     -> "/etc/ssh"
    end
  end

  defp file_name(type, name, opts) do
    Path.join(ssh_dir(type, opts), name)
  end

  @perm700 0700

  @spec default_user_dir() :: binary
  def default_user_dir do
    {:ok, [[home|_]]} = :init.get_argument(:home)
    user_dir = Path.join(home, ".ssh")
    :ok = :filelib.ensure_dir(Path.join(user_dir, "dummy"))
    :ok = :file.change_mode(user_dir, @perm700)
    user_dir
  end
end
