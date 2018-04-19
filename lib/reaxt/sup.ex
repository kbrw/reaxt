defmodule Reaxt.Sup do
  @moduledoc """
  Reaxt supervisor
  """
  use Supervisor

  require Logger

  @doc false
  def init([]) do
    dev_workers = if Application.get_env(:reaxt, :hot) do
      [
	worker(Reaxt.Env, []),
	worker(WebPack.Compiler, []),
	worker(WebPack.EventManager, [])
      ]
    else
      []
    end
    supervise([Supervisor.Spec.supervisor(__MODULE__, [], function: :start_pools,id: :react) | dev_workers],
      strategy: :one_for_one)
  end

  @doc false
  def start_pools do
    pool_size = Application.get_env(:reaxt, :pool_size)
    pool_overflow = Application.get_env(:reaxt, :pool_max_overflow)
    server_dir = "#{WebPack.Util.web_priv()}/#{Application.get_env(:reaxt, :server_dir)}"
    server_files = Path.wildcard("#{server_dir}/*.js")
    
    if server_files == [] do
      Logger.error("#server JS not yet compiled in #{server_dir}, compile it before with `mix webpack.compile`")
      throw {:error, :serverjs_not_compiled}
    else
      children = for server <- server_files do
	id = server |> Path.basename(".js") |> String.replace(~r/[0-9][a-z][A-Z]/, "_")
        pool_id = :"react_#{id}_pool"
	opts = [ worker_module: Reaxt, size: pool_size, max_overflow: pool_overflow, name: {:local, pool_id} ]
	Logger.info("Starting reaxt pool #{pool_id}")
        :poolboy.child_spec(pool_id, opts, server)
      end
      Supervisor.start_link(children, strategy: :one_for_one)
    end
  end  
end
