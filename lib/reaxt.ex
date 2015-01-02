defmodule Reaxt do
  alias :poolboy, as: Pool

  def render(module,data), do:
    render(module,data, dyn_handler: false)
  def render(module,data,opts) when not is_tuple(module), do:
    render({module,nil},data,opts)
  def render({module,submodule},data,opts) do
    req = if opts[:dyn_handler], do: :render_dyn_tpl, else: :render_tpl
    Pool.transaction(:react,fn worker->
      GenServer.call(worker,{req,module,submodule,data})
    end)
  end

  def start_link([]) do
    web_app = Application.get_env :reaxt, :otp_app
    GenServer.start_link(Exos.Proc,{"node server",nil,[cd: '#{:code.priv_dir(web_app)}']})
  end

  defmodule App do
    use Application
    def start(_,_), do: Supervisor.start_link(App.Sup,[], name: App.Sup)
    defmodule Sup do
      use Supervisor
      def init([]) do
        supervise([
          Pool.child_spec(:react,[worker_module: Reaxt,size: 1, max_overflow: 10, name: {:local,:react}], [])
        ], strategy: :one_for_one)
      end
    end
  end
end

defmodule Mix.Tasks.Npm.Install do
  @shortdoc "`npm install` in web_dir + npm install server side dependencies"
  def run(args) do
    web_dir = Mix.Project.config[:web_dir] || "web"
    System.cmd("npm",["install"], into: IO.stream(:stdio, :line), cd: web_dir)
    System.cmd("npm",["install","#{:code.priv_dir(:reaxt)}/react_server"], into: IO.stream(:stdio, :line), cd: web_dir)
  end
end

defmodule Mix.Tasks.Webpack.Compile do
  @shortdoc "Compiles Webpack"
  def run(_) do
    web_dir = Mix.Project.config[:web_dir] || "web"
    if !File.exists?(web_dir<>"/node_modules") do
      Mix.shell.info "javascript dependencies are missing : run `mix npm.install` to get them"
    else
      webpack = "./node_modules/react_server/node_modules/webpack/bin/webpack.js"
      server_config = "./node_modules/react_server/server.webpack.config.js"
      System.cmd("node",[webpack,"--config",server_config,"--colors"], into: IO.stream(:stdio, :line), cd: web_dir)
      System.cmd("node",[webpack,"--colors"], into: IO.stream(:stdio, :line), cd: web_dir)
    end
  end
end

defmodule Mix.Tasks.Compile.Reaxt_npm do
  def run(args) do
    Mix.Task.run "npm.install", args
  end
end
defmodule Mix.Tasks.Compile.Reaxt_webpack do
  def run(args) do
    Mix.Task.run "webpack.compile", args
  end
end
