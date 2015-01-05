var webpack = require("webpack"), port = require('node_erlastic').port

var client_config = require("./../../webpack.config.js")

client_config.plugins = (client_config.plugins || []).concat([new webpack.HotModuleReplacementPlugin()])
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
require('node_erlastic').log(client_config.entry)
var client_compiler = webpack(client_config)
delete require.cache[require.resolve("./../../webpack.config.js")]

var server_compiler = webpack(require('./server.webpack.config.js'))

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
  server_compiler.run(done_or_failed)
  port.write({event: "invalid"})
})
client_compiler.plugin("compile", function() { port.write({event: "compile"}) })
client_compiler.plugin("done", function(stats) {
  last_hash = stats.hash
  port.write({event: "hash",hash: last_hash})
  require("fs").writeFileSync(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()))
})
server_compiler.run(done_or_failed)
client_compiler.watch(100, done_or_failed)

port.on('readable', function server(){
  if(null !== (term = port.read())){
    if(term == "get_hash") port.write(last_hash);
    server();
  }
})
