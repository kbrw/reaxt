defmodule Mix.Tasks.Npm.Install do
  use Mix.Task

  alias Mix.Reaxt.Common
  
  @moduledoc """
  Install node modules for web app
  """

  @shortdoc "`npm install` in web_dir + npm install server side dependencies"

  @doc false
  def run(_args) do
    env = Common.init_nox()
    
    {:ok, _} = Nox.Npm.install(env, WebPack.Util.web_app())

    # TOIMPROVE- did not found a better hack to avoid npm install symlink : first make a tar gz package, then npm install it
    reaxt_tgz = "#{System.tmp_dir}/reaxt.tgz"
    System.cmd("tar", ["zcf", reaxt_tgz, "commonjs_reaxt"], into: Nox.Cli.stream(), cd: "#{:code.priv_dir(:reaxt)}")

    {:ok, _} = Nox.Npm.install(env, WebPack.Util.web_app(), reaxt_tgz, no_save: true)
  end
end
