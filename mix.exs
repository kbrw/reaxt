defmodule Reaxt.Mixfile do
  use Mix.Project

  def project do
    [app: :reaxt,
     version: "0.1.0",
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
     {:plug,"~> 0.9.0"},
     {:poison,"1.3.0"}]
  end

  defp package do
    [ contributors: ["Arnaud Wetzel"],
      licenses: ["The MIT License (MIT)"],
      links: %{ "GitHub"=>"https://github.com/awetzel/reaxt"} ]
  end

  defp description do
    """
    Use your *react* components into your elixir application, using webpack compilation, so :
    
    - An isomorphic ready library (SEO/JS are now nice together), but with Elixir on the server side
    - Just a Library, with a minimum constraint about your application organization and layout :
      - use any javascript compiled language
      - use any javascript routing logic or library
      - you can use JS React rendered component only for parts of your webpage
    - Nice fluent dev workflow, with :
      - combined stacktrace : elixir | javascript
      - hot loading on both server and browser
      - NPM/Webpack as the only config for respectively dependencies/compilation
      - A cool UI to have an overview of your compiled javascript application
      - You do not have to think about the server side Javascript configuration, 
        just write a webpack conf for the browser, and it is ready to use.
    """
  end
end
