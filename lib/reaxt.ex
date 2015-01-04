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
