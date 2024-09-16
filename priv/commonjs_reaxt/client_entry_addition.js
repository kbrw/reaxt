var React = require("react")
var ReactDOMClient = require("react-dom/client")

function default_client_render(props,render,param){
  render(React.createElement(this,props))
}

window.reaxt_render = function(module,submodule,props,param){
  return import(`./../../components/${module}`).then((module)=>{
    module = module.default
    submodule = (submodule) ? module[submodule] :module
    submodule.reaxt_client_render = submodule.reaxt_client_render || default_client_render
    return function(elemid) {
      let root = null
      submodule.reaxt_client_render(props, function(component, args) {
        if (root === null) {
          const container = document.getElementById(elemid)
          root = ReactDOMClient.hydrateRoot(container, component)
        } else {
          root.render(component)
        }
      },param)
    }
  })
}
