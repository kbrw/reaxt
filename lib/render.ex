defmodule Reaxt.Render do
  require Logger

  def get_global_config do
    Application.get_env(:reaxt, :global_config, %{})
  end

  def set_global_config(config) do
    Application.put_env(:reaxt, :global_config, config)
  end

  def render_result(chunk, module, data, timeout) when not is_tuple(module) do
    render_result(chunk, {module, nil}, data, timeout)
  end

  def render_result(chunk, {module, submodule}, data, timeout) do
    Reaxt.PoolsSup.transaction(:"react_#{chunk}_pool", fn worker ->
      GenServer.call(worker, {:render, module, submodule, data, timeout}, timeout + 100)
    end)
  end

  def render!(module, data, timeout \\ 5_000, chunk \\ :server) do
    case render_result(chunk, module, data, timeout) do
      {:ok, res} ->
        res

      {:error, err} ->
        try do
          raise(Reaxt.Error, err)
        rescue
          ex ->
            [_ | stack] = __STACKTRACE__
            # stack = List.wrap(ex[:js_stack]) |> Enum.concat(stack)
            reraise ex, stack
        end
    end
  end

  def render(module, data, timeout \\ 5_000) do
    try do
      render!(module, data, timeout)
    rescue
      ex ->
        case ex do
          %{js_render: js_render} when is_binary(js_render) ->
            Logger.error(Exception.message(ex))
            %{css: "", html: "", js_render: js_render}

          _ ->
            reraise ex, __STACKTRACE__
        end
    end
  end

  def reload do
    if Reaxt.Utils.is_webpack?(), do: Reaxt.Index.Generator.build_webpack_stats()
    :ok = Supervisor.terminate_child(Reaxt.App, Reaxt.PoolsSup)
    Supervisor.restart_child(Reaxt.App, Reaxt.PoolsSup)
  end

  def start_link(server_path) do
    init = Poison.encode!(Application.get_env(:reaxt, :global_config, nil))
    Exos.Proc.start_link("node #{server_path}", init, cd: ~c"#{Reaxt.Utils.web_priv()}")
  end
end
