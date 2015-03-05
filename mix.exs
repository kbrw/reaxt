defmodule Reaxt.Mixfile do
  use Mix.Project

  def project do
    [app: :reaxt,
     version: "0.2.5",
     description: description,
     package: package,
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :poolboy, :exos],
     mod: {Reaxt.App,[]},
     env: [
       otp_app: :reaxt, #the OTP application containing compiled JS server
       hot: false, # false | true | :client hot compilation and loading
       pool_size: 1, #pool size of react renderes
       pool_max_overflow: 5 #maximum pool extension when the pool is full
     ]]
  end

  defp deps do
    [{:exos, "1.0.0"},
     {:poolboy, []},
     {:cowboy,"~> 1.0.0"},
     {:plug,"~> 0.10.0"},
     {:poison,"1.3.0"}]
  end

  defp package do
    [ contributors: ["Arnaud Wetzel"],
      licenses: ["The MIT License (MIT)"],
      links: %{ "GitHub"=>"https://github.com/awetzel/reaxt"} ]
  end

  defp description do
    """
    Use your react components into your elixir application, using webpack compilation.
    """
  end
end
