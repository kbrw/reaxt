defmodule ReaxtError do
  defexception [:message,:args,:js_render,:js_stack]
  def exception({:handler_error,module,submodule,args,error,stack}) do
    params=%{
      module: module,
      submodule: submodule,
      args: args
    }
    %ReaxtError{message: "JS Handler Exception for #{inspect params}: #{error}", args: params, js_stack: (stack && parse_stack(stack))}
  end
  def exception({:render_error,params,error,stack,js_render}) do
    %ReaxtError{message: "JS Render Exception : #{error}", args: params, js_render: js_render, js_stack: (stack && parse_stack(stack))}
  end
  defp parse_stack(stack) do
    Regex.scan(~r/at (.*) \((.*):([0-9]*):[0-9]*\)/,stack)
    |> Enum.map(fn [_,function,url,line]->
      if String.contains?(url,"/priv") and !(function in ["Port.next_term","Socket.read_term"]) do
        {line,_} = Integer.parse(line)
        [_,after_priv] = String.split(url,"/priv/",parts: 2)
        {JS,:"#{function}",0,file: ~c'#{WebPack.Util.web_priv}/#{after_priv}', line: line}
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
        rescue ex in ReaxtError ->
          [_|stack] = __STACKTRACE__
          reraise ex, ((ex.js_stack || []) ++ stack)
        end
    end
  end

  def render(module,data, timeout \\ 5_000, chunk \\ :server) do
    try do
      render!(module, data, timeout, chunk)
    rescue
      ex->
        case ex do
          %{js_render: js_render} when is_binary(js_render)->
            Logger.error(Exception.message(ex))
            %{css: "",html: "", js_render: js_render}
          _ ->
            reraise ex, __STACKTRACE__
        end
    end
  end

  def reload do
    WebPack.Util.build_stats
    Supervisor.terminate_child(Reaxt.App, Reaxt.App.PoolsSup)
    Supervisor.restart_child(Reaxt.App, Reaxt.App.PoolsSup)
  end

  def start_link(server_path) do
    init = Poison.encode!(Application.get_env(:reaxt,:global_config,nil))
    Exos.Proc.start_link(
      "node #{server_path}",
      init,
      port_opts: [cd: ~c'#{WebPack.Util.web_priv}'],
      etf_opts: [minor_version: 1]
    )
  end

  defmodule App do
    use Application
    def start(_,_) do
      result = Supervisor.start_link(
        [App.PoolsSup] ++ List.wrap(if Application.get_env(:reaxt,:hot) do [
          WebPack.Events,
          WebPack.EventManager,
          WebPack.Compiler,
          #{WebPack.StartBlocker,:infinity} # choice : wait for build or "mix webpack.compile" before launch
        ] end), name: __MODULE__, strategy: :one_for_one)
      WebPack.Util.build_stats
      result
    end
    defmodule PoolsSup do
      use Supervisor
      def start_link(arg) do Supervisor.start_link(__MODULE__,arg, name: __MODULE__) end
      def init(_) do
        pool_size = Application.get_env(:reaxt,:pool_size)
        pool_overflow = Application.get_env(:reaxt,:pool_max_overflow)
        server_dir = "#{WebPack.Util.web_priv}/#{Application.get_env(:reaxt,:server_dir)}"
        server_files = Path.wildcard("#{server_dir}/*.js")
        if server_files == [] do
          Logger.error("#server JS not yet compiled in #{server_dir}, compile it before with `mix webpack.compile`")
          throw {:error,:serverjs_not_compiled}
        else
          Supervisor.init(
            for server<-server_files do
              pool = :"react_#{server |> Path.basename(".js") |> String.replace(~r/[0-9][a-z][A-Z]/,"_")}_pool"
              Pool.child_spec(pool,[worker_module: Reaxt,size: pool_size, max_overflow: pool_overflow, name: {:local,pool}], server)
            end, strategy: :one_for_one)
        end
      end
    end
  end
end
