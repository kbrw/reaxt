defmodule WebPack.Compiler do
  @moduledoc """
  webpack compiler
  """
  alias Reaxt.Env

  @doc false
  def start_link do
    exe = Nox.which(Env.get(), "node")
    cmd = "#{exe} ./node_modules/reaxt/webpack_server #{WebPack.Util.webpack_config()}"
    cmd = if Application.get_env(:reaxt, :hot) == :client do
      cmd <> " hot"
    else
      cmd
    end
    Exos.Proc.start_link(cmd, [], [cd: WebPack.Util.web_app()], [name: __MODULE__], WebPack.Events)
  end
end
