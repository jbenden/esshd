defmodule Sshd.Sessions do
  @moduledoc false

  @type ip_address :: :inet.ip_address()
  @type port_number :: :inet.port_number()
  @type peer_address :: {ip_address, port_number}

  def start_link do
    Agent.start_link(fn -> Map.new end, name: __MODULE__)
  end

  @spec set_public_key(pid, binary) :: :ok
  def set_public_key(pid, pubkey) do
    session =
      pid
      |> find_session
      |> Map.put("public_key", pubkey)

    Agent.update(__MODULE__, &Map.put(&1, pid, session))
  end

  @spec set_username(pid, String.t) :: :ok
  def set_username(pid, username) do
    session =
      pid
      |> find_session
      |> Map.put("username", username)

    Agent.update(__MODULE__, &Map.put(&1, pid, session))
  end

  @spec set_peer_address(pid, peer_address) :: :ok
  def set_peer_address(pid, peer_address) do
    session =
      pid
      |> find_session
      |> Map.put("peer_address", peer_address)

    Agent.update(__MODULE__, &Map.put(&1, pid, session))
  end

  @spec get_by_peer_address(peer_address) :: {pid, map}
  def get_by_peer_address(peer_address) do
    Agent.get(__MODULE__, fn sessions ->
      Enum.find(sessions, fn {_key, element} ->
        peer_address === Map.fetch!(element, "peer_address")
      end)
    end)
  end

  @spec delete(pid) :: :ok
  def delete(pid) do
    Agent.update(__MODULE__, &Map.delete(&1, pid))
  end

  @spec find_session(pid) :: map
  defp find_session(pid) do
    Agent.get(__MODULE__, &Map.get(&1, pid)) || Map.new
  end
end
