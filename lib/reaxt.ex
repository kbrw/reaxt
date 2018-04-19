defmodule Reaxt do
  @moduledoc """
  Provides functions for working with react workers
  """
  require Logger

  alias Reaxt.Env

  @type rendering :: %{ html: String.t, css: String.t, js_render: String.t, param: term }
  @type render_ret :: {:ok, rendering} | {:error, {:handler_error, String.t | term, nil}}

  @doc """
  Start react workers
  """
  def start_link(server_path) do
    init = Poison.encode!(Application.get_env(:reaxt, :global_config, nil))
    opts = [
      cd: '#{WebPack.Util.web_priv()}',
      env: Nox.sys_env(Env.get()) |> Enum.map(fn {name, val} -> {'#{name}', '#{val}'} end)
    ]
    exe = Nox.which(Env.get(), "node")
    Exos.Proc.start_link("#{exe} #{server_path}", init, opts)
  end

  @doc """
  Render a react component

  * module: name of the react module
  * data: bindings
  * timeout: default to 5_000
  * chunk: one of react servers. For instance, if react server dir contains server1.js and server2.js,
           chunk can be :server1 or :server2
  """
  @spec render!(module :: atom, data :: map, timeout :: integer, chunk :: atom) :: rendering
  def render!(module, data, timeout \\ 5_000, chunk \\ :server) do
    case render_result(chunk, module, data, timeout) do
      {:ok, res} -> res
      {:error, err} ->
        try do
	  raise(Reaxt.Error, err)
        rescue ex->
          [_ | stack] = System.stacktrace()
          reraise ex, ((ex.js_stack || []) ++ stack)
        end
    end
  end

  @doc """
  Render a react server component, like render!/2,3,4 but does not raise exception if 
  `js_render` field is not empty
  """
  @spec render(module :: atom, data :: map, timeout :: integer) :: rendering
  def render(module, data, timeout \\ 5_000) do
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

  @doc """
  Reload reaxt
  """
  @spec reload() :: :ok
  def reload do
    WebPack.Util.build_stats()
    Supervisor.terminate_child(Reaxt.Sup, :react)
    Supervisor.restart_child(Reaxt.Sup, :react)
    :ok
  end

  ###
  ### Priv
  ###

  # Not sure if someone use it publicly...
  @doc false
  @spec render_result(atom, atom, map, integer) :: render_ret
  def render_result(chunk, module, data, timeout) when not is_tuple(module) do
    render_result(chunk, {module, nil}, data, timeout)
  end
  def render_result(chunk, {module, submodule}, data, timeout) do
    :poolboy.transaction(:"react_#{chunk}_pool", fn worker ->
      GenServer.call(worker, {:render, module, submodule, data, timeout}, timeout + 100)
    end)
  end
end
