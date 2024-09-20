defmodule Mix.Tasks.Esbuild.Compile do
  use Mix.Task

  @shortdoc "Compiles Esbuild"
  @esbuild "./node_modules/esbuild/bin/esbuild.js"

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
    config = "./" <> Reaxt.Esbuild.esbuild_config()
    esbuild = @esbuild
    System.cmd(
      "node",
      [esbuild, "--config", config, "--json"],
      into: "",
      cd: Reaxt.Utils.web_app(),
      env: [{"MIX_ENV", "#{Mix.env()}"}]
    )
  end
end

defmodule Mix.Tasks.Compile.ReaxtEsbuild do
  use Mix.Task.Compiler

  def run(args) do
    IO.puts("[Reaxt] Running Esbuild compiler...")
    Mix.Task.run("reaxt.validate", args ++ ["--reaxt-skip-compiler-check"])

    if !File.exists?(Path.join(Reaxt.Utils.web_app, "node_modules")) do
      Mix.Task.run("npm.install", args)
    else
      installed_version = Poison.decode!(File.read!("#{Reaxt.Utils.web_app}/node_modules/reaxt/package.json"))["version"]
      current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
      if  installed_version !== current_version, do:
        Mix.Task.run("npm.install", args)
    end

    if !Application.get_env(:reaxt, :hot) do
      Mix.Task.run("esbuild.compile", args)
    else
      {:ok, []}
    end
  end
end
