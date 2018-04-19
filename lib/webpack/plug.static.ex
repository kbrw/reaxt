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

  defmodule EventHandler do
    @behaviour :gen_event

    @doc false
    def init(s), do: {:ok, s}

    @doc false
    def handle_event(ev, conn) do # Send all builder events to browser through SSE
      Plug.Conn.chunk(conn, "event: #{ev.event}\ndata: #{Poison.encode!(ev)}\n\n")
      {:ok, conn}
    end

    @doc false
    def handle_call(_call, s), do: {:ok, :ok, s}
  end

  @doc false
  def init(static_opts), do: Plug.Static.init(static_opts)

  @doc false
  def call(conn, opts) do
    conn = plug_builder_call(conn, opts)
    if !conn.halted, do: static_plug(conn,opts), else: conn
  end

  @doc """
  This plug defers answers until webpack is compiled
  """
  def wait_compilation(conn, _) do
    wait = :gen_event.call(WebPack.Events, WebPack.EventManager, {:wait?, self()})
    if Application.get_env(:reaxt, :hot) && :wait == wait do
      receive do
	:ok -> :ok
      after
	30_000 -> :ok
      end # if a compil is running, wait its end before serving asset
    end
    conn
  end

  get "/webpack/stats.json" do
    conn
      |> put_resp_content_type("application/json")
      |> send_file(200,"#{WebPack.Util.web_priv()}/webpack.stats.json")
      |> halt()
  end

  get "/webpack", do: %{ conn | path_info: ["webpack","static","index.html"]}

  get "/webpack/events" do
    conn = conn
      |> put_resp_header("content-type", "text/event-stream")
      |> send_chunked(200)
    hot? = Application.get_env(:reaxt, :hot)
    if hot? == :client do
      Plug.Conn.chunk(conn, "event: hot\ndata: nothing\n\n")
    end
    
    if hot? do
      :gen_event.add_sup_handler(WebPack.Events, {WebPack.Plug.Static.EventHandler, make_ref()}, conn)
    end
    receive do
      {:gen_event_EXIT, _, _} -> halt(conn)
    end
  end
  
  get "/webpack/client.js" do
    conn
      |> put_resp_content_type("application/javascript")
      |> send_file(200, "#{WebPack.Util.web_app()}/node_modules/reaxt/webpack_client.js")
      |> halt()
  end
  
  match _, do: conn

  ###
  ### Priv
  ###
  defp static_plug(conn, static_opts), do: Plug.Static.call(conn, static_opts)
end
