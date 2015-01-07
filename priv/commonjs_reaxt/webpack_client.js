var events = new EventSource("/webpack/events")
var hot = false
var currentHash = ""
events.addEventListener("hot", function() {
	hot = true
	console.log("[WDS] Hot Module Replacement enabled.")
})
var Notification = window.Notification || window.mozNotification || window.webkitNotification
Notification.requestPermission(function (permission) {})
var icon = "https://avatars0.githubusercontent.com/u/1481354?v=3&s=200"
events.addEventListener("invalid", function() {
	console.log("[WDS] App updated. Recompiling...")
})
events.addEventListener("hash", function(ev) {
    currentHash = JSON.parse(ev.data).hash
	console.log("[WDS] new hash : "+currentHash)
})
events.addEventListener("done", function(ev){
    var desc = JSON.parse(ev.data)
    console.log("will print data")
    console.log(ev.data)
    if(desc.error){
        if(desc.error !== "soft fail"){
            new Notification("Fatal error",{body: desc.error,icon: icon})
            console.log(JSON.parse(desc.error))
        }
        else{
            var notif = new Notification("Build errors",{body: "Click me to see them",icon: icon})
            notif.onclick = function(){
                window.open(location.protocol + '//' + location.host+'/webpack#errors','_newtab')
            }
            console.log("[WDS] soft fail, see /webpack#errors")
        }
    }else{
        console.log("build success, reload")
        var msg
	    if(hot) {
            msg = "Build Success, hot reload"
	    	console.log("[WDS] App hot update...")
	    	window.postMessage("webpackHotUpdate" + currentHash, "*")
	    } else {
            msg = "Build Success, reload"
	    	console.log("[WDS] App updated. Reloading...")
	    	window.location.reload()
	    }
        var notif = new Notification(msg,{body: "Click me",icon: icon})
        notif.onclick = function(){
            window.open(location.protocol + '//' + location.host+'/webpack','_newtab')
        }
    }
})
