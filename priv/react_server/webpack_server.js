var webpack = require("webpack"),
    webpack_server = require("webpack-dev-server"),
    port = require('node_erlastic').port,
    server_config = require('./server.webpack.config.js'),
    client_config = require("./../../webpack.config.js")

var client_compiler = webpack(client_config)
var server_compiler = webpack(server_config)

new WebpackDevServer(client_compiler, {
  contentBase: "priv/static",
  hot: true,
  quiet: false,
  noInfo: false,
  lazy: true,
  watchDelay: 300,
  publicPath: "/assets/",
  headers: { "X-Custom-Header": "yes" },
  stats: { colors: true }
})
  server.listen(8080, "localhost", function() {});
  return 
})
