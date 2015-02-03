var React = require('react'),
    Server = require('node_erlastic').server,
	Bert = require('node_erlastic/bert'),
    styleCollector = require("./style-collector")
Bert.all_binaries_as_string = true

function safe_stringify(props){
  return JSON.stringify(props)
         .replace(/<\/script/g, '<\\/script')
         .replace(/<!--/g, '<\\!--')
}

function rendering(component,module,submodule,param){
  var render_params = safe_stringify([module,submodule,component.props,param])
  var js_render = "(window.reaxt_render.apply(window,"+render_params+"))"
  try{
    var html
    var css = styleCollector.collect(function() {
      html = React.renderToString(component)
    })
    return Bert.tuple(Bert.atom("ok"),{
      html: html,
      css: css,
      js_render: js_render
    })
  }catch(error){
    return Bert.tuple(
             Bert.atom("error"),
               Bert.tuple(
                 Bert.atom("render_error"),
                 error.toString(),
                 (error.stack && error.stack || Bert.atom("nil")),
                 js_render ))
  }
}

function default_server_render(arg,render){
  render(React.createElement(this,arg))
}

// protocol :
// call {:render, module, submodule | nil, arg}
// - if :render_tpl, take handler from require("components/{module}") or require("template/{module}")[submodule]
//   then reply {:ok,%{html: ReactRenderingOf(handler,arg),js_render: renderingjs,css: css}}
// if error reply {:error, {:render_error,error,stack,renderingjs} | {:handler_error,error,stack}}
Server(function(term,from,state,done){
  try{
    var type=term[0], module=term[1].toString(), submodule=term[2].toString(), args=term[3],
        handler = require("./../../components/"+module)
    submodule = (submodule == "nil") ? undefined : submodule
    handler = (!submodule) ? handler : handler[submodule]
    handler.reaxt_server_render = handler.reaxt_server_render || default_server_render
    handler.reaxt_server_render(args,function(component,param){
      done("reply",rendering(component,module,submodule,param))
    })
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
