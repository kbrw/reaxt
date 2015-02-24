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
    if Application.get_env(:reaxt,:hot) && 
         :wait == GenEvent.call(WebPack.Events,WebPack.EventManager,{:wait?,self}) do
      receive do :ok->:ok after 30_000->:ok end # if a compil is running, wait its end before serving asset
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
    if hot? == :client, do: Plug.Conn.chunk(conn, "event: hot\ndata: nothing\n\n")
    if hot?, do:
      GenEvent.add_mon_handler(WebPack.Events,{WebPack.Plug.Static.EventHandler,make_ref},conn)
    receive do {:gen_event_EXIT,_,_} -> halt(conn) end
  end
  get "/webpack/client.js" do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200,"web/node_modules/reaxt/webpack_client.js")
    |> halt
  end
  match _, do: conn

  defmodule EventHandler do
    use GenEvent
    def handle_event(ev,conn) do #Send all builder events to browser through SSE
      Plug.Conn.chunk(conn, "event: #{ev.event}\ndata: #{Poison.encode!(ev)}\n\n")
      {:ok, conn}
    end
  end
end

defmodule WebPack.EventManager do
  use GenEvent
  require Logger
  def start_link do
    res = GenEvent.start_link(name: WebPack.Events)
    GenEvent.add_handler(WebPack.Events,__MODULE__,%{init: true,pending: [], compiling: false})
    receive do :server_ready-> :ok end
    res 
  end

  def handle_call({:wait?,_reply_to},%{compiling: false}=state), do:
    {:ok,:nowait,state}
  def handle_call({:wait?,reply_to},state), do:
    {:ok,:wait,%{state|pending: [reply_to|state.pending]}}

  def handle_event(%{event: "done"}=ev,state) do
    WebPack.Util.build_stats
    case {ev,state.init} do
      {%{error: "soft fail"},true}->
        Logger.error("Compilation Error: see /webpack#errors")
        send(Process.whereis(Reaxt.App.Sup),:server_ready)
      {%{error: error},true}->
        Logger.error("cannot compile server_side renderer")
        Logger.error(error)
        System.halt(1)
      {_,true}->
        send(Process.whereis(Reaxt.App.Sup),:server_ready)
      {_,false}->
        Supervisor.terminate_child(Reaxt.App.Sup,:react)
        Supervisor.restart_child(Reaxt.App.Sup,:react)
    end
    for pid<-state.pending, do: send(pid,:ok)
    {:ok,%{state| pending: [], init: false, compiling: false}}
  end
  def handle_event(%{event: "invalid"},%{compiling: false}=state) do
    spawn fn-> #async compile server on invalid file
      Mix.Tasks.Webpack.Compile.compile_server
      GenServer.cast(WebPack.Compiler,:server_build)
    end
    {:ok,%{state|compiling: true}}
  end
  def handle_event(_ev,state), do: {:ok,state}
end

defmodule WebPack.Compiler do
  def start_link do
    cmd = "node ./node_modules/reaxt/webpack_server"
    hot_arg = if Application.get_env(:reaxt,:hot) == :client, do: " hot",else: ""
    Exos.Proc.start_link(cmd<>hot_arg,[],[cd: 'web'],[name: __MODULE__],WebPack.Events)
  end
end

defmodule WebPack.Util do
  def web_priv do
    web_app = Application.get_env :reaxt, :otp_app
    "#{:code.priv_dir(web_app)}"
  end

  def build_stats do
    if File.exists?("#{web_priv}/webpack.stats.json") do
      stats = Poison.Parser.parse!(File.read!("#{web_priv}/webpack.stats.json"), keys: :atoms)
      stats = %{assetsByChunkName: stats.assetsByChunkName}
      defmodule Elixir.WebPack do
        @stats stats
        def stats, do: @stats
        def file_of(name) do
          case WebPack.stats.assetsByChunkName[name] do
            [f|_]->f
            f -> f
          end
        end 
        @header_script if(Application.get_env(:reaxt,:hot), do: ~s(<script src="/webpack/client.js"></script>))
        @header_global Poison.encode!(Application.get_env(:reaxt,:global_config))
        def header, do:
          "<script>window.global_reaxt_config=#{@header_global}</script>\n#{@header_script}"
      end
    end 
  end
end
