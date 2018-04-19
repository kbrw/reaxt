defmodule WebPack.Util do
  def webpack_config do
    Application.get_env(:reaxt,:webpack_config,"webpack.config.js")
  end

  def web_priv do
    case Application.get_env :reaxt, :otp_app, :no_app_specified do
      :no_app_specified -> :no_app_specified
      web_app -> :code.priv_dir(web_app)
    end
  end

  def web_app do
    Application.get_env :reaxt, :web_app, "web"
  end

  def build_stats do
    if File.exists?("#{web_priv}/webpack.stats.json") do
      all_stats = Poison.Parser.parse!(File.read!("#{web_priv}/webpack.stats.json"))
      stats = all_stats["children"] |> Enum.with_index |> Enum.into(%{},fn {stats,idx}->
         {idx,%{assetsByChunkName: stats["assetsByChunkName"],
                errors: stats["errors"],
                warnings: stats["warnings"]}}
      end)
      defmodule Elixir.WebPack do
        @stats stats
        def stats, do: @stats
        def file_of(name) do
          r = Enum.find_value(WebPack.stats,
            fn {_,%{assetsByChunkName: assets}}->
              assets["#{name}"]
            end)
          case r do
            [f|_]->f
            f -> f
          end
        end
        @header_script if(Application.get_env(:reaxt,:hot), do: ~s(<script src="/webpack/client.js"></script>))
        @header_global Poison.encode!(Application.get_env(:reaxt,:global_config))
        def header, do:
          "<script>window.global_reaxt_config=#{@header_global}</script>\n#{@header_script}"
      end
    end
  end
end

defmodule Elixir.WebPack do
  def stats, do: %{assetsByChunkName: %{}}
  def file_of(_), do: nil
  def header, do: ""
end
