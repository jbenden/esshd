# SPDX-License-Identifier: Apache-2.0
defmodule Sshd.ShellHandler do
  @moduledoc """
  As incoming SSH connections are accepted, authorized, and request remote
  shell services; they are passed to the `c:Sshd.ShellHandler.on_shell/4`
  callback.
  """

  @type username :: String.t()
  @type ssh_publickey :: binary
  @type ip_address :: :inet.ip_address()
  @type port_number :: :inet.port_number()
  @type peer_address :: {ip_address, port_number}
  @type method :: String.t()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Sshd.ShellHandler

      require Logger

      @type username :: String.t()
      @type ssh_publickey :: binary
      @type ip_address :: :inet.ip_address()
      @type port_number :: :inet.port_number()
      @type peer_address :: {ip_address, port_number}
      @type method :: String.t()

      @before_compile Sshd.ShellHandler
    end
  end

  @doc """
  User function callback to handle incoming shell requests.
  """
  @callback on_shell(
              username,
              ssh_publickey,
              ip_address,
              port_number
            ) :: :ok | {:error, any}

  @doc """
  User function callback to perform any tasks prior to launching a
  shell session.
  """
  @callback on_connect(
              username,
              ip_address,
              port_number,
              method
            ) :: :ok | {:error, any}

  @doc """
  User function callback to perform any tasks after a shell session. Will
  always be called, regardless of disconnect reason.
  """
  @callback on_disconnect(
              username,
              ip_address,
              port_number
            ) :: :ok | {:error, any}

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec incoming(
              username,
              ssh_publickey,
              ip_address,
              port_number
            ) :: :ok | {:error, any}
      def incoming(username, ssh_publickey, ip_address, port_number) do
        group_leader = Process.group_leader()

        _ = :io.setopts(group_leader, binary: true, encoding: :unicode)

        # :ok = on_connect username, ip_address, port_number
        try do
          :ok = on_shell(username, ssh_publickey, ip_address, port_number)
        rescue
          _ ->
            _ = Logger.warning("Exception caught")
            :ok
        end

        :ok = on_disconnect(username, ip_address, port_number)
      rescue
        _ ->
          :ok = Logger.info("io.setopts failed")
          {:error, ":io.setopts failed"}
      end
    end
  end
end
