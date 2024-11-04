defmodule Reaxt.Utils do
  @moduledoc """

  """

  @doc "Return the priv directory of the otp_app using Reaxt"
  def web_priv do
    case Application.get_env(:reaxt, :otp_app, :no_app_specified) do
      :no_app_specified ->
        :no_app_specified

      web_app ->
        :code.priv_dir(web_app)
    end
  end

  @doc "Return the name of the directory containing the Web application"
  def web_app do
    Application.get_env(:reaxt, :web_app, "web")
  end

  @doc "Return the bundler used by Reaxt. Default is :webpack"
  def bundler() do
    Application.get_env(:reaxt, :bundler, :webpack)
  end

  @doc "Return true if the configured bundler is webpack"
  def is_webpack?() do
    bundler() == :webpack
  end

  @doc "Return true if the Hot reload capacity is enabled"
  def is_hot?() do
    Application.get_env(:reaxt, :hot, false)
  end

  @doc "Return the path to the react_servers directory"
  def server_dir() do
    Application.get_env(:reaxt, :server_dir, "react_servers")
  end

  @doc "Return the size of the Poolboy pool for SSR"
  def pool_size() do
    Application.get_env(:reaxt, :pool_size, 1)
  end

  def max_pool_overflow() do
    Application.get_env(:reaxt, :pool_max_overflow, 5)
  end
end
