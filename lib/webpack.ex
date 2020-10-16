defmodule WebPack.Events do
  def child_spec(_) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  @dispatch_key :events
  def register! do
    {:ok, _} = Registry.register(__MODULE__,@dispatch_key,nil)
  end
  def dispatch(event) do
    Registry.dispatch(__MODULE__, @dispatch_key, fn entries ->
      for {pid, nil} <- entries, do: send(pid,{:event,event})
    end)
  end

  import Plug.Conn
  def stream_chunks(conn) do
    register!()
    conn = Stream.repeatedly(fn-> receive do {:event,event}-> event end end)
      |> Enum.reduce_while(conn, fn event, conn ->
        io = "event: #{event.event}\ndata: #{Poison.encode!(event)}\n\n"
        case chunk(conn,io) do {:ok,conn}->{:cont,conn};{:error,:closed}->{:halt,conn} end
      end)
    halt(conn)
  end
end

defmodule WebPack.Plug.Static do
  @moduledoc """
  This plug API is the same as plug.static,
  but wrapped to :
  - wait file if compiling before serving them
  - add server side event endpoint for webpack build events
  - add webpack "stats" JSON getter, and stats static analyser app
  """
  use Plug.Router
  plug :match
  plug :dispatch
  plug Plug.Static, at: "/webpack/static", from: :reaxt
  plug :wait_compilation

  def init(static_opts), do: Plug.Static.init(static_opts)
  def call(conn, opts) do
    conn = plug_builder_call(conn, opts)
    if !conn.halted, do: static_plug(conn,opts), else: conn
  end

  def wait_compilation(conn,_) do
    if Application.get_env(:reaxt,:hot) do
      try do
        :ok = GenServer.call(WebPack.EventManager,:wait?,30_000)
      catch
        :exit,{:timeout,_} -> :ok
      end
    end
    conn
  end

  def static_plug(conn,static_opts) do
    Plug.Static.call(conn,static_opts)
  end

  get "/webpack/stats.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_file(200,"#{WebPack.Util.web_priv}/webpack.stats.json")
    |> halt
  end
  get "/webpack", do: %{conn|path_info: ["webpack","static","index.html"]}
  get "/webpack/events" do
    conn=conn
        |> put_resp_header("content-type", "text/event-stream")
        |> send_chunked(200)
    hot? = Application.get_env(:reaxt,:hot)
    if hot? == :client, do: chunk(conn, "event: hot\ndata: nothing\n\n")
    if hot? do WebPack.Events.stream_chunks(conn) else conn end
  end
  get "/webpack/client.js" do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200,"#{WebPack.Util.web_app}/node_modules/reaxt/webpack_client.js")
    |> halt
  end
  match _, do: conn

end

defmodule WebPack.StartBlocker do
  @moduledoc """
  this process blocks application start to ensure that when the next application starts
  the reaxt render is ready (js is compiled)
  """
  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}, restart: :temporary}
  end
  def start_link(timeout) do
    {:ok,spawn_link(fn-> :ok = GenServer.call(WebPack.EventManager,:wait?,timeout) end)}
  end
end

