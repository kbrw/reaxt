defmodule Mix.Tasks.Reaxt.Validate do
  use Mix.Task

  @moduledoc """
  Validate reaxt setup
  """

  @shortdoc "Validates that reaxt is setup correct"

  @doc false
  def run(args) do
    if Enum.all?(args, &(&1 != "--reaxt-skip-validation")) do
      validate(args)
    end
  end

  defp validate(args) do
    if WebPack.Util.web_priv == :no_app_specified, do:
      Mix.raise """
                Reaxt :otp_app is not configured.
                Add following to config.exs

                  config :reaxt, :otp_app, :your_app

                """

    packageJsonPath = Path.join(WebPack.Util.web_app(), "package.json")
    if not File.exists?(packageJsonPath), do:
      Mix.raise """
                Reaxt could not find a package.json in #{WebPack.Util.web_app()}.
                Add package.json to #{WebPack.Util.web_app()} or configure a new
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
