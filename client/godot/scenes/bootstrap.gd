extends Node

const API_BASE := "https://api.basketmanager-game.com"
const PATH_REFRESH := "/v1/auth/refresh"
const PATH_GUEST := "/v1/auth/guest"

const PATH_LOGIN := "res://scenes/Login.tscn"
const PATH_MENU := "res://scenes/Menu.tscn"
const SESSION_FILE := "user://session.json"

var _http: HTTPRequest = null
var _refresh_in_flight := false

var _refresh_retry_count: int = 0
const _REFRESH_MAX_RETRIES: int = 2

# Backoff (base) + cap (évite d’attendre trop longtemps)
const _REFRESH_BACKOFF_BASE_SEC: float = 0.8
const _REFRESH_BACKOFF_MAX_SEC: float = 6.0

# Anti-retry incohérent : on refuse de retry si le refresh_token change en cours de route
var _last_refresh_token: String = ""


func _ready() -> void:
	print("[BOOT] ready, profile_uuid=", str(Session.profile_uuid),
		" refresh_len=", str(str(Session.refresh_token).strip_edges().length()),
		" access_len=", str(str(Session.access_token).strip_edges().length()))

	# 1) Charger session locale (profile_uuid + refresh_token)
	_load_session_local()

	print("[BOOT] after local load profile_uuid=", str(Session.profile_uuid),
		" refresh_len=", str(str(Session.refresh_token).strip_edges().length()),
		" access_len=", str(str(Session.access_token).strip_edges().length()))

	# 2) Si access_token déjà présent, on va au menu
	var access := str(Session.access_token).strip_edges()
	if access.length() >= 20:
		print("[BOOT] route -> MENU (has access_token)")
		_route_menu()
		return

	# 3) Sinon refresh auto si on a un refresh_token
	var rt := str(Session.refresh_token).strip_edges()
	if rt.length() >= 10:
		print("[BOOT] D6: has refresh -> try refresh")
		_try_refresh(rt)
		return

	# 4) Sinon login (desktop) / guest auto (web)
	if OS.has_feature("web"):
		print("[BOOT] D6: no refresh -> try GUEST (web)")
		_try_guest_auth()
		return

	print("[BOOT] D6: no refresh -> route LOGIN")
	_route_login()


# ------------------------------------------------------------
# ROUTING
# ------------------------------------------------------------
func _route_login() -> void:
	_refresh_in_flight = false
	get_tree().change_scene_to_file(PATH_LOGIN)

func _route_menu() -> void:
	_refresh_in_flight = false
	get_tree().change_scene_to_file(PATH_MENU)


# ------------------------------------------------------------
# SESSION LOCAL (user://session.json)
# ------------------------------------------------------------
func _load_session_local() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		print("[BOOT] no local session file:", SESSION_FILE)
		return

	var f := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if f == null:
		print("[BOOT] cannot read:", SESSION_FILE)
		return

	var txt := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[BOOT] invalid session json (not dict)")
		return

	var d := parsed as Dictionary
	var file_puuid := str(d.get("profile_uuid", "")).strip_edges()
	var file_rt := str(d.get("refresh_token", "")).strip_edges()

	# ✅ PRIORITÉ profile_uuid (ne jamais écraser un profil forcé)
	var cur_puuid := str(Session.profile_uuid).strip_edges()
	var is_forced: bool = bool(Session.is_profile_forced())

	if file_puuid != "":
		if is_forced and file_puuid != cur_puuid:
			print("[BOOT] file profile_uuid=", file_puuid, " cur=", cur_puuid, " forced=true (IGNORED file profile_uuid)")
		else:
			print("[BOOT] file profile_uuid=", file_puuid, " cur=", cur_puuid, " forced=false")
			Session.profile_uuid = file_puuid
	else:
		print("[BOOT] file profile_uuid=(empty) cur=", cur_puuid, " forced=", str(is_forced))

	# refresh_token : on peut le charger (n’écrase pas l’identité forcée)
	if file_rt != "":
		Session.refresh_token = file_rt

	print("[SESSION] loaded local refresh_len=", str(str(Session.refresh_token).strip_edges().length()),
		" profile_uuid=", str(Session.profile_uuid))


func _save_session_local() -> void:
	var d := {
		"profile_uuid": str(Session.profile_uuid),
		"refresh_token": str(Session.refresh_token)
	}
	var f := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if f == null:
		print("[FILE] cannot write ", SESSION_FILE)
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	print("[FILE] wrote:", SESSION_FILE)


func _purge_session_local() -> void:
	Session.refresh_token = ""
	Session.access_token = ""
	_save_session_local()


# ------------------------------------------------------------
# HTTP + REFRESH (retry/backoff + inflight)
# ------------------------------------------------------------
func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 30
	print("[BOOT] http created:", _http.get_path())


func _compute_backoff_sec(attempt_index: int) -> float:
	# attempt_index: 1..N
	var sec := _REFRESH_BACKOFF_BASE_SEC * pow(2.0, float(attempt_index - 1))
	if sec > _REFRESH_BACKOFF_MAX_SEC:
		sec = _REFRESH_BACKOFF_MAX_SEC
	# mini jitter léger (évite synchro si plusieurs clients)
	var jitter := randf_range(0.0, 0.15)
	return sec + jitter


