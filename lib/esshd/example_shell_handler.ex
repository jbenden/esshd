defmodule Sshd.ShellHandler.Example do
  @moduledoc """
  An example implementation of `Sshd.ShellHandler`, implementing a very simple
  Read-Eval-Loop, that does nothing.
  """
  use Sshd.ShellHandler

  def on_shell(_username, _pubkey, _ip, _port) do
    :ok = IO.puts "Interactive example SSH shell - type exit ENTER to quit"
    loop(run_state([]))
  end

  def on_connect(username, ip, port, method) do
    Logger.debug fn ->
      """
      Incoming SSH shell #{inspect self()} requested for #{username} from #{inspect ip}:#{inspect port} using #{inspect method}
      """
    end
  end

  def on_disconnect(username, ip, port) do
    Logger.debug fn ->
      "Disconnecting SSH shell for #{username} from #{inspect ip}:#{inspect port}"
    end
  end

  defp loop(state) do
    self_pid = self()
    counter  = state.counter
    prefix   = state.prefix

    input = spawn(fn -> io_get(self_pid, prefix, counter) end)
    wait_input state, input
  end

  defp wait_input(state, input) do
    receive do
      {:input, ^input, "exit\n"} ->
        IO.puts "Exiting..."

      {:input, ^input, code} when is_binary(code) ->
        code = String.trim(code)

        IO.puts "Received shell command: #{inspect code}"

        loop(%{state | counter: state.counter + 1})

      {:error, :interrupted} ->
        IO.puts "Caught Ctrl+C..."
        loop(%{state | counter: state.counter + 1})

      {:input, ^input, msg} ->
        :ok = Logger.warn "received unknown message: #{inspect msg}"
        loop(%{state | counter: state.counter + 1})
    end
  end

  defp run_state(opts) do
    prefix = Keyword.get(opts, :prefix, "shell")

    %{prefix: prefix, counter: 1}
  end

  defp io_get(pid, prefix, counter) do
    prompt = prompt(prefix, counter)
    send pid, {:input, self(), IO.gets(:stdio, prompt)}
  end

  defp prompt(prefix, counter) do
    prompt = "%prefix(%node)%counter>"
      |> String.replace("%counter", to_string(counter))
      |> String.replace("%prefix", to_string(prefix))
      |> String.replace("%node", to_string(node()))

    prompt <> " "
  end
end
