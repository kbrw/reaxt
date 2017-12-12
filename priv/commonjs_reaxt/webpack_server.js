var webpack = require("webpack"), 
    port = require('node_erlastic').port,
    server = require('node_erlastic').server

var client_config = require(process.cwd()+"/"+process.argv[2])

//if(process.argv[2] === "hot"){
//    // add hotmodule plugin to client
//    client_config.plugins = (client_config.plugins || []).concat([new webpack.HotModuleReplacementPlugin()])
//    // add reloading code to entries
//    client_config.add_to_entries(client_config,"webpack/hot/dev-server")
//    // remove external which cause conflicts in hot loading
//    client_config.externals = {}
//}
var client_compiler = webpack(client_config)

var client_stats,client_err
function maybe_done() {
  if(client_err) port.write({event: "client_done", error: JSON.stringify(client_err)})
  else if(client_stats.hasErrors()) port.write({event: "client_done", error: "soft fail"})
  else    port.write({event: "client_done"})
}

client_compiler.plugin("invalid", function() {
  port.write({event: "client_invalid"})
})
client_compiler.plugin("compile", function() { 
  port.write({event: "client_compile"})
})
client_compiler.plugin("failed", function(error) {
  client_err = error
  maybe_done()
})
client_compiler.plugin("done", function(stats) {
  client_stats = stats
  port.write({event: "client_hash",hash: stats.hash})
  require("fs").writeFile(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()), maybe_done)
})
//port.write({event: "invalid"})
client_compiler.watch({aggregateTimeout: 200},  function(){})
server(function(req,reply_to,state,done){
  //maybe_done() // receive message indicating server compilation end
  done("noreply")
})
