var Server = require('node_erlastic').server,
    ReactDOMServer = require("react-dom/server"),
    React = require("react"),
	Bert = require('node_erlastic/bert'),
    Domain = require('domain')
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
    var html = ReactDOMServer.renderToString(component)
    return Bert.tuple(Bert.atom("ok"),{
      html: html,
      js_render: js_render,
      param: param
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
var current_ref = 0
Server(function(term,from,state,done){
  var module=term[1].toString(), submodule=term[2].toString(), args=term[3], timeout=term[4]

  var timeout_handler = setTimeout(function(){
    done("reply",Bert.tuple(Bert.atom("error"),Bert.tuple(Bert.atom("handler_error"),"timeout",Bert.atom("nil"))))
  },timeout)

  import(`./../../components/${module}`).then((handler)=>{
    handler = handler.default
    submodule = (submodule == "nil") ? undefined : submodule
    handler = (!submodule) ? handler : handler[submodule]

    handler.reaxt_server_render = handler.reaxt_server_render || default_server_render
    current_ref++
    return (function(ref){
      return handler.reaxt_server_render(args,function(component,param,callback){
        clearTimeout(timeout_handler)
        if(ref === current_ref){
          done("reply",rendering(component,module,submodule,param))
        }
      })
    })(current_ref)
  },(error)=>{
    clearTimeout(timeout_handler)
    done("reply",Bert.tuple(Bert.atom("error"),Bert.tuple(
      Bert.atom("handler_error"),
      error.toString(), 
      (error.stack && error.stack || Bert.atom("nil"))
    )))
  }).catch((error)=>{
    clearTimeout(timeout_handler)
    done("reply",Bert.tuple(Bert.atom("error"),Bert.tuple(
      Bert.atom("handler_error"),
      error.toString(), 
      (error.stack && error.stack || Bert.atom("nil"))
    )))
  })
},function(init){
  global.global_reaxt_config = JSON.parse(init)
  return null
})
