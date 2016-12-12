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
      if String.contains?(url,"server.js") and !(function in ["Port.next_term","Socket.read_term"]) do
        {line,_} = Integer.parse(line)
        {JS,:"#{function}",0,file: '#{WebPack.Util.web_priv}/server.js', line: line}
      end
    end)
    |> Enum.filter(&!is_nil(&1))
  end
end
defmodule Reaxt do
  alias :poolboy, as: Pool
  require Logger

  def render_result(module,data,timeout) when not is_tuple(module), do:
    render_result({module,nil},data,timeout)
  def render_result({module,submodule},data,timeout) do
    Pool.transaction(:react_pool,fn worker->
      GenServer.call(worker,{:render,module,submodule,data,timeout},timeout+100)
    end)
  end

  def render!(module,data, timeout \\ 5_000) do
    case render_result(module,data,timeout) do
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

  def start_link([]) do
    init = Poison.encode!(Application.get_env(:reaxt,:global_config,nil))
    Exos.Proc.start_link("node server",init,[cd: '#{WebPack.Util.web_priv}'])
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
        pool_size = Application.get_env(:reaxt,:pool_size)
        pool_overflow = Application.get_env(:reaxt,:pool_max_overflow)
        dev_workers = if Application.get_env(:reaxt,:hot),
           do: [worker(WebPack.Compiler.Client,[]),
                worker(WebPack.Compiler.Server,[]),
                worker(WebPack.EventManager,[])], else: []
        supervise([
          Pool.child_spec(:react,[worker_module: Reaxt,size: pool_size, max_overflow: pool_overflow, name: {:local,:react_pool}], [])
        ]++dev_workers, strategy: :one_for_one)
      end
    end
  end
end
