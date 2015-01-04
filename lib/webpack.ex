defmodule Mix.Tasks.Npm.Install do
  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "web")
    System.cmd("npm",["install","#{:code.priv_dir(:reaxt)}/react_server"], into: IO.stream(:stdio, :line), cd: "web")
  end
end

defmodule Mix.Tasks.Webpack.Analyseapp do
  @shortdoc "Generate webpack stats analysing application, resulting priv/analyse is meant to be versionned"
  def run(_args) do
    {_,0} = System.cmd("git",["clone","-b","ajax-sse-loading","https://github.com/awetzel/analyse"], into: IO.stream(:stdio, :line))
    {_,0} = System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: "analyse")
    {_,0} = System.cmd("grunt",[], into: IO.stream(:stdio, :line), cd: "analyse")
    File.cp_r!("analyse/dist", "priv/analyse")
    File.rm_rf!("analyse")
  end
end

defmodule Mix.Tasks.Webpack.Compile do
  @shortdoc "Compiles Webpack"
  def run(_) do
    webpack = "./node_modules/react_server/node_modules/webpack/bin/webpack.js"
    server_config = "./node_modules/react_server/server.webpack.config.js"
    {_res,0} = System.cmd("node",[webpack,"--config",server_config,"--colors"], into: IO.stream(:stdio, :line), cd: "web")
    {json,0} = System.cmd("node",[webpack,"--colors","--json"], into: "", cd: "web")
    File.write!("priv/webpack.stats.json",json)
    build_stats
  end

  def build_stats do
    if File.exists?("priv/webpack.stats.json") do
      stats = Poison.Parser.parse!(File.read!("priv/webpack.stats.json"), keys: :atoms)
      defmodule Elixir.WebPack do
        @stats stats
        def stats, do: @stats
      end
    end 
  end
end

defmodule Mix.Tasks.Compile.Reaxt_webpack do
  def run(args) do
    if !File.exists?("web/node_modules"), do:
      Mix.Task.run("npm.install", args)
    Mix.Task.run("webpack.compile", args)
  end
end
