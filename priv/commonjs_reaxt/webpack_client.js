if(typeof EventSource != "undefined"){
  var events = new EventSource("/webpack/events")
  var hot = false
  var currentHash = ""
  events.addEventListener("hot", function() {
  	hot = true
  	console.log("[Reaxt] Hot Module Replacement enabled.")
  })
  var Notification = window.Notification || window.mozNotification || window.webkitNotification
  if(typeof Notification != "undefined"){
    Notification.requestPermission(function (permission) {})
  }
  var icon = "https://avatars0.githubusercontent.com/u/1481354?v=3&s=200"
  events.addEventListener("client_invalid", function() {
    console.log("[Reaxt] Client file change detection, start compiling...")
  })
  events.addEventListener("server_invalid", function() {
    console.log("[Reaxt] Server file change detection, start compiling...")
  })
  events.addEventListener("client_hash", function(ev) {
    currentHash = JSON.parse(ev.data).hash
    console.log("[Reaxt] Client side hash : "+currentHash)
  })
  events.addEventListener("server_done", function() {
    console.log("[Reaxt] Server compilation done.")
  })
  var desc
  events.addEventListener("client_done", function(ev) {
    desc = JSON.parse(ev.data)
    console.log("[Reaxt] Client compilation done.")
  })
  events.addEventListener("done", function(ev){
    if(desc.error){
      if(desc.error !== "soft fail"){
        if(typeof Notification != "undefined"){
          new Notification("Fatal error",{body: desc.error,icon: icon})
            console.log(JSON.parse(desc.error))
        }
        return
      }
      else{
        if(typeof Notification != "undefined"){
          var notif = new Notification("Build errors",{body: "Click me to see them",icon: icon})
          notif.onclick = function(){
            window.open(location.protocol + '//' + location.host+'/webpack#errors','_newtab')
          }
        }
        console.log("[Reaxt] client soft fail, see /webpack#errors")
      }
    }
    console.log("[Reaxt] build success, reload")
    var msg
    if(hot) {
      msg = "Build Success, hot reload"
      console.log("[Reaxt] App hot update...")
      window.postMessage("webpackHotUpdate" + currentHash, "*")
    } else {
      msg = "Build Success, reload"
      console.log("[Reaxt] App updated. Reloading...")
      window.location.reload()
    }
  
    if(typeof Notification != "undefined"){
      var notif = new Notification(msg,{body: "Click me",icon: icon})
      notif.onclick = function(){
        window.open(location.protocol + '//' + location.host+'/webpack','_newtab')
      }
    }
  })
}
