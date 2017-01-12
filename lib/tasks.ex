defmodule Reaxt.Build.Utils do
  def info(action, msg, color \\ :reset) do
    msg = [
      IO.ANSI.format_fragment([color], true),
      String.pad_leading(String.upcase("#{action} "), 8),
      IO.ANSI.format_fragment([:reset], true),
      msg,
    ] |> IO.iodata_to_binary
    Mix.shell.info(msg)
  end

  def cmd(cmdname, args, {logname, logtarget}, opts \\ []) do
    case System.cmd(cmdname, args, opts) do
      {_, 0} ->
	info(logname, "#{logtarget}", :green)
	:ok
      {out, _} ->
	info(logname, "#{logtarget} (FAILED)", :red)
	Mix.shell.error(out)
	:error
    end
  end
end

defmodule Mix.Tasks.Npm.Install do
  import Reaxt.Build.Utils
  
  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    :ok = cmd("npm",["install"], {:install, "#{WebPack.Util.web_app}"},
      cd: WebPack.Util.web_app)
    :ok = cmd("npm",["install", "#{:code.priv_dir(:reaxt)}/commonjs_reaxt"],
      {:install, "#{:code.priv_dir(:reaxt)}/commonjs_reaxt"}, cd: WebPack.Util.web_app)
  end
end

defmodule Mix.Tasks.Webpack.Analyseapp do
  import Reaxt.Build.Utils
  
  @shortdoc "Generate webpack stats analysing application, resulting priv/static is meant to be versionned"
  def run(_args) do
    File.rm_rf!("priv/static")
    :ok = cmd("git",["clone","-b","ajax-sse-loading","https://github.com/awetzel/analyse"],
      {:git, "clone analyse"}, stderr_to_stdout: true)
    :ok = cmd("npm",["install"],
      {:install, "analyse"}, cd: "analyse")
    :ok = cmd("grunt",[],
      {:grunt, "analyse"}, cd: "analyse")
    File.cp_r!("analyse/dist", "priv/static")
    File.rm_rf!("analyse")
  end
end

defmodule Mix.Tasks.Webpack.Compile do
  import Reaxt.Build.Utils
  
  @shortdoc "Compiles Webpack"
  @webpack "./node_modules/webpack/bin/webpack.js"
  def run(_) do
    {_res,0} = compile_server
    {json,0} = compile_client
    File.write!("priv/webpack.stats.json",json)
  end
  def compile_server() do
    server_config = "./node_modules/reaxt/server.webpack.config.js"
    :ok = cmd("node",[@webpack,"--config",server_config,"--colors"],
      {:build, "#{WebPack.Util.web_app} / server"},
      cd: WebPack.Util.web_app)
  end
  def compile_client() do
    client_config = "./node_modules/reaxt/client.webpack.config.js"
    :ok = cmd("node", [@webpack,"--config",client_config,"--json"],
      {:build, "#{WebPack.Util.web_app} / client"},
      cd: WebPack.Util.web_app)
  end
end

defmodule Mix.Tasks.Reaxt.Validate do
  @shortdoc "Validates that reaxt is setup correct"
  use Mix.Task

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
  def run(args) do
    Mix.Task.run("reaxt.validate", args ++ ["--reaxt-skip-compiler-check"])

    if !File.exists?(Path.join(WebPack.Util.web_app, "node_modules")) do
      Mix.Task.run("npm.install", args)
    else
      installed_version = Poison.decode!(File.read!("#{WebPack.Util.web_app}/node_modules/reaxt/package.json"))["version"]
      current_version = Poison.decode!(File.read!("#{:code.priv_dir(:reaxt)}/commonjs_reaxt/package.json"))["version"]
      if  installed_version !== current_version, do:
        Mix.Task.run("npm.install", args)
    end

    if !Application.get_env(:reaxt,:hot), do:
      Mix.Task.run("webpack.compile", args)
  end
end
