var webpack = require("webpack"), port = require('node_erlastic').port

var client_compiler = webpack(require("./../../webpack.config.js"))
delete require.cache[require.resolve("./../../webpack.config.js")]
var server_compiler = webpack(require('./server.webpack.config.js'))

var to_compile = 2
function done_or_failed(err,stats) {
    to_compile--
    if(to_compile == 0){
        if(err) port.write({event: "done", error: JSON.stringify(err)})
        else if(stats.hasErrors()) port.write({event: "done", error: "soft fail",hash: stats.hash})
        else    port.write({event: "done",hash: stats.hash})
        to_compile = 2;
    }
}

client_compiler.plugin("invalid", function() {
  server_compiler.run(done_or_failed)
  port.write({event: "invalid"})
})
client_compiler.plugin("compile", function() { port.write({event: "compile"}) })
client_compiler.plugin("done", function(stats) {
  require("fs").writeFileSync(process.cwd()+"/../priv/webpack.stats.json", JSON.stringify(stats.toJson()))
})
server_compiler.run(done_or_failed)
client_compiler.watch(100, done_or_failed)
