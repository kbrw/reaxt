var React = require("react")

window.reaxt_render = function(module,submodule,props,param){
  module = require("./../../components/"+module)
  submodule = (submodule) ? module[submodule] :module
  return function(elemid){
    if(submodule.reaxt_client_render){
      submodule.reaxt_client_render(props,elemid,param)
    }else{
      React.withContext(param, function() {
        React.render(React.createElement(submodule,props),document.getElementById(elemid))
      })
    }
  }
}
