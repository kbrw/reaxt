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

  def init(static_opts), do: Plug.Static.init(static_opts)
  def call(conn,static_opts) do
    conn = plug_builder_call(conn,static_opts) #manage webpack dev specific assets in this builder
    if conn.halted do conn else
      if Application.get_env(:reaxt,:hot) && 
           :wait == GenEvent.call(WebPack.Events,WebPack.EventManager,{:wait?,self}) do
        receive do :ok->:ok after 30_000->:ok end # if a compil is running, wait its end before serving asset
      end
      Plug.Static.call(conn,static_opts) # finally serve static files as with Plug.Static
    end
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
  def start_link do
    res = GenEvent.start_link(name: WebPack.Events)
    GenEvent.add_handler(WebPack.Events,__MODULE__,{:wait_server_ready,[]})
    receive do :server_ready-> :ok end
    res 
  end

  def handle_call({:wait?,_reply_to},{:idle,_}=state), do:
    {:ok,:nowait,state}
  def handle_call({:wait?,reply_to},{build_state,pending}), do:
    {:ok,:wait,{build_state,[reply_to|pending]}}

  def handle_event(%{event: "done"}=ev,{state,pending}) do
    WebPack.Util.build_stats
    case {ev,state} do
      {%{error: "soft fail"},:wait_server_ready}->
        IO.puts "Compilation Error: see /webpack#errors"
        send(Process.whereis(Reaxt.App.Sup),:server_ready)
      {%{error: error},:wait_server_ready}->
        IO.puts "FATAL Error: cannot compile server_side renderer"
        IO.puts error
        System.halt(1)
      {_,:wait_server_ready}->
        send(Process.whereis(Reaxt.App.Sup),:server_ready)
      _->
        Supervisor.terminate_child(Reaxt.App.Sup,:react)
        Supervisor.restart_child(Reaxt.App.Sup,:react)
    end
    for pid<-pending, do: send(pid,:ok)
    {:ok,{:idle,[]}}
  end
  def handle_event(%{event: "invalid"},{_,pending}), do:
    {:ok,{:compiling,pending}}
  def handle_event(_ev,state), do: {:ok,state}
end

defmodule WebPack.Compiler do
  def start_link do
    cmd = "node ./node_modules/reaxt/webpack_server"
    hot_arg = if Application.get_env(:reaxt,:hot) == :client, do: " hot",else: ""
    Exos.Proc.start_link(cmd<>hot_arg,:no_init,[cd: 'web'],[name: __MODULE__],WebPack.Events)
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
      defmodule Elixir.WebPack do
        @stats stats
        def stats, do: @stats
        def file_of(name) do
          case WebPack.stats.assetsByChunkName[name] do
            [f|_]->f
            f -> f
          end
        end 
        @header if(Application.get_env(:reaxt,:hot), do: ~s(<script src="/webpack/client.js"></script>))
        def header, do: @header
      end
    end 
  end
end
