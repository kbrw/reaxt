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
    conn = plug_builder_call(conn,static_opts) #manage webpack dev specific assets
    if conn.halted do conn else
      if :wait == GenEvent.call(WebPack.Events,WebPack.EventManager,{:wait?,self}) do
        receive do :ok->:ok after 30_000->:ok end
      end
      Plug.Static.call(conn,static_opts)
    end
  end

  get "/webpack/stats.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_file(200,"#{WebPack.Util.web_priv}/webpack.stats.json")
    |> halt
  end
  get "/webpack" do
    %{conn|path_info: ["webpack","static","index.html"]}
  end
  get "/webpack/events" do
    conn=conn
        |> put_resp_header("content-type", "text/event-stream")
        |> send_chunked(200)
    if Application.get_env(:reaxt,:hot), do:
      Plug.Conn.chunk(conn, "event: hot\ndata: nothing\n\n")
    GenEvent.add_mon_handler(WebPack.Events,{WebPack.Plug.Static.EventHandler,make_ref},conn)
    receive do
      {:gen_event_EXIT,_,_} -> halt(conn)
    end
  end
  get "/webpack/client.js" do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200,"#{:code.priv_dir :reaxt}/client.js")
    |> halt
  end
  match _, do: conn

  defmodule EventHandler do
    use GenEvent
    def handle_event(ev,conn) do
      Plug.Conn.chunk(conn, "event: #{ev.event}\ndata: #{Poison.encode!(ev)}\n\n")
      {:ok, conn}
    end
  end
end

defmodule WebPack.EventManager do
  use GenEvent
  def start_link do
    res = GenEvent.start_link(name: WebPack.Events)
    GenEvent.add_handler(WebPack.Events,__MODULE__,{:idle,[]})
    res 
  end

  def handle_call({:wait?,_reply_to},{:idle,_}=state), do:
    {:ok,:nowait,state}
  def handle_call({:wait?,reply_to},{build_state,pending}), do:
    {:ok,:wait,{build_state,[reply_to|pending]}}

  def handle_event(%{event: "invalid"},{_,pending}), do:
    {:ok,{:compiling,pending}}
  def handle_event(%{event: "done"},{_,pending}) do
    Process.exit(Process.whereis(:react_pool), :kill)
    WebPack.Util.build_stats
    for pid<-pending, do: send(pid,:ok)
    {:ok,{:idle,[]}}
  end
  def handle_event(ev,state) do
    IO.puts "not handle event  #{inspect ev}"
    {:ok,state}
  end
end

defmodule WebPack.Compiler do
  def start_link do
    cmd = "node ./node_modules/react_server/webpack_server"
    Exos.Proc.start_link(cmd,:no_init,[cd: 'web'],[],WebPack.Events)
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
      end
    end 
  end
end

defmodule Mix.Tasks.Npm.Install do
  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "web")
    System.cmd("npm",["install","#{:code.priv_dir(:reaxt)}/react_server"], into: IO.stream(:stdio, :line), cd: "web")
  end
end

defmodule Mix.Tasks.Webpack.Analyseapp do
  @shortdoc "Generate webpack stats analysing application, resulting priv/static is meant to be versionned"
  def run(_args) do
    File.rm_rf!("priv/static")
    {_,0} = System.cmd("git",["clone","-b","ajax-sse-loading","https://github.com/awetzel/analyse"], into: IO.stream(:stdio, :line))
    {_,0} = System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "analyse")
    {_,0} = System.cmd("grunt",[], into: IO.stream(:stdio, :line), cd: "analyse")
    File.cp_r!("analyse/dist", "priv/static")
    File.rm_rf!("analyse")
  end
end

defmodule Mix.Tasks.Webpack.Compile do
  @shortdoc "Compiles Webpack"
  def run(_) do
    webpack = "./node_modules/react_server/node_modules/webpack/bin/webpack.js"
    server_config = "./node_modules/react_server/server.webpack.config.js"
    {_res,0} = System.cmd("node",[webpack,"--config",server_config,"--colors"], into: IO.stream(:stdio, :line), cd: "web")
    {json,0} = System.cmd("node",[webpack,"--colors","--json"], into: "", cd: "web")
    File.write!("priv/webpack.stats.json",json)
  end
end

defmodule Mix.Tasks.Compile.Reaxt_webpack do
  def run(args) do
    if !File.exists?("web/node_modules"), do:
      Mix.Task.run("npm.install", args)
    Mix.Task.run("webpack.compile", args)
  end
end
