var React = require('react'), 
    Server = require('node_erlastic').server,
	Bert = require('node_erlastic/bert')
Bert.all_binaries_as_string = true

function safe_json_props(props){
  return JSON.stringify(props)
         .replace(/<\/script/g, '<\\/script')
         .replace(/<!--/g, '<\\!--')
}

function render_props(handler,props){
  return {
    html: React.renderToString(React.createElement(handler,props)),
    init_props: safe_json_props(props)
  }
}

Server(function(term,from,state,done){
  var type = term[0],
      module = require("./../../templates/"+term[1]),
      submodule = (term[2] == "nil") ? module : module[term[2]]
  if (type == "render_tpl")
    done("reply", render_props(submodule,term[3]))
  else if (type == "render_dyn_tpl")
    submodule(term[3],function(handler,props){
      done("reply",render_props(handler,props)) })
  else throw new Error("unexpected request")
})
