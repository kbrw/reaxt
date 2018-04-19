defmodule Reaxt.Env do
  @moduledoc """
  Store Nox env for reaxt
  """

  @doc false
  def start_link do
    # Use the same env for build and run
    env = Mix.Reaxt.Common.env()
    :ok = Nox.Make.all(env)
    
    Agent.start_link(fn -> env end, name: __MODULE__)
  end

  @doc """
  Get Nox env
  """
  @spec get() :: Nox.Env.t
  def get, do: Agent.get(__MODULE__, &(&1))
end
