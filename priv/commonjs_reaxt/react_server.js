var React = require('react'), 
    Server = require('node_erlastic').server,
	Bert = require('node_erlastic/bert'),
    styleCollector = require("./style-collector")
Bert.all_binaries_as_string = true

function safe_json_props(props){
  return JSON.stringify(props)
         .replace(/<\/script/g, '<\\/script')
         .replace(/<!--/g, '<\\!--')
}

var normal_write = process.stdout.write
function render_props(handler,props){
  try{
    var html
    process.stdout.write = function(){}
    var css = styleCollector.collect(function() {
      html = React.renderToString(React.createElement(handler,props))
    })
    process.stdout.write = normal_write
    return Bert.tuple(Bert.atom("ok"),{
      html: html,
      css: css,
      init_props: safe_json_props(props)
    })
  }catch(error){
    return Bert.tuple(
             Bert.atom("error"),
               Bert.tuple(
                 Bert.atom("render_error"),
                 error.toString(),
                 (error.stack && error.stack || Bert.atom("nil")),
                 safe_json_props(props) ))
  }
}

// protocol : 
// call {:render_tpl | :render_dyn_tpl, module, submodule | nil, arg}
// - if :render_tpl, take handler from require("components/{module}") or require("template/{module}")[submodule]
//   then reply {:ok,%{html: ReactRenderingOf(handler,arg),init_props: json(arg)}}
// - if :render_dyn_tpl, take a handler selector function from require("template/{module}") or require("template/{module}")[submodule]
//   this function must take 2 arguments : arg, callback, must find an appropriate handler and call
//   callback(handler,prop) to reply the same as :render_tpl
// if error reply {:error, {:render_error,error,stack,props} | {:handler_error,error,stack}}
Server(function(term,from,state,done){
  try{
    var type = term[0],
        module = require("./../../components/"+term[1]),
        submodule = (term[2] == "nil") ? module : module[term[2]]
    if (type == "render_tpl")
      done("reply", render_props(submodule,term[3]))
    else if (type == "render_dyn_tpl")
      submodule(term[3],function(handler,props){
        done("reply",render_props(handler,props)) })
    else throw new Error("unexpected request")
  }catch(error){
      done("reply", 
       Bert.tuple(
         Bert.atom("error"),
           Bert.tuple(
             Bert.atom("handler_error"),
             error.toString(),
             (error.stack && error.stack || Bert.atom("nil")))))
  }
})
