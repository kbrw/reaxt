defmodule Reaxt.Esbuild do

  def esbuild_config do
    Application.get_env(:reaxt, :webpack_config, "build.js")
  end

end

defmodule Reaxt.Esbuild.Compiler do
  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]} }
  end
  def start_link(_) do
    cmd = "node ./node_modules/reaxt/webpack_server #{WebPack.Util.webpack_config}"
    hot_arg = if Application.get_env(:reaxt,:hot) == :client, do: " hot",else: ""
    Exos.Proc.start_link(cmd<>hot_arg,[],[cd: Reaxt.Utils.web_app],[name: __MODULE__],&WebPack.Events.dispatch/1)
  end
end
