var React = require("react")

window.reaxt_render = function(module,submodule,props){
  module = require("./../../components/"+module)
  submodule = (submodule) ? module[submodule] :module
  return function(elemid){
    React.render(React.createElement(submodule,props),document.getElementById(elemid))
  }
}
