defmodule Reaxt.Index.Generator do
  @moduledoc """
  Utils functions to overlaod the Reaxt.Index module for the WebPack configuration
  """

  def build_webpack_stats do
    if File.exists?("#{Reaxt.Utils.web_priv()}/webpack.stats.json") do
      all_stats = Poison.decode!(File.read!("#{Reaxt.Utils.web_priv()}/webpack.stats.json"))
      stats_array = all_stats["children"]

      stats =
        Enum.map(stats_array, fn stats ->
          %{
            assetsByChunkName: stats["assetsByChunkName"],
            errors: stats["errors"],
            warnings: stats["warnings"]
          }
        end)

      _ = Code.compiler_options(ignore_module_conflict: true)

      defmodule Elixir.Reaxt.Index do
        @stats stats
        def stats, do: @stats

        def file_of(name) do
          r =
            Enum.find_value(WebPack.stats(), fn %{assetsByChunkName: assets} ->
              assets["#{name}"]
            end)

          case r do
            [f | _] -> f
            f -> f
          end
        end

        @header_script if(Reaxt.Utils.is_hot?(),
                         do: ~s(<script src="/webpack/client.js"></script>)
                       )
        @header_global Poison.encode!(Reaxt.Render.get_global_config())

        def header do
          "<script>window.global_reaxt_config=#{@header_global}</script>\n#{@header_script}"
        end
      end

      _ = Code.compiler_options(ignore_module_conflict: false)
    end
  end
end

defmodule Elixir.Reaxt.Index do
  @moduledoc """
  Functions to help construct the index.html to serve
  """
  def stats, do: %{assetsByChunkName: %{}}
  def file_of(_), do: nil

  def header do
    global_config = Poison.encode!(Reaxt.Render.get_global_config())
    "<script>window.global_reaxt_config=#{global_config}</script>"
  end
end
