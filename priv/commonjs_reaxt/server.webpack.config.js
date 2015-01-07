var client_config = require("./../../webpack.config.js")
client_config.entry = "reaxt/react_server"
client_config.output = { path: '../priv', filename: 'server.js' }
client_config.target = "node"
client_config.externals = {}
module.exports = client_config
