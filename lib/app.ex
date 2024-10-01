defmodule Reaxt.App do
  use Application
  require Logger

  def start(_,_) do
    hot_reload_processes = if Reaxt.Utils.is_hot?() do
      hot_processes(Reaxt.Utils.bundler)
    else
      []
    end

    base_processes = [
      Reaxt.PoolsSup
    ]

    children = Enum.concat(base_processes, hot_reload_processes)

    result = Supervisor.start_link(children, name: __MODULE__, strategy: :one_for_one)
    if Reaxt.Utils.is_webpack?(), do: Reaxt.Index.Generator.build_webpack_stats()

    result
  end

  def hot_processes(:webpack) do
    [
      WebPack.Hot.Events,
      WebPack.Hot.EventManager,
      WebPack.Hot.Compiler,
    ]
  end

  def hot_processes(_) do
    raise "[Reaxt] Hot reload is not supported for bundle #{inspect Reaxt.Utils.bundler()}"
  end
end
