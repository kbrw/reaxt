defmodule Mix.Tasks.Webpack.Analyseapp do
  use Mix.Task

  alias Mix.Reaxt.Common

  @moduledoc """
  Generate webpack stats analysing application, resulting priv/static is meant to be versionned
  """
  
  @shortdoc "Generate webpack stats analysing application"

  @doc false
  def run(_args) do
    env = Common.init_nox()
    
    File.rm_rf!("priv/static")

    {_,0} = System.cmd("git", ["clone", "-b", "ajax-sse-loading", "https://github.com/awetzel/analyse"],
      into: Nox.Cli.stream())

    {:ok, _} = Nox.Npm.install(env, "analyse")
    {:ok, _} = Nox.Npm.install_global(env, "grunt")
    {:ok, _} = Nox.Grunt.run(env, "analyse")

    File.cp_r!("analyse/dist", "priv/static")
    File.rm_rf!("analyse")
  end
end
