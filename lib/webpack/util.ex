defmodule WebPack.Util do
  @moduledoc """
  Utility functions for webpack
  """

  @doc """
  Returns webpack.config.js file name
  """
  @spec webpack_config :: Path.t
  def webpack_config do
    Application.get_env(:reaxt, :webpack_config, "webpack.config.js")
  end

  @doc """
  Returns path to app web dir, or :no_app_specified
  """
  @spec web_priv() :: Path.t | :no_app_specified
  def web_priv do
    case Application.get_env :reaxt, :otp_app, :no_app_specified do
      :no_app_specified -> :no_app_specified
      web_app -> :code.priv_dir(web_app)
    end
  end

  @doc """
  Returns web app source dir
  """
  @spec web_app() :: Path.t
  def web_app do
    Application.get_env :reaxt, :web_app, "web"
  end

  @doc """
  Rebuild `WebPack` module with data from `webpack.stats.json` 

  Returns :ok but produces `WebPack` module as a side effect
  """
  @spec build_stats :: :ok
  def build_stats do
    src = "#{web_priv()}/webpack.stats.json"
    if File.exists?(src) do
      do_build_stats(src)
    else
      :ok
    end
  end

  ###
  ### Priv
  ###
  defp do_build_stats(src) do    
    all_stats = File.read!(src) |> Poison.Parser.parse!()
    stats = all_stats["children"] |> Enum.with_index() |> Enum.into(%{}, fn {stats, idx} ->
      {idx, %{assetsByChunkName: stats["assetsByChunkName"],
              errors: stats["errors"],
              warnings: stats["warnings"]}}
    end)
    
    _ = Code.compiler_options(ignore_module_conflict: true)
    defmodule Elixir.WebPack do
      @stats stats

      @doc false
      def stats, do: @stats

      @doc false
      def file_of(name) do
        r = Enum.find_value(WebPack.stats(),
          fn {_, %{assetsByChunkName: assets}} ->
            assets["#{name}"]
          end)
        case r do
          [f | _] -> f
          f -> f
        end
      end
      
      @header_script if(Application.get_env(:reaxt, :hot), do: ~s(<script src="/webpack/client.js"></script>))
      @header_global Poison.encode!(Application.get_env(:reaxt, :global_config))
      
      def header do
	"<script>window.global_reaxt_config=#{@header_global}</script>\n#{@header_script}"
      end
    end
    _ = Code.compiler_options(ignore_module_conflict: false)
  end
end
