var React = require("react")

window.reaxt_render = function(module,submodule,props,render_fun){
  try{
    module = require("./../../components/"+module)
    submodule = (submodule) ? module[submodule] :module
  }catch(e){
    submodule = null
  }
  return function(elemid){
    if(render_fun){
      render_fun(props,submodule,elemid)
    }else{
      React.render(React.createElement(submodule,props),document.getElementById(elemid))
    }
  }
}
