var client_config = require("./../../webpack.config.js")
client_config.entry = {"server": "react_server/react_server",
                       "client": "react_server/webpack_client"}
client_config.output = { path: '../priv', filename: '[name].js' }
client_config.target = "node"
client_config.externals = {}
module.exports = client_config
