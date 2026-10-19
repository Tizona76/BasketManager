extends "res://tests/steam_wallet/test_steam_persistence.gd"
# The isolated harness copies the complete menu, injecting only autoload symbols.
class SessionStub:
	extends RefCounted
	var access_token := "old_synthetic_access_token"
	var refresh_token := "synthetic_refresh_token"
	var profile_uuid := "uuid1"
	func set_tokens(access: String, refresh: String, _kind: String) -> void:
		access_token=access;refresh_token=refresh
class MenuProbe:
	extends "res://menu_under_test.gd"
	var fixture_data: Dictionary
	var enabled := true
	var requests: Array=[]
	var refreshes: Array=[]
	var identity := {"user_id":"user1","profile_uuid":"uuid1","career_id":"career1"}
	var feedback := ""
	func _steam_cloud_enabled() -> bool: return enabled
	func _steam_cloud_document() -> Variant: return JSON.parse_string(FileAccess.get_file_as_string(fixture_data.path))
	func _steam_cloud_binding() -> Dictionary: return identity.duplicate(true)
	func _steam_cloud_io() -> RefCounted: return fixture_data.io
	func _steam_cloud_send(message: Dictionary,key: String) -> void: requests.append({"message":message.duplicate(true),"key":key})
	func _steam_cloud_send_refresh(refresh: String) -> void: refreshes.append(refresh)
	func _save_session_local_from_menu() -> bool: return true
	func _cloud_save_feedback(message: String) -> void: feedback=message
	func make_adapter() -> void:
		var adapter = load("res://tests/steam_wallet/test_steam_cloud.gd").TestWallet.new()
		var key := JSON.stringify(identity)
		adapter.enable_cloud(_steam_cloud_send.bind(key));_steam_cloud_adapters[key]=adapter
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-root="):base=arg.trim_prefix("--fixture-root=")
	if not base.begins_with("/private/tmp/") or ".." in base or ProjectSettings.globalize_path("res://").begins_with("/Users/"):quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	var f:=fixture(false);var m:=MenuProbe.new();m.Session=SessionStub.new();m.fixture_data=f
	expect("menu_ordinary_not_intercepted",not m._steam_cloud_route(true) and m.requests.is_empty())
	f=fixture();m.fixture_data=f;m.enabled=false
	expect("menu_disabled_no_legacy_fallback",m._steam_cloud_route(true) and m.requests.is_empty())
	m.enabled=true;m.make_adapter();m._try_cloud_save_from_local()
	expect("menu_put_only",m.requests.size()==1 and m.requests[0].message.method=="PUT")
	var sent:Dictionary=m.requests.back();var req:=HTTPRequest.new()
	m._steam_cloud_completed(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),"{}".to_utf8_buffer(),req,sent.key,sent.message.request_id)
	expect("menu_401_refresh_existing_session",m.refreshes.size()==1 and not m._steam_cloud_refresh_attempt.is_empty())
	var tokens:={"access_token":"new_synthetic_access_token","refresh_token":"new_synthetic_refresh_token"}
	m._steam_cloud_refreshed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(tokens).to_utf8_buffer(),HTTPRequest.new())
	expect("menu_refresh_retries_only_original_put",m.requests.size()==2 and m.requests[1].message.body==sent.message.body and m.requests[1].message.headers["Idempotency-Key"]==sent.message.headers["Idempotency-Key"] and m.requests[1].message.headers.Authorization=="Bearer new_synthetic_access_token")
	var last:Dictionary=m.requests.back();m._steam_cloud_completed(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),"{}".to_utf8_buffer(),HTTPRequest.new(),last.key,last.message.request_id)
	expect("menu_refresh_bounded",m.refreshes.size()==1)
	m.free()
	f=fixture();m=MenuProbe.new();m.Session=SessionStub.new();m.fixture_data=f;m.make_adapter();m._try_cloud_save_from_local();sent=m.requests.back()
	m._steam_cloud_completed(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),"{}".to_utf8_buffer(),HTTPRequest.new(),sent.key,sent.message.request_id)
	m.identity.career_id="career2";m._steam_cloud_refreshed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(tokens).to_utf8_buffer(),HTTPRequest.new())
	expect("menu_late_refresh_context_guard",m.Session.access_token=="old_synthetic_access_token" and m.requests.size()==1)
	m.free()
	for delta in [0,3]:
		f=fixture();m=MenuProbe.new();m.Session=SessionStub.new();m.fixture_data=f;m.make_adapter();m._dirty_local=true;m._try_cloud_save_from_local();sent=m.requests.back()
		if delta:local_change(f,delta)
		var answer:={"profile_uuid":"uuid1","career_id":"career1","revision":2,"checkpoint_hash":"d".repeat(64),"snapshot":sent.message.body.snapshot}
		m._steam_cloud_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(answer).to_utf8_buffer(),HTTPRequest.new(),sent.key,sent.message.request_id)
		expect("menu_dirty_progress_"+str(delta),m._dirty_local==(delta!=0) and read(f).wallet.tokens==10+delta)
		m.free()
	print("RESULT ",passed," PASS / ",failed," FAIL");quit(0 if failed==0 else 1)
