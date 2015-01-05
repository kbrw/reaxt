var events = new EventSource("/webpack/events")
var hot = false
var currentHash = ""
events.addEventListener("hot", function() {
	hot = true
	console.log("[WDS] Hot Module Replacement enabled.")
})
events.addEventListener("invalid", function() {
	console.log("[WDS] App updated. Recompiling...")
})
events.addEventListener("hash", function(ev) {
    currentHash = JSON.parse(ev.data).hash
	console.log("[WDS] new hash : "+currentHash)
})
events.addEventListener("done", function(ev){
    var desc = JSON.parse(ev.data)
    if(desc.error){
        if(desc.error !== "soft fail") console.log(JSON.parse(desc.error))
        else console.log("[WDS] soft fail, see /webpack#errors")
    }else{
        console.log("build success, reload")
	    if(hot) {
	    	console.log("[WDS] App hot update...")
	    	window.postMessage("webpackHotUpdate" + currentHash, "*")
	    } else {
	    	console.log("[WDS] App updated. Reloading...")
	    	window.location.reload()
	    }
    }
})
