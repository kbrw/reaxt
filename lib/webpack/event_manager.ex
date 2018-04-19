defmodule WebPack.EventManager do
  @moduledoc """
  Event manager for webpack
  """
  @behaviour :gen_event
  
  require Logger

  @doc false
  def start_link do
    res = :gen_event.start_link({:local, WebPack.Events})

    state0 = %{init: true, pending: [], compiling: false, compiled: false}
    :gen_event.add_handler(WebPack.Events, __MODULE__, state0)
    receive do
      :server_ready -> :ok
    end
    res
  end

  ###
  ### gen_event callbacks
  ### 
  @doc false
  def init(s), do: {:ok, s}

  @doc false
  def handle_call({:wait?, _reply_to}, %{compiling: false}=state) do
    {:ok, :nowait, state}
  end
  def handle_call({:wait?, reply_to}, state) do
    {:ok, :wait, %{ state | pending: [reply_to | state.pending]}}
  end

  @doc false
  def handle_event(%{event: "client_done"}=ev, state) do
    Logger.info("[reaxt-webpack] client done, build_stats")
    _ = WebPack.Util.build_stats()
    
    if (!state.init) do
      Logger.info("[reaxt-webpack] client done, restart servers")
      :ok = Supervisor.terminate_child(Reaxt.Sup, :react)
      {:ok, _} = Supervisor.restart_child(Reaxt.Sup, :react)
    end
    
    if ev[:error] do
      Logger.error("[rext-webpack] error compiling server_side JS #{ev[:error]}")
      if ev[:error] != "soft fail" do
        System.halt(1)
      end
    end
    
    for {_idx, build} <- WebPack.stats, error <- build.errors, do: Logger.warn(error)
    for {_idx, build} <- WebPack.stats, warning <- build.warnings, do: Logger.warn(warning)
    
    {:ok, done(state)}
  end
  def handle_event(%{event: "client_invalid"}, %{compiling: false}=state) do
    Logger.info("[reaxt-webpack] detect client file change")
    {:ok, %{state | compiling: true, compiled: false}}
  end
  def handle_event(%{event: "done"}, state) do
    Logger.info("[reaxt-webpack] both done !")
    {:ok, state}
  end
  def handle_event(ev, state) do
    Logger.info("[reaxt-webpack] event : #{ev[:event]}")
    {:ok, state}
  end

  ###
  ### Priv
  ###
  def done(state) do
    for pid <- state.pending, do: send(pid, :ok)

    if state.init do
      send(Process.whereis(Reaxt.Sup), :server_ready)
    end
    :gen_event.notify(WebPack.Events, %{event: "done"})
    %{ state | pending: [], init: false, compiling: false, compiled: true }
  end
end
