defmodule Reaxt.Utils do
  def web_priv do
    case Application.get_env :reaxt, :otp_app, :no_app_specified do
      :no_app_specified ->
        :no_app_specified
      web_app ->
        :code.priv_dir(web_app)
    end
  end

  def web_app do
    Application.get_env(:reaxt, :web_app, "web")
  end
end
