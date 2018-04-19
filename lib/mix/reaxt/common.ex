defmodule Mix.Reaxt.Common do
  @moduledoc """
  Commons for mix tasks
  """

  @doc false
  def env, do: Nox.Env.new(shared: true)

  @doc false
  def init_nox do
    Application.load(:nox)
    :application.set_env(:nox, :shared_dir, System.tmp_dir!())
    
    env = env()
    :ok = Nox.Make.all(env)
    env
  end
end
