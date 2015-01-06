var client_config = require("./../../webpack.config.js")
client_config.module.cssLoaders = client_config.module.cssLoaders.map(function(e){
  e.loader = "style!" + e.loader
  return e
})
client_config.module.loaders = (client_config.module.loaders || []).concat(client_config.module.cssLoaders)
module.exports = client_config
