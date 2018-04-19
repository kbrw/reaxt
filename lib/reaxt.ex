defmodule Reaxt do
  alias :poolboy, as: Pool
  require Logger

  def render_result(chunk,module,data,timeout) when not is_tuple(module), do:
    render_result(chunk,{module,nil},data,timeout)
  def render_result(chunk,{module,submodule},data,timeout) do
    Pool.transaction(:"react_#{chunk}_pool",fn worker->
      GenServer.call(worker,{:render,module,submodule,data,timeout},timeout+100)
    end)
  end

  def render!(module,data,timeout \\ 5_000, chunk \\ :server) do
    case render_result(chunk,module,data,timeout) do
      {:ok,res}->res
      {:error,err}->
        try do raise(Reaxt.Error,err)
        rescue ex->
          [_|stack] = System.stacktrace
          reraise ex, ((ex.js_stack || []) ++ stack)
        end
    end
  end

  def render(module,data, timeout \\ 5_000) do
    try do
      render!(module,data,timeout)
    rescue
      ex->
        case ex do
          %{js_render: js_render} when is_binary(js_render)->
            Logger.error(Exception.message(ex))
            %{css: "",html: "", js_render: js_render}
          _ ->
            reraise ex, System.stacktrace
        end
    end
  end

  def reload do
    WebPack.Util.build_stats
    Supervisor.terminate_child(Reaxt.Sup,:react)
    Supervisor.restart_child(Reaxt.Sup,:react)
  end

  def start_link(server_path) do
    env = Nox.Env.default()
    init = Poison.encode!(Application.get_env(:reaxt,:global_config,nil))
    opts = [
      cd: '#{WebPack.Util.web_priv}',
      env: Nox.sys_env(env) |> Enum.map(fn {name, val} -> {'#{name}', '#{val}'} end)
    ]
    exe = Nox.which(env, "node")
    Exos.Proc.start_link("#{exe} #{server_path}", init, opts)
  end
end
