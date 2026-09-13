extends Node

# Web-platform HTTP transport for the cloud save. The native HTTPRequest node
# is unusable in the Godot 3.6 HTML5 export — request() never issues an XHR
# (the call enters, nothing goes out on the wire, and it never returns), so on
# the web we route through JavaScript fetch() and bridge responses back into
# GDScript via a JS callback. Native platforms keep using HTTPRequest.
#
# Instantiated lazily by game._get_web_bridge() (cross-module access only via
# game members — see docs/scaling.md); `game` is wired at creation time.

var game = null
var _js_on_done = null


func _ready() -> void:
	print("[Sync] bridge _ready: callback")
	_js_on_done = JavaScript.create_callback(self, "_on_response")
	print("[Sync] bridge _ready: eval")
	JavaScript.eval(
		"window.__llkHttp = function(kind, url, method, body, token) {" +
		"  var opts = {method: method, headers: {}};" +
		"  if (body) { opts.headers['Content-Type'] = 'application/json'; opts.body = body; }" +
		"  if (token) { opts.headers['Authorization'] = 'Bearer ' + token; }" +
		"  fetch(url, opts).then(function(r) {" +
		"    return r.text().then(function(t) { window.__llkOnDone(kind, r.status, t); });" +
		"  }).catch(function(e) { window.__llkOnDone(kind, 0, String(e)); });" +
		"};", true)
	print("[Sync] bridge _ready: assign")
	JavaScript.get_interface("window").__llkOnDone = _js_on_done
	print("[Sync] bridge _ready: done")


func request(kind: String, url: String, method: String, body: String, token: String) -> bool:
	print("[Sync] web fetch ", method, " ", url)
	JavaScript.get_interface("window").__llkHttp(kind, url, method, body, token)
	return true


# window.__llkOnDone(kind, status, text) lands here; args is a JS array.
func _on_response(args) -> void:
	var kind = str(args[0])
	var code = int(args[1])
	var text = String(args[2])
	print("[Sync] ", kind, " -> ", code)
	game.call("_on_sync_request_completed", 0, code, PoolStringArray(), text.to_utf8(), kind)
