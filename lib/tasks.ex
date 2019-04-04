defmodule Mix.Tasks.Npm.Install do
  use Mix.Task

  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    {_, 0} = System.cmd("npm", ["install"], into: IO.stream(:stdio, :line), cd: WebPack.Util.web_app)
    reaxt_js_root = Application.get_env(:reaxt, :reaxt_js_root, "reaxt")
    if not File.exists?("#{WebPack.Util.web_app}/node_modules/#{reaxt_js_root}") do
      # TOIMPROVE - did not find a better hack to avoid `npm install`'s symlinks.
      # First we make a tar gz package, then npm installs it.
      reaxt_tgz = "#{System.tmp_dir}/reaxt.tgz"
      System.cmd("tar", ["zcf",reaxt_tgz,"commonjs_reaxt"],into: IO.stream(:stdio, :line), cd: "#{:code.priv_dir(:reaxt)}")
      System.cmd("npm",["install","--no-save",reaxt_tgz], into: IO.stream(:stdio, :line), cd: WebPack.Util.web_app)
    end
    :ok
  end
end

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

  @shortdoc "Compiles with Webpack"
  @webpack "./node_modules/webpack/bin/webpack.js"
  def run(_) do
    case compile() do
      {json, 0} ->
        File.write!("priv/webpack.stats.json", json)

      {ret, 2} ->
        require Logger
        ret
        |> Poison.decode!()
        |> Map.fetch!("errors")
        |> Enum.each(&Logger.error/1)
        :error
    end
  end

  def compile() do
    config = "./" <> WebPack.Util.webpack_config
    System.cmd("node", [@webpack, "--config", config, "--json"], into: "", cd: WebPack.Util.web_app)
  end
end

defmodule Mix.Tasks.Reaxt.Validate do
  use Mix.Task
  @shortdoc "Validates that reaxt is set up correctly"

  def run(args) do
    if Enum.all?(args, &(&1 != "--reaxt-skip-validation")) do
      validate(args)
    end
  end

  def validate(args) do
    if WebPack.Util.web_priv == :no_app_specified, do:
      Mix.raise """
                Reaxt :otp_app is not configured.
                Add following to config.exs

                  config :reaxt, :otp_app, :your_app

                """

    packageJsonPath = Path.join(WebPack.Util.web_app, "package.json")
    if not File.exists?(packageJsonPath), do:
      Mix.raise """
                Reaxt could not find a package.json in #{WebPack.Util.web_app}.
                Add package.json to #{WebPack.Util.web_app} or configure a new
                web_app directory in config.exs:

                  config :reaxt, :web_app, "webapp"

                """

    if Poison.decode!(File.read!(packageJsonPath))["dependencies"]["webpack"] == nil, do:
      Mix.raise """
                Reaxt requires webpack as a dependency in #{packageJsonPath}.
                Add a dependency to 'webpack' like:

                  {
                    dependencies: {
                      "webpack": "^1.4.13"
                    }
                  }
                """

    if (Enum.all?(args, &(&1 != "--reaxt-skip-compiler-check"))
        and Enum.all? (Mix.Project.get!).project[:compilers], &(&1 != :reaxt_webpack)), do:
      Mix.raise """
                Reaxt has a built in compiler that compiles the web app.
                Remember to add it to the list of compilers in mix.exs:

                  def project do
                    [...
                      app: :your_app,
                      compilers: [:reaxt_webpack] ++ Mix.compilers,
                      ...]
                  end
                """
  end
end

defmodule Mix.Tasks.Compile.ReaxtWebpack do
  use Mix.Task
  def run(args) do
    Mix.Task.run("reaxt.validate", args ++ ["--reaxt-skip-compiler-check"])

    if !File.exists?(Path.join(WebPack.Util.web_app, "node_modules")) do
      Mix.Task.run("npm.install", args)
    # That form of checking goes against what I'm trying to do.
    # else
    #   installed_version = Poison.decode!(File.read!("#{WebPack.Util.web_app}/node_modules/reaxt/package.json"))["version"]
    #   current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
    #   if  installed_version !== current_version do
    #     Mix.Task.run("npm.install", args)
    #   end
    end

    if !Application.get_env(:reaxt, :hot) do
      Mix.Task.run("webpack.compile", args)
    end

    :ok
  end
end
