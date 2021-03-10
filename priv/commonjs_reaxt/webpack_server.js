var webpack = require("webpack"), 
    port = require('@kbrw/node_erlastic').port,
    server = require('@kbrw/node_erlastic').server

var multi_config = require(process.cwd()+"/"+process.argv[2])

//if(process.argv[2] === "hot"){
//    // add hotmodule plugin to client
//    client_config.plugins = (client_config.plugins || []).concat([new webpack.HotModuleReplacementPlugin()])
//    // add reloading code to entries
//    client_config.add_to_entries(client_config,"webpack/hot/dev-server")
//    // remove external which cause conflicts in hot loading
//    client_config.externals = {}
//}

var client_stats,client_err
function maybe_done() {
  if(client_err) port.write({event: "client_done", error: JSON.stringify(client_err)})
  else if(client_stats.hasErrors()) port.write({event: "client_done", error: "soft fail", error_details: client_stats.toJson('errors-warnings')})
  else    port.write({event: "client_done"})
}

var multi_compiler = webpack(multi_config)

for (const compiler of multi_compiler.compilers) {
  compiler.hooks.failed.tap("ReaxtPlugin", function(error) {
    client_err = error
    maybe_done()
  })
}
multi_compiler.hooks.done.tap("ReaxtPlugin", function(stats) {
  client_stats = stats
  port.write({event: "client_hash",hash: stats.hash})
  require("fs").writeFile(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()), maybe_done)
})
multi_compiler.hooks.invalid.tap("ReaxtPlugin", function() {
  port.write({event: "client_invalid"})
})
multi_compiler.hooks.run.tap("ReaxtPlugin", function() {
  port.write({event: "client_compile"})
})
multi_compiler.watch({aggregateTimeout: 200},  function(){})

server(function(req,reply_to,state,done){
  //maybe_done() // receive message indicating server compilation end
  done("noreply")
})
