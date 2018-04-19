defmodule Mix.Tasks.Compile.ReaxtWebpack do
  use Mix.Task

  @moduledoc """
  Compiler for building web app with reaxt
  """

  @shortdoc "Compiler for building web app with reaxt"

  @doc false
  def run(args) do
    Mix.Task.run("reaxt.validate", args ++ ["--reaxt-skip-compiler-check"])

    if !File.exists?(Path.join(WebPack.Util.web_app(), "node_modules")) do
      Mix.Task.run("npm.install", args)
    else
      installed_version = Poison.decode!(File.read!("#{WebPack.Util.web_app()}/node_modules/reaxt/package.json"))["version"]
      current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
      if  installed_version !== current_version, do:
        Mix.Task.run("npm.install", args)
    end

    if ! Application.get_env(:reaxt, :hot) do
      Mix.Task.run("webpack.compile", args)
    end

    :ok
  end
end
