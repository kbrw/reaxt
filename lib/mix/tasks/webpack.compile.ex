defmodule Mix.Tasks.Webpack.Compile do
  use Mix.Task

  alias Mix.Reaxt.Common

  @moduledoc """
  Compile Webpack
  """
  
  @shortdoc "Compiles Webpack"
  @webpack "./node_modules/webpack/bin/webpack.js"

  @doc false
  def run(_) do
    {json, 0} = compile()
    File.write!("priv/webpack.stats.json",json)
  end
  
  defp compile() do
    env = Common.init_nox()
    config = "./" <> WebPack.Util.webpack_config()
    System.cmd(Nox.which(env, "node"), [@webpack, "--config", config, "--json"],
      into: "", cd: WebPack.Util.web_app(), env: Nox.sys_env(env))
  end
end
