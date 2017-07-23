var client_config = require("./../../webpack.config.js")
// add reloading code to entries
function add_to_entries(obj,newEntry){
  if(typeof(obj.entry) === 'string'){
    obj.entry = [newEntry,obj.entry]
  }else if(obj.entry.length === undefined){
    for(k in obj.entry){
      var tmp = {entry: obj.entry[k]} ; add_to_entries(tmp,newEntry)
      obj.entry[k] = tmp.entry
    }
  }else {
    obj.entry = [newEntry].concat(obj.entry)
  }
}
add_to_entries(client_config,require.resolve("./client_entry_addition"))
module.exports = client_config
//module.exports.add_to_entries = add_to_entries
