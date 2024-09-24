defmodule Reaxt.Utils do
  def web_priv do
    case Application.get_env :reaxt, :otp_app, :no_app_specified do
      :no_app_specified ->
        :no_app_specified
      web_app ->
        :code.priv_dir(web_app)
    end
  end

  def bundler() do
    Application.get_env(:reaxt, :bundler, :webpack)
  end

  def is_webpack?() do
    bundler() == :webpack
  end

  def server_dir() do
    Application.get_env(:reaxt, :server_dir, "react_servers")
  end

  def pool_size() do
    Application.get_env(:reaxt, :pool_size, 1)
  end

  def max_pool_overflow() do
    Application.get_env(:reaxt, :pool_max_overflow, 5)
  end

  def web_app do
    Application.get_env(:reaxt, :web_app, "web")
  end
end
