var webpack = require("webpack")

Server(function(term,from,state,done){
  if (term[0] == "compilation_state") done("reply", code)
  else throw new Error("unexpected request")
},function(config){
  config.entry = {
    server: "deps/reaxt/priv/react_server/react_server.js",
    client: "web/app.js"
  }
  config.output = {
    path: 'priv',
    filename: '[name].js',
    chunkFilename: '[id].chunk.js',
    publicPath: '/assets/'
  }
  var compiler = webpack(config)
  var server = new WebpackDevServer(compiler, {
    contentBase: "priv/",
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
