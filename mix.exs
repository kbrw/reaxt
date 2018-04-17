defmodule Reaxt.Mixfile do
  use Mix.Project

  def project do
    [app: :reaxt,
     version: "2.0.0",
     description: description,
     package: package,
     elixir: ">= 1.0.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :poolboy, :exos],
     mod: {Reaxt.App,[]},
     env: [
       otp_app: :reaxt, #the OTP application containing compiled JS server
       hot: false, # false | true | :client hot compilation and loading
       pool_size: 1, #pool size of react renderes
       webpack_config: "webpack.config.js",
       server_dir: "react_servers",
       pool_max_overflow: 5 #maximum pool extension when the pool is full
     ]]
  end

  defp deps do
    [{:nox, ">= 0.0.0"},
     {:exos, "1.0.0"},
     {:poolboy, "~> 1.5.0"},
     {:cowboy,"~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:poison,"~> 3.1"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [ maintainers: ["Arnaud Wetzel"],
      licenses: ["The MIT License (MIT)"],
      links: %{ "GitHub"=>"https://github.com/awetzel/reaxt"} ]
  end

  defp description do
    """
    Use your react components into your elixir application, using webpack compilation.
    """
  end
end
