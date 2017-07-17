defmodule Sshd.PublicKeyAuthenticator do
  @moduledoc """
  This module helps with Public Key authentication.
  """

  @type username :: charlist()
  @type public_key :: binary()
  @type opts :: Keyword.t

  defmacro __using__(_) do
    quote do
      @behaviour Sshd.PublicKeyAuthenticator

      @type username :: charlist()
      @type public_key :: binary()
      @type opts :: Map.t

      def authenticate(username, public_key, opts), do: false

      defoverridable [
        {:authenticate, 3}
      ]
    end
  end

  @doc """
  Returns a boolean that determines if the `username` user, presenting the
  `public_key` OpenSSH public key, is authorized to connect to the SSH
  server.
  """
  @callback authenticate(username, public_key, opts) :: boolean
end

defmodule Sshd.PublicKeyAuthenticator.Default do
  @moduledoc """
  Default implementation of Public Key authentication.
  """
  use Sshd.PublicKeyAuthenticator
end

defmodule Sshd.PublicKeyAuthenticator.AuthorizedKeys do
  @moduledoc """
  Implementation of `Sshd.PublicKeyAuthenticator` which uses the
  `authorized_keys` file contained in the `HOME` directory of the user
  attempting to enter the SSH server.
  """
  use Sshd.PublicKeyAuthenticator
  import Sshd.KeyAuthentication, only: [ssh_dir: 2]
  require Logger

  def authenticate(username, public_key, opts) do
    :ok = Logger.info "authenticate under #{inspect self()}"

    case lookup_user_key(public_key, username, opts) do
      {:ok, _public_key} ->
        true
      _ ->
        false
    end
  end

  @spec lookup_user_key(
    key :: binary,
    user :: charlist,
    opts :: Keyword.t
  ) :: {:ok, binary} | {:error, any}

  defp lookup_user_key(key, user, opts) do
    ssh_dir = ssh_dir({:remoteuser, user}, opts)
    case lookup_user_key_f(key, user, ssh_dir, "authorized_keys", opts) do
      {:ok, key} ->
        {:ok, key}
      _ ->
        lookup_user_key_f(key, user, ssh_dir, "authorized_keys2", opts)
    end
  end

  @spec lookup_user_key_f(
    key :: binary,
    user :: charlist,
    dir :: binary,
    f :: binary,
    opts :: Keyword.t
  ) :: {:ok, binary} | {:error, any}

  defp lookup_user_key_f(key, _user, dir, f, _opts) do
    filename = Path.join(dir, f)
    case File.open(filename, [:read, :binary]) do
      {:ok, fd} ->
        res = lookup_user_key_fd(fd, key)
        :ok = File.close fd
        res
      {:error, reason} ->
        {:error, {{:openerr, reason}, {:file, filename}}}
    end
  end

  @spec lookup_user_key_fd(
    fd :: pid,
    key :: binary
  ) :: {:ok, binary} | {:error, :not_found}

  defp lookup_user_key_fd(fd, key) do
    case IO.binread(fd, :line) do
      :eof -> {:error, :not_found}
      line -> match_user_key_fd(fd, key, line)
    end
  end

  @spec match_user_key_fd(
    fd :: pid,
    key :: binary,
    line :: binary
  ) :: {:ok, binary} | {:error, :not_found}

  defp match_user_key_fd(fd, key, line) do
    case ssh_decode_line(line, :auth_keys) do
      [{authKey, _}] ->
        case is_auth_key(key, authKey) do
          true ->
            {:ok, key}
          false -> lookup_user_key_fd(fd, key)
        end
      [] -> lookup_user_key_fd(fd, key)
    end
  end

  @spec ssh_decode_line(
    line :: binary,
    type :: atom
  ) :: list

  defp ssh_decode_line(line, type) do
    :public_key.ssh_decode line, type
  rescue
    _ -> []
  end

  @spec is_auth_key(
    key1 :: any,
    key2 :: tuple
  ) :: boolean

  defp is_auth_key(key, key), do: true
  defp is_auth_key(_, _), do: false
end
