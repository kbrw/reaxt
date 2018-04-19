defmodule Reaxt.Mixfile do
  use Mix.Project

  def project, do: [
    app: :reaxt,
    version: "2.0.0",
    description: description(),
    package: package(),
    elixir: ">= 1.0.0",
    compilers: Mix.compilers(),
    deps: deps(),
    aliases: aliases()
  ]

  def application, do: [
    mod: {Reaxt.App,[]},
    extra_applications: [:logger],
    env: [
      otp_app: :reaxt, #the OTP application containing compiled JS server
      hot: false, # false | true | :client hot compilation and loading
      pool_size: 1, #pool size of react renderes
      webpack_config: "webpack.config.js",
      server_dir: "react_servers",
      pool_max_overflow: 5 #maximum pool extension when the pool is full
    ]
  ]

  defp deps, do: [
    {:nox, "~> 0.3"},
    {:exos, "~> 1.0"},
    {:poolboy, "~> 1.5.0"},
    {:cowboy,"~> 1.0.0"},
    {:plug, "~> 1.0"},
    {:poison,"~> 3.1"},
    {:ex_doc, ">= 0.0.0", only: :dev}
  ]

  defp aliases, do: []

  defp package, do: [
    maintainers: ["Arnaud Wetzel"],
    licenses: ["The MIT License (MIT)"],
    links: %{ "GitHub"=>"https://github.com/awetzel/reaxt"}
  ]
  
  defp description, do: """
  Use your react components into your elixir application, using webpack compilation.
  """
end
