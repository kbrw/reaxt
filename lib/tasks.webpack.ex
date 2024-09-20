defmodule Mix.Tasks.Webpack.Analyseapp do
  use Mix.Task

  @shortdoc "Generate webpack stats analysing application, resulting priv/static is meant to be versionned"
  def run(_args) do
    File.rm_rf!("priv/static")
    {_,0} = System.cmd("git",["clone","-b","ajax-sse-loading","https://github.com/awetzel/analyse"], into: IO.stream(:stdio, :line))
    {_,0} = System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "analyse")
    {_,0} = System.cmd("grunt",[], into: IO.stream(:stdio, :line), cd: "analyse")
    File.cp_r!("analyse/dist", "priv/static")
    File.rm_rf!("analyse")
  end
end

defmodule Mix.Tasks.Webpack.Compile do
  use Mix.Task

  @shortdoc "Compiles Webpack"
  @webpack "./node_modules/webpack/bin/webpack.js"

  def run(_) do
    case compile() do
      {json, 0} ->
        File.write!("priv/webpack.stats.json", json)
        {:ok, []}

      {ret, x} when x in [1,2] ->
        require Logger
        ret
        |> Poison.decode!()
        |> Map.fetch!("errors")
        |> Enum.map(fn
          bin when is_binary(bin) -> Logger.error(bin)
          %{"message" => bin} when is_binary(bin) -> Logger.error(bin)
        end)
        {:error,[]}
    end
  end

  def compile() do
    config = "./"<>WebPack.Util.webpack_config
    webpack = @webpack
    System.cmd(
      "node",
      [webpack, "--config", config, "--json"],
      into: "",
      cd: Reaxt.Utils.web_app(),
      env: [{"MIX_ENV", "#{Mix.env()}"}]
    )
  end
end

defmodule Mix.Tasks.Compile.ReaxtWebpack do
  use Mix.Task.Compiler

  def run(args) do
    IO.puts("[Reaxt] Running Webpack compiler...")
    Mix.Task.run("reaxt.validate", args ++ ["--reaxt-skip-compiler-check"])

    if !File.exists?(Path.join(Reaxt.Utils.web_app, "node_modules")) do
      Mix.Task.run("npm.install", args)
    else
      installed_version = Poison.decode!(File.read!("#{Reaxt.Utils.web_app}/node_modules/reaxt/package.json"))["version"]
      current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
      if  installed_version !== current_version, do:
        Mix.Task.run("npm.install", args)
    end

    if !Application.get_env(:reaxt,:hot) do
      Mix.Task.run("webpack.compile", args)
    else
      {:ok, []}
    end
  end
end
