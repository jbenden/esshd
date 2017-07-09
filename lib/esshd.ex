defmodule Sshd do
  @moduledoc """
  Documentation for Sshd.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Sshd.hello
      :world

  """
  def hello do
    :world
  end

  @doc """
  Starts the `:esshd` Application.
  """
  @spec start() :: :ok | {:error, any}
  def start do
    Application.start(:esshd)
  end

  @doc """
  Stops the running `:esshd` Application.
  """
  @spec stop() :: :ok | {:error, any}
  def stop do
    Application.stop(:esshd)
  end
end
