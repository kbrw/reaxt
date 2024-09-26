defmodule Reaxt.Esbuild do

  def esbuild_config do
    Application.get_env(:reaxt, :esbuild_config, "build.js")
  end

end
