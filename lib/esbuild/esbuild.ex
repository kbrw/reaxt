defmodule Reaxt.Esbuild do
  @moduledoc """
  Utilities functions to fetch specific esbuild configs
  """

  def esbuild_config do
    Application.get_env(:reaxt, :esbuild_config, "build.js")
  end
end
