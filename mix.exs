defmodule Reaxt.Mixfile do
  use Mix.Project

  def project do
    [app: :reaxt,
     version: "4.0.2-rc.1",
     description: description(),
     package: package(),
     elixir: ">= 1.10.0",
     deps: deps()]
  end

  def application do
    [applications: [:logger, :poolboy, :exos, :plug, :poison],
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
    [{:exos, "~> 2.0"},
     {:poolboy, "~> 1.5.0"},
     {:plug, "~> 1.10"},
     {:poison,"~> 4.0"},
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
