extends RefCounted
# Test activation is an explicit resource present ONLY in the temporary iOS test project.
const PRODUCTION_BASE := "https://api.basketmanager-game.com"
const P0_BASE := "https://192.168.1.25:8443"
const P0_CONFIG := "res://p0_cloud_test.cfg"
const P0_CA := "res://p0_cloud_test_ca.crt"

static func _config() -> Dictionary:
	var requested: bool = bool(ProjectSettings.get_setting("p0_cloud/test_mode", false))
	if not FileAccess.file_exists(P0_CONFIG):
		return {"enabled": requested, "base": ""}
	if not requested:
		return {"enabled": true, "base": ""}
	var cfg := ConfigFile.new()
	if cfg.load(P0_CONFIG) != OK:
		return {"enabled": true, "base": ""}
	# Presence is fail-closed even when the marker is malformed or disabled.
	if cfg.get_value("p0", "enabled", false) != true:
		return {"enabled": true, "base": ""}
	return {"enabled": true, "base": str(cfg.get_value("p0", "api_base", ""))}

static func is_p0_test_mode() -> bool:
	return bool(_config()["enabled"])

static func resolve_context(enabled: bool, ios: bool, debug: bool, base: String) -> String:
	if not enabled:
		return PRODUCTION_BASE
	if not ios or not debug or base != P0_BASE:
		return ""
	return base

static func get_api_base() -> String:
	var cfg := _config()
	var base := resolve_context(bool(cfg["enabled"]), OS.has_feature("ios"), OS.is_debug_build(), str(cfg["base"]))
	if base.is_empty():
		push_error("P0 FAIL CLOSED: invalid API configuration or unsupported build")
	return base

static func target_allowed(base: String, url: String) -> bool:
	if base.is_empty():
		return false
	if url != base and not url.begins_with(base + "/"):
		return false
	# Reject ambiguous control/escape forms before the native HTTP parser sees them.
	for forbidden in ["\\", "\r", "\n", "\t", " ", "#"]:
		if forbidden in url:
			return false
	return true

static func assert_network_target_allowed(url: String) -> bool:
	if not is_p0_test_mode():
		return true # Preserve existing non-test platform behaviour.
	if not target_allowed(get_api_base(), url):
		push_error("P0 FAIL CLOSED: forbidden network destination")
		return false
	return true

static func request(http: HTTPRequest, url: String, headers := PackedStringArray(), method := HTTPClient.METHOD_GET, body := "") -> Error:
	if not assert_network_target_allowed(url):
		return ERR_UNAUTHORIZED
	if is_p0_test_mode():
		var ca := X509Certificate.new()
		if ca.load(P0_CA) != OK:
			push_error("P0 FAIL CLOSED: test CA missing or invalid")
			return ERR_UNAUTHORIZED
		http.set_tls_options(TLSOptions.client(ca))
		http.max_redirects = 0
	return http.request(url, headers, method, body)

static func open_checkout(url: String) -> Error:
	if is_p0_test_mode():
		push_error("P0 FAIL CLOSED: external checkout disabled")
		return ERR_UNAUTHORIZED
	return OS.shell_open(url)