defmodule WebPack.EventManager do
  use GenServer
  require Logger
  def start_link(_) do GenServer.start_link(__MODULE__,[], name: __MODULE__) end

  def init([]) do
    {:ok,%{init: true,pending: [], compiling: false, compiled: false}}
  end

  def handle_call(:wait?,_from,%{compiling: false}=state), do:
    {:reply,:ok,state}
  def handle_call(:wait?,from,state), do:
    {:noreply,%{state|pending: [from|state.pending]}}

  def handle_info({:event,%{event: "client_done"}=ev},state) do
    Logger.info("[reaxt-webpack] client done, build_stats")
    WebPack.Util.build_stats
    if(!state.init) do
      Logger.info("[reaxt-webpack] client done, restart servers")
      :ok = Supervisor.terminate_child(Reaxt.App, Reaxt.App.PoolsSup)
      {:ok,_} = Supervisor.restart_child(Reaxt.App, Reaxt.App.PoolsSup)
    end
    if ev[:error] do
      Logger.error("[reaxt-webpack] error compiling server_side JS #{ev[:error]}")
      if ev[:error] != "soft fail", do:
        System.halt(1)
    end
    for {_idx,build}<-WebPack.stats, error<-build.errors, do: Logger.warn(error)
    for {_idx,build}<-WebPack.stats, warning<-build.warnings, do: Logger.warn(warning)
    {:noreply,done(state)}
  end

  def handle_event(%{event: "client_invalid"},%{compiling: false}=state) do
    Logger.info("[reaxt-webpack] detect client file change")
    {:ok,%{state|compiling: true, compiled: false}}
  end
  def handle_event(%{event: "done"},state) do
    Logger.info("[reaxt-webpack] both done !")
    {:ok,state}
  end
  def handle_event(ev,state) do
    Logger.info("[reaxt-webpack] event : #{ev[:event]}")
    {:ok,state}
  end

  def done(state) do
    for from<-state.pending do GenServer.reply(from,:ok) end
    WebPack.Events.dispatch(%{event: "done"})
    %{state| pending: [], init: false, compiling: false, compiled: true}
  end
end

defmodule WebPack.Compiler do
  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]} }
  end
  def start_link(_) do
    cmd = "node ./node_modules/reaxt/webpack_server #{WebPack.Util.webpack_config}"
    hot_arg = if Application.get_env(:reaxt,:hot) == :client, do: " hot",else: ""
    Exos.Proc.start_link(cmd<>hot_arg,[],[cd: WebPack.Util.web_app],[name: __MODULE__],&WebPack.Events.dispatch/1)
  end
end

defmodule WebPack.Util do
  def webpack_config do
    Application.get_env(:reaxt,:webpack_config,"webpack.config.js")
  end

  def web_priv do
    case Application.get_env :reaxt, :otp_app, :no_app_specified do
      :no_app_specified -> :no_app_specified
      web_app -> :code.priv_dir(web_app)
    end
  end

  def web_app do
    Application.get_env :reaxt, :web_app, "web"
  end

  def parallel_build do
    ## We can't have parallel AND hot reload together
    Application.get_env(:reaxt, :hot, false) == false && Application.get_env(:reaxt, :parallel, false)
  end

  def build_stats do
    if File.exists?("#{web_priv()}/webpack.stats.json") do
      all_stats = Poison.decode!(File.read!("#{web_priv()}/webpack.stats.json"))
      #The format of the stats from parallel-webpack is different than the raw one from webpack
      stats_array = if WebPack.Util.parallel_build, do: all_stats, else: all_stats["children"]
      stats = stats_array |> Enum.with_index |> Enum.into(%{},fn {stats,idx}->
         {idx,%{assetsByChunkName: stats["assetsByChunkName"],
                errors: stats["errors"],
                warnings: stats["warnings"]}}
      end)
      _ = Code.compiler_options(ignore_module_conflict: true)
      defmodule Elixir.WebPack do
        @stats stats
        def stats, do: @stats
        def file_of(name) do
          r = Enum.find_value(WebPack.stats,
            fn {_,%{assetsByChunkName: assets}}->
              assets["#{name}"]
            end)
          case r do
            [f|_]->f
            f -> f
          end
        end
        @header_script if(Application.get_env(:reaxt,:hot), do: ~s(<script src="/webpack/client.js"></script>))
        @header_global Poison.encode!(Application.get_env(:reaxt,:global_config))
        def header, do:
          "<script>window.global_reaxt_config=#{@header_global}</script>\n#{@header_script}"
      end
      _ = Code.compiler_options(ignore_module_conflict: false)
    end
  end
end

defmodule Elixir.WebPack do
  def stats, do: %{assetsByChunkName: %{}}
  def file_of(_), do: nil
  def header, do: ""
end
