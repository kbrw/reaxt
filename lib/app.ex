defmodule Reaxt.App do
  use Application

  def start(_,_) do
    hot_reload_processes = [
      # WebPack.Events,
      # WebPack.EventManager,
      # WebPack.Compiler,
    ]

    base_processes = [
      Reaxt.PoolsSup
    ]

    children = if Application.get_env(:reaxt, :hot, false) do
      Enum.concat(base_processes, hot_reload_processes)
    else
      base_processes
    end

    result = Supervisor.start_link(children, name: __MODULE__, strategy: :one_for_one)
    # WebPack.Util.build_stats()

    result
  end
end
