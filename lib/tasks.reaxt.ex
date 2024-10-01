defmodule Mix.Tasks.Npm.Install do
  use Mix.Task

  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(_args) do
    System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: Reaxt.Utils.web_app)
    # TOIMPROVE- did not found a better hack to avoid npm install symlink : first make a tar gz package, then npm install it
    reaxt_tgz = "#{System.tmp_dir}/reaxt.tgz"
    System.cmd("tar", ["zcf", reaxt_tgz, "commonjs_reaxt"],into: IO.stream(:stdio, :line), cd: "#{:code.priv_dir(:reaxt)}")
    System.cmd("npm",["install", "--no-save", reaxt_tgz], into: IO.stream(:stdio, :line), cd: Reaxt.Utils.web_app)
  end
end

defmodule Mix.Tasks.Reaxt.Validate do
  use Mix.Task

  @shortdoc "Validates that reaxt is setup correct"
  def run(args) do
    if Enum.all?(args, &(&1 != "--reaxt-skip-validation")) do
      validate(args)
    end
  end

  def validate(args) do
    if Reaxt.Utils.bundler() not in [:webpack, :esbuild], do:
      Mix.raise """
              Reaxt :bundler is not configured.
              Add following to config.exs

                config :reaxt, :bundler, :webpack
                OR
                config :reaxt, :bundler, :esbuild
              """

    if Reaxt.Utils.web_priv == :no_app_specified, do:
      Mix.raise """
                Reaxt :otp_app is not configured.
                Add following to config.exs

                  config :reaxt, :otp_app, :your_app

                """

    packageJsonPath = Path.join(Reaxt.Utils.web_app(), "package.json")
    if not File.exists?(packageJsonPath), do:
      Mix.raise """
                Reaxt could not find a package.json in #{Reaxt.Utils.web_app}.
                Add package.json to #{Reaxt.Utils.web_app} or configure a new
                web_app directory in config.exs:

                  config :reaxt, :web_app, "webapp"

                """

    packageJson = Poison.decode!(File.read!(packageJsonPath))
    if packageJson["devDependencies"]["webpack"] == nil, do:
      Mix.raise """
                Reaxt requires webpack as a devDependency in #{packageJsonPath}.
                Add a dependency to 'webpack' like:

                  {
                    devDependencies: {
                      "webpack": "^1.4.13"
                    }
                  }
                """

    good_compilers = [:reaxt_webpack, :reaxt_esbuild]
    if (Enum.all?(args, &(&1 != "--reaxt-skip-compiler-check"))
        and not Enum.any?((Mix.Project.get!).project[:compilers], &(&1 in good_compilers))), do:
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
