var client_config = require("./../../webpack.config.js")
client_config.entry = "reaxt/react_server"
client_config.output = { path: '../priv', filename: 'server.js' }
client_config.target = "node"
client_config.externals = {}
//client_config.module.cssLoaders = client_config.module.cssLoaders.map(function(e){
//  e.loader = __dirname + "/style-collector!" + e.loader
//  return e
//})
//client_config.module.loaders = (client_config.module.loaders || []).concat(client_config.module.cssLoaders)
module.exports = client_config
