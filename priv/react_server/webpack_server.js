var webpack = require("webpack"), port = require('node_erlastic').port

var client_config = require("./../../webpack.config.js")
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

// server reload a blank client config to change it
delete require.cache[require.resolve("./../../webpack.config.js")]
var server_config = require('./server.webpack.config.js')

var to_compile = 2
var last_hash = ""
function done_or_failed(err,stats) {
    to_compile--
    if(to_compile == 0){
        if(err) port.write({event: "done", error: JSON.stringify(err)})
        else if(stats.hasErrors()) port.write({event: "done", error: "soft fail"})
        else    port.write({event: "done"})
        to_compile = 2;
    }
}

client_compiler.plugin("invalid", function() {
  webpack(server_config).run(done_or_failed)
  port.write({event: "invalid"})
})
client_compiler.plugin("compile", function() { port.write({event: "compile"}) })
client_compiler.plugin("done", function(stats) {
  last_hash = stats.hash
  port.write({event: "hash",hash: last_hash})
  require("fs").writeFileSync(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()))
})
webpack(server_config).run(done_or_failed)
client_compiler.watch(100, done_or_failed)
