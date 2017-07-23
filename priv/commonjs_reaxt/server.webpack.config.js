var client_config = require("./../../webpack.config.js")
var path = require('path')
client_config.entry = "reaxt/react_server"
client_config.output = { path: path.join(__dirname, '../../../priv'), filename: 'server.js' }
client_config.target = "node"
client_config.externals = {}
module.exports = client_config
