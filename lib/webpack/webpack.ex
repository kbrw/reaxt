defmodule Reaxt.Webpack do
  @moduledoc """
  Utilities functions to fetch specific Webpack configs
  """

  def webpack_config do
    Application.get_env(:reaxt, :webpack_config, "webpack.config.js")
  end
end

defmodule WebPack.Hot.Events do
  def child_spec(_) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  @dispatch_key :events
  def register! do
    {:ok, _} = Registry.register(__MODULE__, @dispatch_key, nil)
  end

  def dispatch(event) do
    Registry.dispatch(__MODULE__, @dispatch_key, fn entries ->
      for {pid, nil} <- entries, do: send(pid, {:event, event})
    end)
  end

  import Plug.Conn

  def stream_chunks(conn) do
    register!()

    conn =
      Stream.repeatedly(fn ->
        receive do
          {:event, event} -> event
        end
      end)
      |> Enum.reduce_while(conn, fn event, conn ->
        io = "event: #{event.event}\ndata: #{Poison.encode!(event)}\n\n"

        case chunk(conn, io) do
          {:ok, conn} -> {:cont, conn}
          {:error, :closed} -> {:halt, conn}
        end
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
    if !conn.halted, do: static_plug(conn, opts), else: conn
  end

  def wait_compilation(conn, _) do
    if Application.get_env(:reaxt, :hot) do
      try do
        :ok = GenServer.call(WebPack.Hot.EventManager, :wait?, 30_000)
      catch
        :exit, {:timeout, _} -> :ok
      end
    end

    conn
  end

  def static_plug(conn, static_opts) do
    Plug.Static.call(conn, static_opts)
  end

  get "/webpack/stats.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_file(200, "#{Reaxt.Utils.web_priv()}/webpack.stats.json")
    |> halt
  end

  get("/webpack", do: %{conn | path_info: ["webpack", "static", "index.html"]})

  get "/webpack/events" do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> send_chunked(200)

    hot? = Reaxt.Utils.is_hot?()
    if hot? == :client, do: chunk(conn, "event: hot\ndata: nothing\n\n")

    if hot? do
      WebPack.Hot.Events.stream_chunks(conn)
    else
      conn
    end
  end

  get "/webpack/client.js" do
    conn
    |> put_resp_content_type("application/javascript")
    |> send_file(200, "#{Reaxt.Utils.web_app()}/node_modules/reaxt/webpack_client.js")
    |> halt
  end

  match(_, do: conn)
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
    :proc_lib.start_link(__MODULE__, :wait, [timeout])
  end

  def wait(timeout) do
    :ok = GenServer.call(WebPack.EventManager, :wait?, timeout)
    :proc_lib.init_ack({:ok, self()})
  end
end

defmodule WebPack.Hot.EventManager do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    WebPack.Hot.Events.register!()
    {:ok, %{init: true, pending: [], compiling: false, compiled: false}}
  end

  def handle_call(:wait?, _from, %{compiling: false} = state), do: {:reply, :ok, state}
  def handle_call(:wait?, from, state), do: {:noreply, %{state | pending: [from | state.pending]}}

  def handle_info({:event, %{event: "client_done"} = ev}, state) do
    Logger.info("[reaxt-webpack] client done, build_stats")
    _ = Reaxt.Index.Generator.build_webpack_stats()

    if(!state.init) do
      Logger.info("[reaxt-webpack] client done, restart servers")
      :ok = Supervisor.terminate_child(Reaxt.App, Reaxt.PoolsSup)
      {:ok, _} = Supervisor.restart_child(Reaxt.App, Reaxt.PoolsSup)
    end

    _ =
      case ev do
        %{error: "soft fail", error_details: details} ->
          _ = Logger.error("[reaxt-webpack] soft fail compiling server_side JS")

          _ =
            Enum.each(details.errors, fn
              bin when is_binary(bin) -> Logger.error(bin)
              %{message: bin} when is_binary(bin) -> Logger.error(bin)
            end)

        %{error: other} ->
          _ = Logger.error("[reaxt-webpack] error compiling server_side JS : #{other}")
          _ = System.halt(1)

        _ ->
          :ok
      end

    for {_idx, build} <- Reaxt.Index.stats(), error <- build.errors, do: Logger.warning(error)

    for {_idx, build} <- Reaxt.Index.stats(),
        warning <- build.warnings,
        do: Logger.warning(warning)

    {:noreply, done(state)}
  end

  def handle_info({:event, %{event: "client_invalid"}}, %{compiling: false} = state) do
    Logger.info("[reaxt-webpack] detect client file change")
    {:noreply, %{state | compiling: true, compiled: false}}
  end

  def handle_info({:event, %{event: "done"}}, state) do
    Logger.info("[reaxt-webpack] both done !")
    {:noreply, state}
  end

  def handle_info({:event, ev}, state) do
    Logger.info("[reaxt-webpack] event : #{ev[:event]}")
    {:noreply, state}
  end

  def done(state) do
    for from <- state.pending do
      GenServer.reply(from, :ok)
    end

    WebPack.Hot.Events.dispatch(%{event: "done"})
    %{state | pending: [], init: false, compiling: false, compiled: true}
  end
end

defmodule WebPack.Hot.Compiler do
  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}
  end

  def start_link(_) do
    cmd = "node ./node_modules/reaxt/webpack_hot_server #{Reaxt.Webpack.webpack_config()}"
    hot_arg = if Application.get_env(:reaxt, :hot) == :client, do: " hot", else: ""

    Exos.Proc.start_link(
      cmd <> hot_arg,
      [],
      [cd: Reaxt.Utils.web_app()],
      [name: __MODULE__],
      &WebPack.Hot.Events.dispatch/1
    )
  end
end
