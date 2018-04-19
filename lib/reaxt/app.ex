defmodule Reaxt.App do
  @moduledoc """
  Reaxt application entry point
  """
  use Application

  @doc false
  def start(_type, _args) do
    result = Supervisor.start_link(Reaxt.Sup,[], name: Reaxt.Sup)
    _ = WebPack.Util.build_stats()
    result
  end
end
