var fs = require('fs')
var nodeLoaderPath = __dirname+'/style-collector.loader.js'
var nodeLoaderCode = fs.readFileSync(nodeLoaderPath,{encoding: "utf8"})
var webLoaderPath = require.resolve('style-loader')
var loaderUtilPath = require.resolve('loader-utils')
var webLoaderCode = fs.readFileSync(webLoaderPath,{encoding: "utf8"}).replace('loader-utils',loaderUtilPath)
module.exports = function(content){
  var mod
  if(this.target === "node")
    mod = this.exec(nodeLoaderCode,nodeLoaderPath)
  else
    mod = this.exec(webLoaderCode,webLoaderPath)
  return mod.apply(this, arguments)
}

module.exports.pitch = function(req) {
  var mod
  if(this.target === "node")
    mod = this.exec(nodeLoaderCode,nodeLoaderPath)
  else
    mod = this.exec(webLoaderCode,webLoaderPath)
  return mod.pitch.apply(this, arguments)
}
