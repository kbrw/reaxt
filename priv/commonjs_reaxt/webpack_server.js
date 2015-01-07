var webpack = require("webpack"), 
    port = require('node_erlastic').port,
    server = require('node_erlastic').server

var client_config = require("./client.webpack.config.js")
if(process.argv[2] === "hot"){
    // add hotmodule plugin to client
    client_config.plugins = (client_config.plugins || []).concat([new webpack.HotModuleReplacementPlugin()])
    // add reloading code to entries
    function add_hot_client(obj){
      if(typeof(obj.entry) === 'string'){
        obj.entry = [obj.entry,"webpack/hot/dev-server"]
      }else if(obj.entry.length === undefined){
        for(k in obj.entry){
          var tmp = {entry: obj.entry[k]} ; add_hot_client(tmp)
          obj.entry[k] = tmp.entry
        }
      }else {
        obj.entry = ["webpack/hot/dev-server"].concat(obj.entry)
      }
    }
    add_hot_client(client_config)
    client_config.externals = {}
}
var client_compiler = webpack(client_config)

var to_compile = 2
var last_hash = ""
var client_stats,client_err
function maybe_done() {
    to_compile--
    if(to_compile == 0){
        if(client_err) port.write({event: "done", error: JSON.stringify(client_err)})
        else if(client_stats.hasErrors()) port.write({event: "done", error: "soft fail"})
        else    port.write({event: "done"})
        to_compile = 2;
    }
}

client_compiler.plugin("invalid", function() {
  port.write({event: "invalid"})
})
client_compiler.plugin("compile", function() { 
  port.write({event: "compile"}) 
})
client_compiler.plugin("failed", function(error) {
  client_err = error
  maybe_done()
})
client_compiler.plugin("done", function(stats) {
  last_hash = stats.hash
  client_stats = stats
  port.write({event: "hash",hash: last_hash})
  require("fs").writeFile(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()), maybe_done)
})
port.write({event: "invalid"})
client_compiler.watch(100, function(){})
server(function(req,reply_to,state,done){
  maybe_done() // receive message indicating server compilation end
  done("noreply")
})
