defmodule Hello.App do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Hello.Api, [], port: 8098),
    ]

    Reaxt.reload()
    Supervisor.start_link(children, [strategy: :one_for_one, name: __MODULE__])
  end
end

defmodule Hello.Api do
  require EEx
  use Plug.Router
  
  if Mix.env == :dev do
    use Plug.Debugger
    plug WebPack.Plug.Static, at: "/public", from: :hello
  else
    plug Plug.Static, at: "/public", from: :hello
  end

  plug :match
  plug :dispatch

  EEx.function_from_file :defp, :layout, "web/layout.html.eex", [:render]

  get "*_" do
    data = %{path: conn.request_path, cookies: conn.cookies, query: conn.params, headers: conn.req_headers}
    render = Reaxt.render!(:app, data, 30_000)
    conn = put_resp_header(conn, "content-type", "text/html;charset=utf-8")
    send_resp(conn, render.param || 200, layout(render))
  end
end
