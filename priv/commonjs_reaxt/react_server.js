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

function build_js_render(handler,props,module,submodule){
  if(module === undefined){
    if(handler.filename === undefined){
      throw new Error("cannot use dyn_handler with component in a module property, it must be an entire module")
    }
    module = handler.filename.split('components/')[1]
  }
  module = '"'+module+'"'
  submodule = (submodule) ? ('"'+submodule+'"') : 'null'
  return "(window.reaxt_render("+module+","+submodule+","+safe_json_props(props)+"))"
}

var normal_write = process.stdout.write
function reaxt_render(handler,props,module,submodule){
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
      js_render: build_js_render(handler,props,module,submodule)
    })
  }catch(error){
    process.stdout.write = normal_write
    return Bert.tuple(
             Bert.atom("error"),
               Bert.tuple(
                 Bert.atom("render_error"),
                 error.toString(),
                 (error.stack && error.stack || Bert.atom("nil")),
                 build_js_render(handler,props,module,submodule) ))
  }
}

// protocol : 
// call {:render_tpl | :render_dyn_tpl, module, submodule | nil, arg}
// - if :render_tpl, take handler from require("components/{module}") or require("template/{module}")[submodule]
//   then reply {:ok,%{html: ReactRenderingOf(handler,arg),js_render: renderingjs,css: css}}
// - if :render_dyn_tpl, take a handler selector function from require("template/{module}") or require("template/{module}")[submodule]
//   this function must take 2 arguments : arg, callback, must find an appropriate handler and call
//   callback(handler,prop) to reply the same as :render_tpl
// if error reply {:error, {:render_error,error,stack,renderingjs} | {:handler_error,error,stack}}
Server(function(term,from,state,done){
  try{
    var type=term[0], module=term[1], submodule=term[2], args=term[3],
        handler = require("./../../components/"+module),
    submodule = (submodule == "nil") ? undefined : submodule
    handler = (!submodule) ? handler : handler[submodule]
    if (type == "render_tpl")
      done("reply", reaxt_render(handler,args,module,submodule))
    else if (type == "render_dyn_tpl")
      handler(args,function(dynhandler,props){
        done("reply",reaxt_render(dynhandler,props)) })
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
