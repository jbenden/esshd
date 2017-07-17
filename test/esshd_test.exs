defmodule SshdTest do
  use ExUnit.Case, async: true
  doctest Sshd

  @ip '127.0.0.1'
  @port 65_432
  @user 'tests'
  @pass 'testpass'
  @prompt ~r/shell\(.*@.*\)\d+> /

  describe "when remotely connecting" do
    test "it correctly connects and disconnects with user and password" do
      {:ok, conn, chan_id} = SSHClient.connect ip: @ip, port: @port, user: @user, password: @pass
      {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

      SSHClient.send(conn, chan_id, "exit\n")

      {:ok, vals, _} = SSHClient.expect conn, chan_id, @prompt

      assert String.match?(vals, ~r/(*ANY)^Exiting...$/mu) == true, "#{vals} does not match regular expression."
    end

    test "it correctly connects and disconnects with public key" do
      user_dir = Application.fetch_env!(:esshd, :priv_dir) |> Path.join("tests")
      {:ok, conn, chan_id} = SSHClient.connect ip: @ip, port: @port, user: @user, password: "wrong", user_dir: user_dir
      {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

      SSHClient.send(conn, chan_id, "exit\n")

      {:ok, vals, _} = SSHClient.expect conn, chan_id, @prompt

      assert String.match?(vals, ~r/(*ANY)^Exiting...$/mu) == true, "#{vals} does not match regular expression."
    end

    test "it does nothing with an invalid command" do
      {:ok, conn, chan_id} = SSHClient.connect ip: @ip, port: @port, user: @user, password: @pass
      {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

      SSHClient.send(conn, chan_id, "dummy\n")
      {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

      SSHClient.send(conn, chan_id, "exit\n")

      {:ok, vals, _} = SSHClient.expect conn, chan_id, @prompt

      assert String.match?(vals, ~r/(*ANY)^Exiting...$/mu) == true, "#{vals} does not match regular expression."
    end

    test "it handles parallel connections" do
      tasks = Enum.map(1..5, fn(_) ->
        Task.async(fn ->
          {:ok, conn, chan_id} = SSHClient.connect ip: @ip, port: @port, user: @user, password: @pass
          {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

          SSHClient.send(conn, chan_id, "dummy\n")
          {:ok, _, _} = SSHClient.expect conn, chan_id, @prompt

          SSHClient.send(conn, chan_id, "exit\n")

          {:ok, vals, _} = SSHClient.expect conn, chan_id, @prompt

          assert String.match?(vals, ~r/(*ANY)^Exiting...$/mu) == true, "#{vals} does not match regular expression."
        end)
      end)

      tasks
      |> Enum.each(fn t ->
        t |> Task.await
      end)
    end
  end
end
