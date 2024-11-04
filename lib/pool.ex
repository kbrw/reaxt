defmodule Reaxt.PoolsSup do
  @moduledoc """
  Supervision of multiple :poolboy instances for the Server Side Rendering
  """
  alias :poolboy, as: Pool

  use Supervisor
  require Logger

  def transaction(pool_name, fct) do
    Pool.transaction(pool_name, fct)
  end

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_) do
    pool_size = Reaxt.Utils.pool_size()
    pool_overflow = Reaxt.Utils.max_pool_overflow()
    server_dir = "#{Reaxt.Utils.web_priv()}/#{Reaxt.Utils.server_dir()}"
    server_files = Path.wildcard("#{server_dir}/*.js")

    if server_files == [] do
      Logger.error(
        "#server JS not yet compiled in #{server_dir}, compile it before with `mix webpack.compile`"
      )

      throw({:error, :serverjs_not_compiled})
    else
      children =
        Enum.map(server_files, fn server ->
          parsed_js_name =
            server |> Path.basename(".js") |> String.replace(~r/[0-9][a-z][A-Z]/, "_")

          pool_name = :"react_#{parsed_js_name}_pool"

          args = [
            worker_module: Reaxt.Render,
            size: pool_size,
            max_overflow: pool_overflow,
            name: {:local, pool_name}
          ]

          Pool.child_spec(pool_name, args, server)
        end)

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
