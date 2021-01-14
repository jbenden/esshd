defmodule Sshd.Server do
  @moduledoc """
  The module that encompasses the SSH socket acceptor and
  its dispatch.
  """

  use GenServer
  require Logger
  alias Sshd.Sessions

  @doc false
  def start_link(_args) do
    enabled = Application.fetch_env!(:esshd, :enabled)

    GenServer.start_link(__MODULE__,
      %{pid: nil, enabled: enabled}, name: __MODULE__)
  end

  @doc false
  def init(%{enabled: true} = state) do
    # start listening for incoming SSH connections
    GenServer.cast self(), :start

    {:ok, state}
  end

  @doc false
  @spec init(map()) :: {:ok, map()}
  def init(%{enabled: false} = state) do
    # we're not enabled so return a dummy response
    {:ok, state}
  end

  @doc false
  @spec handle_info(map | any, map) :: {:noreply, map}
  def handle_info(_, state), do: {:noreply, state}

  @doc false
  def handle_cast(:start, state) do
    # Gather settings from the application configuration
    port                 = Application.fetch_env!(:esshd, :port)
    priv_dir             = Application.fetch_env!(:esshd, :priv_dir)
      # credo:disable-for-next-line
      |> String.to_charlist
    parallel_login       = Application.fetch_env!(:esshd, :parallel_login)
    max_sessions         = Application.fetch_env!(:esshd, :max_sessions)
    idle_time            = Application.fetch_env!(:esshd, :idle_time)
    negotiation_timeout  =
      Application.fetch_env!(:esshd, :negotiation_timeout)
    preferred_algorithms =
      Application.fetch_env!(:esshd, :preferred_algorithms)
        || :ssh.default_algorithms()
    subsystems = Application.fetch_env!(:esshd, :subsystems)

    case :ssh.daemon port, shell: &on_shell/2,
                           subsystems: subsystems,
                           system_dir: priv_dir,
                           user_dir: priv_dir,
                           user_passwords: [],
                           parallel_login: parallel_login,
                           max_sessions: max_sessions,
                           id_string: :random,
                           idle_time: idle_time,
                           negotiation_timeout: negotiation_timeout,
                           preferred_algorithms: preferred_algorithms,
                           failfun: &on_shell_unauthorized/3,
                           connectfun: &on_shell_connect/3,
                           disconnectfun: &on_shell_disconnect/1,
                           key_cb: Sshd.KeyAuthentication,
                           pwdfun: &on_password/4 do
      {:ok, pid} ->
        # link the created SSH daemon to ourself
        Process.link pid

        # Return, with state, and sleep
        {:noreply, %{state | pid: pid}, :hibernate}

      {:error, :eaddrinuse} ->
        :ok = Logger.error "Unable to bind to local TCP port; the address is already in use"
        #raise RuntimeError, "TCP port #{port} is in use"
        {:noreply, state, :hibernate}

      {:error, err} ->
        raise "Unhandled error encountered: #{inspect err}"
    end
  end

  @type ip_address :: :inet.ip_address()
  @type port_number :: :inet.port_number()
  @type peer_address :: {ip_address, port_number}

  @doc false
  @spec on_password(
    username :: charlist,
    password :: charlist,
    peer_address :: peer_address,
    state :: any
  ) :: :disconnect | {boolean, map}
  def on_password(username, password, peer_address, state) do
    :ok = Logger.debug fn ->
      "Checking #{inspect username} with password #{inspect password} from #{inspect peer_address}"
    end

    # credo:disable-for-next-line
    stateN =
      case state do
        :undefined -> %{attempts: 1}
        _ -> state
      end

    # check the incoming network details via AccessList
    accesslist_module = Application.fetch_env!(:esshd, :access_list)
    case apply(Module.concat([accesslist_module]), :permit?, [peer_address]) do
      false -> :disconnect
      true  -> valid_password_for_user?(peer_address,
                                        username,
                                        password,
                                        stateN)
    end
  end

  @spec valid_password_for_user?(
    peer_address :: peer_address,
    username :: charlist,
    password :: charlist,
    state :: map
    ) :: :disconnect | boolean | {boolean, any}
  defp valid_password_for_user?(peer_address, username, password, state) do
    password_module = Application.fetch_env!(:esshd, :password_authenticator)
    if apply(Module.concat([password_module]),
             :authenticate, [username, password]) do
      {true, state}
    else
      # drop the connection AFTER N password attempts
      if state.attempts >= 2 do
        :ok = Logger.warn "ATTEMPT TO ACCESS FAILED for #{inspect username} from #{inspect peer_address}"
        :disconnect
      else
        {false, %{state | attempts: state.attempts + 1}}
      end
    end
  end

  @doc false
  @spec on_shell_connect(String.t, peer_address, String.t) :: any
  def on_shell_connect(username, {ip, port} = peer_address, method) do
    handler_module = Application.fetch_env!(:esshd, :handler)

    Sessions.set_username(self(), username)
    Sessions.set_peer_address(self(), peer_address)

    spawn(Module.concat([handler_module]),
          :on_connect,
          [username, ip, port, method])
    :ok
  end

  @doc false
  @spec on_shell_unauthorized(String.t, peer_address, term) :: any
  def on_shell_unauthorized(username, {ip, port}, reason) do
    Logger.warn """
    Authentication failure for #{inspect username} from #{inspect ip}:#{inspect port}: #{inspect reason}
    """
  end

  @doc false
  @spec on_shell_disconnect(any) :: :ok
  def on_shell_disconnect(_) do
    Sessions.delete(self())
  end

  @doc false
  @spec on_shell(String.t, peer_address) :: pid
  def on_shell(username, {ip, port} = peer_address) do
    # we now have a completely connected client SSH connection, so
    # start a background Task to deal with the connection, and
    # disconnect it from ourselves; for proper supervisor tree.
    {_controlling_pid, session} = Sessions.get_by_peer_address(peer_address)
    ssh_publickey = Map.get(session, "public_key")

    ##
    # Create a new Process and wire-up everything, then dispatch
    ##
    handler_module = Application.fetch_env!(:esshd, :handler)

    spawn_link(Module.concat([handler_module]),
               :incoming,
               [username, ssh_publickey, ip, port])
  end
end
