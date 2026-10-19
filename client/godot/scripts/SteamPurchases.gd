extends Node
# Single process-owned callback pump. Created lazily by the Steam shop only.
# GodotSteam 4.23.1 stays outside res://; never copied into other exports.
signal authorization(app_id: int, order_id: String, authorized: bool)
signal web_ticket_ready(ticket_hex: String)
signal web_ticket_failed()

const WEB_API_IDENTITY := "basketcorp-identity-v1"
var _web_ticket_handle := 0

const APP_ID := 5069970
var _steam: Object
var _initialized := false

func environment_allowed() -> bool:
	return OS.get_name()=="Windows" and OS.has_feature("steam") and OS.has_feature("x86_64")

func initialize(enabled: bool = false) -> String:
	if not enabled or not environment_allowed(): return "STEAM_DISABLED"
	if _initialized: return "READY"
	if not Engine.has_singleton("Steam"):
		var descriptor := OS.get_executable_path().get_base_dir().path_join("steamworks/external.gdextension")
		var status := GDExtensionManager.load_extension(descriptor)
		if status != GDExtensionManager.LOAD_STATUS_OK: return "STEAM_UNAVAILABLE"
	if not Engine.has_singleton("Steam"): return "STEAM_UNAVAILABLE"
	return initialize_api(Engine.get_singleton("Steam"))

func initialize_api(api: Object) -> String:
	# Production entry uses initialize(); tests subclass the environment gate.
	if not environment_allowed(): return "STEAM_DISABLED"
	if _initialized: return "READY"
	for method in ["steamInitEx","getAppID","run_callbacks","steamShutdown"]:
		if not api.has_method(method): return "STEAM_API_MISSING"
	if not api.has_signal("microtransaction_auth_response"): return "STEAM_API_MISSING"
	var result: Variant = api.call("steamInitEx",APP_ID,false)
	if not result is Dictionary or result.get("status") != 0: return "STEAM_UNAVAILABLE"
	if int(api.call("getAppID")) != APP_ID:
		api.call("steamShutdown")
		return "STEAM_APPID_MISMATCH"
	_steam=api
	_steam.connect("microtransaction_auth_response",_authorized)
	if not _steam.has_method("getAuthTicketForWebApi") or not _steam.has_signal("get_ticket_for_web_api"):
		_steam.call("steamShutdown")
		return "STEAM_WEB_AUTH_UNAVAILABLE"
	_steam.connect("get_ticket_for_web_api",_on_web_ticket)
	_initialized=true
	return "READY"

func request_web_ticket() -> bool:
	if not _initialized or _web_ticket_handle != 0:
		return false
	_steam.call("getAuthTicketForWebApi", WEB_API_IDENTITY)
	return true

func _on_web_ticket(handle: int, result: int, ticket_size: int, ticket_buffer: Array) -> void:
	_web_ticket_handle = handle
	if result != 1 or ticket_size <= 0 or ticket_size > ticket_buffer.size():
		web_ticket_failed.emit()
		return
	var hex := ""
	for i in range(ticket_size):
		hex += "%02x" % int(ticket_buffer[i])
	web_ticket_ready.emit(hex)

func cancel_web_ticket() -> void:
	if _steam != null and _web_ticket_handle != 0:
		_steam.call("cancelAuthTicket", _web_ticket_handle)
	_web_ticket_handle = 0

func _process(_delta: float) -> void:
	if _initialized: _steam.call("run_callbacks")

func _authorized(app_id: int, order_id: int, authorized: bool) -> void:
	if app_id == APP_ID and order_id > 0: authorization.emit(app_id,str(order_id),authorized)

func _exit_tree() -> void:
	if _initialized:
		cancel_web_ticket()
		if _steam.has_signal("get_ticket_for_web_api") and _steam.is_connected("get_ticket_for_web_api", _on_web_ticket):
			_steam.disconnect("get_ticket_for_web_api", _on_web_ticket)
		_steam.disconnect("microtransaction_auth_response",_authorized)
		_steam.call("steamShutdown")
		_initialized=false
