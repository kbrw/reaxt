defmodule WebPack do
  @moduledoc """
  This module is supposed to be regenerated at runtime by `WebPack.Util.build_stats/0`
  """

  @doc """
  Returns stats as from webpack.stats.json
  """
  @spec stats() :: map
  def stats, do: %{assetsByChunkName: %{}}

  @doc """
  Returns file name where is defined given asset
  """
  @spec file_of(asset :: String.t) :: nil | Path.t
  def file_of(_), do: nil

  @doc """
  Returns header for including stats into webpage
  """
  @spec header() :: String.t
  def header, do: ""
end
