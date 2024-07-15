defmodule Reaxt.Mixfile do
  use Mix.Project

  def version, do: "4.0.3"

  defp description do
    """
    Use your react components into your elixir application, using webpack compilation.
    """
  end

  def project do
    [
      app: :reaxt,
      version: version(),
      description: description(),
      package: package(),
      elixir: ">= 1.10.0",
      deps: deps(),
      docs: docs(),
      source_url: git_repository(),
    ]
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
     {:ex_doc, "~> 0.24", only: :dev, runtime: false}]
  end

  defp package do
    [
      licenses: ["The MIT License (MIT)"],
      links: %{
        "GitHub" => git_repository(),
        "Changelog" => "https://hexdocs.pm/reaxt/changelog.html",
      },
      maintainers: ["Arnaud Wetzel"],
    ]
  end

  def docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "README.md": [title: "Overview"],
      ],
      api_reference: false,
      main: "readme",
      source_url: git_repository(),
      source_ref: "v#{version()}",
    ]
  end

  defp git_repository do
    "https://github.com/kbrw/reaxt"
  end
end
