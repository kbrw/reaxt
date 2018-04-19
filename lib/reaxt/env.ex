defmodule Reaxt.Env do
  @moduledoc """
  Store Nox env for reaxt
  """

  @doc false
  def start_link do
    env = Nox.Env.new(shared: true)
    :ok = Nox.Make.all(env)
    
    Agent.start_link(fn -> env end, name: __MODULE__)
  end

  @doc """
  Get Nox env
  """
  @spec get() :: Nox.Env.t
  def get, do: Agent.get(__MODULE__, &(&1))
end
