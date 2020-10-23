var React = require("react")
var ReactDOM = require("react-dom")

function default_client_render(props,render,param){
  render(React.createElement(this,props))
}

window.reaxt_render = function(module,submodule,props,param){
  return import(`./../../components/${module}`).then((module)=>{
    module = module.default
    submodule = (submodule) ? module[submodule] :module
    submodule.reaxt_client_render = submodule.reaxt_client_render || default_client_render
    return function(elemid){
      submodule.reaxt_client_render(props,function(comp,args,callback){
        ReactDOM.hydrate(comp,document.getElementById(elemid),callback)
      },param)
    }
  })
}
