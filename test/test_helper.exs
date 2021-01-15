ExUnit.start()

defmodule SSHClient do
  @moduledoc """
  A very simple SSH client, which operates on a login shell of the remote host.

  Portions of the code were liberated from the [`sshex`](https://github.com/rubencaro/sshex) project.
  """

  def connect(opts) do
    opts =
      opts
      |> convert_values
      |> defaults(port: 22, negotiation_timeout: 5000, silently_accept_hosts: true)

    own_keys = [:ip, :port, :negotiation_timeout, :prompt]

    ssh_opts = opts |> Enum.filter(fn {k, _} -> not (k in own_keys) end)

    {:ok, conn} = :ssh.connect(opts[:ip], opts[:port], ssh_opts, opts[:negotiation_timeout])
    {:ok, chan_id} = :ssh_connection.session_channel(conn, :infinity)
    :ok = :ssh_connection.shell(conn, chan_id)

    {:ok, conn, chan_id}
  end

  def expect(conn, chan_id, opts) do
    get_response(conn, chan_id, 5_000, "", "", nil, false, prompt: opts)
  end

  def send(conn, chan_id, string) do
    case :ssh_connection.send(conn, chan_id, string) do
      :ok -> :ok
      {:error, :closed} -> :ok
    end
  end

  # Loop until all data is received. Return read data and the exit_status.
  #
  defp get_response(conn, channel, timeout, stdout, stderr, status, closed, opts) do
    # if we got status and closed, then we are done
    parsed =
      case {status, closed} do
        {st, true} when not is_nil(st) ->
          format_response({:ok, stdout, stderr, status}, opts)

        _ ->
          receive_and_parse_response(
            conn,
            channel,
            opts[:prompt],
            timeout,
            stdout,
            stderr,
            status,
            closed
          )
      end

    # tail recursion
    case parsed do
      # loop again, still things missing
      {:loop, {ch, tout, out, err, st, cl}} ->
        get_response(conn, ch, tout, out, err, st, cl, opts)

      x ->
        x
    end
  end

  # Parse ugly response
  # credo:disable-for-next-line
  defp receive_and_parse_response(
         conn,
         chn,
         prompt,
         tout,
         stdout,
         stderr,
         status,
         closed
       ) do
    response =
      receive do
        {:ssh_cm, _, res} -> res
      after
        tout -> {:error, "Timeout. Did not receive data for #{tout}ms."}
      end

    # call adjust_window to allow more data income, but only when needed
    case response do
      {:data, ^chn, _, new_data} ->
        :ssh_connection.adjust_window(conn, chn, byte_size(new_data))

      _ ->
        :ok
    end

    case response do
      {:data, ^chn, 1, new_data} ->
        {:loop, {chn, tout, stdout, stderr <> new_data, status, closed}}

      {:data, ^chn, 0, new_data} ->
        if String.match?(new_data, prompt) do
          {:loop, {chn, tout, stdout, stderr, 0, true}}
        else
          {:loop, {chn, tout, stdout <> new_data, stderr, status, closed}}
        end

      {:eof, ^chn} ->
        {:loop, {chn, tout, stdout, stderr, status, closed}}

      {:exit_signal, ^chn, _, _} ->
        {:loop, {chn, tout, stdout, stderr, status, closed}}

      {:exit_status, ^chn, new_status} ->
        {:loop, {chn, tout, stdout, stderr, new_status, closed}}

      {:closed, ^chn} ->
        {:loop, {chn, tout, stdout, stderr, 0, true}}

      # {:error, reason}
      any ->
        any
    end
  end

  # Format response for given raw response and given options
  #
  defp format_response(raw, opts) do
    case opts[:separate_streams] do
      true ->
        raw

      _ ->
        {:ok, stdout, stderr, status} = raw
        {:ok, stdout <> stderr, status}
    end
  end

  defp defaults(args, defs) do
    defs |> Keyword.merge(args)
  end

  defp convert_values(args) do
    Enum.map(args, fn {k, v} -> {k, convert_value(v)} end)
  end

  defp convert_value(v) when is_binary(v) do
    String.to_charlist(v)
  end

  defp convert_value(v), do: v
end
