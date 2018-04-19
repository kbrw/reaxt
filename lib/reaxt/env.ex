defmodule Reaxt.Env do
  @moduledoc """
  Store Nox env for reaxt
  """

  @doc false
  def start_link do
    Agent.start_link(fn -> Nox.Env.default() end, name: __MODULE__)
  end

  @doc """
  Get Nox env
  """
  @spec get() :: Nox.Env.t
  def get, do: Agent.get(__MODULE__, &(&1))
end
