defmodule Sshd.AccessList do
  @moduledoc """
  This module provides a means to permit incoming SSH connections based on
  the remote IP address and TCP port.
  """

  @type ip_address :: :inet.ip_address()
  @type port_number :: :inet.port_number()
  @type peer_address :: {ip_address, port_number}

  defmacro __using__(_) do
    quote do
      @behaviour Sshd.AccessList

      @type ip_address :: :inet.ip_address()
      @type port_number :: :inet.port_number()
      @type peer_address :: {ip_address, port_number}

      def permit?(peer_address), do: true

      defoverridable [
        {:permit?, 1}
      ]
    end
  end

  @doc """
  Returns a boolean which should determine if the remote IP and TCP port,
  `peer_address`, is permitted to connect to the SSH server.
  """
  @callback permit?(peer_address) :: boolean
end

defmodule Sshd.AccessList.Default do
  @moduledoc """
  Default implementation of `Sshd.AccessList`, that permits every
  remote IP address.
  """
  use Sshd.AccessList
end
