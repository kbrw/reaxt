defmodule Mix.Reaxt.Common do
  @moduledoc """
  Commons for mix tasks
  """
  require Logger

  @doc false
  def env, do: Nox.Env.new(shared: true)

  @doc false
  def init_nox do
    env = env()
    :ok = Nox.Make.all(env)
    env
  end
end
