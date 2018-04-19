defmodule WebPack.EventManager do
  use GenEvent
  require Logger
  def start_link do
    res = GenEvent.start_link(name: WebPack.Events)
    GenEvent.add_handler(WebPack.Events,__MODULE__,%{init: true,pending: [], compiling: false, compiled: false})
    receive do :server_ready-> :ok end
    res
  end

  def handle_call({:wait?,_reply_to},%{compiling: false}=state), do:
    {:ok,:nowait,state}
  def handle_call({:wait?,reply_to},state), do:
    {:ok,:wait,%{state|pending: [reply_to|state.pending]}}

  def handle_event(%{event: "client_done"}=ev,state) do
    Logger.info("[reaxt-webpack] client done, build_stats")
    WebPack.Util.build_stats
    if(!state.init) do
      Logger.info("[reaxt-webpack] client done, restart servers")
      :ok = Supervisor.terminate_child(Reaxt.Sup,:react)
      {:ok,_} = Supervisor.restart_child(Reaxt.Sup,:react)
    end
    if ev[:error] do
      Logger.error("[rext-webpack] error compiling server_side JS #{ev[:error]}")
      if ev[:error] != "soft fail", do:
        System.halt(1)
    end
    for {_idx,build}<-WebPack.stats, error<-build.errors, do: Logger.warn(error)
    for {_idx,build}<-WebPack.stats, warning<-build.warnings, do: Logger.warn(warning)
    {:ok,done(state)}
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
    for pid<-state.pending, do: send(pid,:ok)
    if state.init, do: send(Process.whereis(Reaxt.Sup),:server_ready)
    GenEvent.notify(WebPack.Events,%{event: "done"})
    %{state| pending: [], init: false, compiling: false, compiled: true}
  end
end

defmodule WebPack.Compiler do
  def start_link do
    cmd = "node ./node_modules/reaxt/webpack_server #{WebPack.Util.webpack_config}"
    hot_arg = if Application.get_env(:reaxt,:hot) == :client, do: " hot",else: ""
    Exos.Proc.start_link(cmd<>hot_arg,[],[cd: WebPack.Util.web_app],[name: __MODULE__],WebPack.Events)
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

  def build_stats do
    if File.exists?("#{web_priv}/webpack.stats.json") do
      all_stats = Poison.Parser.parse!(File.read!("#{web_priv}/webpack.stats.json"))
      stats = all_stats["children"] |> Enum.with_index |> Enum.into(%{},fn {stats,idx}->
         {idx,%{assetsByChunkName: stats["assetsByChunkName"],
                errors: stats["errors"],
                warnings: stats["warnings"]}}
      end)
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
    end
  end
end

defmodule Elixir.WebPack do
  def stats, do: %{assetsByChunkName: %{}}
  def file_of(_), do: nil
  def header, do: ""
end
