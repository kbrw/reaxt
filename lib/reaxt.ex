defmodule ReaxtError do
  defexception [:message,:js_render,:js_stack]
  def exception({:handler_error,error,stack}) do
    %ReaxtError{message: "JS Exception : #{error}", js_stack: (stack && parse_stack(stack))}
  end
  def exception({:render_error,error,stack,js_render}) do
    %ReaxtError{message: "JS Exception : #{error}", js_render: js_render, js_stack: (stack && parse_stack(stack))}
  end
  defp parse_stack(stack) do
    Regex.scan(~r/at (.*) \((.*):([0-9]*):[0-9]*\)/,stack)
    |> Enum.map(fn [_,function,url,line]->
      if String.contains?(url,"/priv") and !(function in ["Port.next_term","Socket.read_term"]) do
        {line,_} = Integer.parse(line)
        [_,after_priv] = String.split(url,"/priv/",parts: 2)
        {JS,:"#{function}",0,file: '#{WebPack.Util.web_priv}/#{after_priv}', line: line}
      end
    end)
    |> Enum.filter(&!is_nil(&1))
  end
end
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
        try do raise(ReaxtError,err)
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
    Supervisor.terminate_child(Reaxt.App.Sup,:react)
    Supervisor.restart_child(Reaxt.App.Sup,:react)
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

  defmodule App do
    use Application
    def start(_,_) do
      result = Supervisor.start_link(App.Sup,[], name: App.Sup)
      WebPack.Util.build_stats
      result
    end
    defmodule Sup do
      use Supervisor
      def init([]) do
        dev_workers = if Application.get_env(:reaxt,:hot),
          do: [worker(WebPack.Compiler,[]),
               worker(WebPack.EventManager,[])], else: []
        supervise([Supervisor.Spec.supervisor(__MODULE__,[],function: :start_pools,id: :react)
          |dev_workers], strategy: :one_for_one)
      end

      def start_pools do
        pool_size = Application.get_env(:reaxt,:pool_size)
        pool_overflow = Application.get_env(:reaxt,:pool_max_overflow)
        server_dir = "#{WebPack.Util.web_priv}/#{Application.get_env(:reaxt,:server_dir)}"
        server_files = Path.wildcard("#{server_dir}/*.js")
        if server_files == [] do
          Logger.error("#server JS not yet compiled in #{server_dir}, compile it before with `mix webpack.compile`")
          throw {:error,:serverjs_not_compiled}
        else
          Supervisor.start_link(
            for server<-server_files do
              pool = :"react_#{server |> Path.basename(".js") |> String.replace(~r/[0-9][a-z][A-Z]/,"_")}_pool"
              Pool.child_spec(pool,[worker_module: Reaxt,size: pool_size, max_overflow: pool_overflow, name: {:local,pool}], server)
            end, strategy: :one_for_one)
        end
      end
    end
  end
end