func _try_refresh(rt: String) -> void:
	if _refresh_in_flight:
		print("[BOOT] refresh ignored: already in flight")
		return
	_refresh_in_flight = true

	_last_refresh_token = rt

	_ensure_http()

	# connect propre (évite double connexion)
	if _http.request_completed.is_connected(_on_refresh_completed):
		_http.request_completed.disconnect(_on_refresh_completed)
	_http.request_completed.connect(_on_refresh_completed)

	var url := API_BASE + PATH_REFRESH
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"refresh_token": rt})

	print("[BOOT][REFRESH] POST ", url, " rt_len=", str(rt.length()))
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	print("[BOOT][REFRESH] request err=", err)

	if err != OK:
		_refresh_in_flight = false
		print("[BOOT][REFRESH] request() failed err=", err)
		_route_login()


func _on_refresh_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var txt := body.get_string_from_utf8()
	print("[BOOT][REFRESH] result=", result, " code=", response_code, " body=", txt)

	_refresh_in_flight = false

	# --- CAS RESEAU (pas de réponse HTTP) ---
	# Godot: succès = HTTPRequest.RESULT_SUCCESS (0). Quand offline/timeout/etc => != 0 et code=0
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		print("[BOOT][REFRESH] network fail result=", result, " code=", response_code)

		if _refresh_retry_count < _REFRESH_MAX_RETRIES:
			_refresh_retry_count += 1
			var wait_sec := _compute_backoff_sec(_refresh_retry_count)
			print("[BOOT][REFRESH] retry in ", str(wait_sec), "s ... count=", str(_refresh_retry_count))
			await get_tree().create_timer(wait_sec).timeout

			var rt := str(Session.refresh_token).strip_edges()
			if rt != _last_refresh_token:
				print("[BOOT][REFRESH] token changed during retry -> abort retry")
				_route_login()
				return

			if rt.length() >= 10:
				_try_refresh(rt)
				return

		# ✅ OFFLINE-FIRST: réseau KO -> on laisse jouer en local
		print("[BOOT][REFRESH] retries exhausted (network) -> OFFLINE MENU (local-only)")
		_route_menu()
		return

	# --- CAS HTTP FAIL (réponse reçue mais pas 2xx) ---
	if response_code < 200 or response_code >= 300:
		print("[BOOT][REFRESH] http fail code=", response_code, " body=", txt)

		# ✅ purge si refresh invalide
		if response_code == 401 or txt.find("REFRESH_INVALID") != -1:
			print("[BOOT][REFRESH] REFRESH_INVALID -> purge local session + route LOGIN")
			_purge_session_local()
			_route_login()
			return

		# (Optionnel) si tu veux garder une vieille signature côté API :
		if response_code == 400 and txt.find("BAD_REFRESH") != -1:
			print("[BOOT][REFRESH] BAD_REFRESH -> purge local session + route LOGIN")
			_purge_session_local()
			_route_login()
			return

		_route_login()
		return

	# --- JSON OK ---
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[BOOT][REFRESH] invalid json -> LOGIN")
		_route_login()
		return

	var d := parsed as Dictionary
	var at := str(d.get("access_token", "")).strip_edges()
	var new_rt := str(d.get("refresh_token", "")).strip_edges()
	var tt := str(d.get("token_type", "Bearer")).strip_edges()

	if tt.to_lower() == "bearer":
		tt = "Bearer"

	if at == "" or at.length() < 20:
		print("[BOOT][REFRESH] missing/short access_token -> LOGIN")
		_route_login()
		return

	if new_rt == "":
		new_rt = str(Session.refresh_token).strip_edges()

	# ✅ succès : reset retry counter
	_refresh_retry_count = 0

	Session.set_tokens(at, new_rt, tt)

	print("[BOOT][REFRESH_OK] access_len=", str(Session.access_token.length()),
		" refresh_len=", str(str(Session.refresh_token).strip_edges().length()),
		" token_type=", str(Session.token_type),
		" profile_uuid=", str(Session.profile_uuid))

	_save_session_local()
	_route_menu()


func _try_guest_auth() -> void:
	_ensure_http()

	if _http.request_completed.is_connected(_on_refresh_completed):
		_http.request_completed.disconnect(_on_refresh_completed)
	if _http.request_completed.is_connected(_on_guest_completed):
		_http.request_completed.disconnect(_on_guest_completed)
	_http.request_completed.connect(_on_guest_completed)

	var url := API_BASE + PATH_GUEST
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := "{}"

	print("[BOOT][GUEST] POST ", url)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	print("[BOOT][GUEST] request err=", err)

	if err != OK:
		print("[BOOT][GUEST] request() failed err=", err, " -> LOGIN")
		_route_login()


func _on_guest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var txt := body.get_string_from_utf8()
	print("[BOOT][GUEST] result=", result, " code=", response_code, " body=", txt)

	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		print("[BOOT][GUEST] network fail -> LOGIN")
		_route_login()
		return

	if response_code < 200 or response_code >= 300:
		print("[BOOT][GUEST] http fail -> LOGIN")
		_route_login()
		return

	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[BOOT][GUEST] invalid json -> LOGIN")
		_route_login()
		return

	var d := parsed as Dictionary
	var at := str(d.get("access_token", "")).strip_edges()
	var rt := str(d.get("refresh_token", "")).strip_edges()
	var puid := str(d.get("profile_uuid", "")).strip_edges()
	var tt := str(d.get("token_type", "Bearer")).strip_edges()

	if tt.to_lower() == "bearer":
		tt = "Bearer"

	if at == "" or at.length() < 20:
		print("[BOOT][GUEST] missing/short access_token -> LOGIN")
		_route_login()
		return

	Session.set_tokens(at, rt, tt)
	Session.profile_uuid = puid

	print("[BOOT][GUEST_OK] access_len=", str(Session.access_token.length()),
		" refresh_len=", str(str(Session.refresh_token).strip_edges().length()),
		" token_type=", str(Session.token_type),
		" profile_uuid=", str(Session.profile_uuid))

	_save_session_local()
	_route_menu()
