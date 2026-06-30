extends Control


func _make_lineedit_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 4
	return sb

func _apply_login_modern_styles() -> void:
	var title := $UI/TitleRow/Title as Button
	var email := $UI/Email as LineEdit
	var code := $UI/Code as LineEdit
	var btn_send := $UI/BtnSendOtp as Button
	var btn_validate := $UI/BtnValidateOtp as Button
	var btn_cancel := $UI/BtnCancel as Button

	var title_empty := StyleBoxEmpty.new()
	title.add_theme_stylebox_override("normal", title_empty)
	title.add_theme_stylebox_override("hover", title_empty)
	title.add_theme_stylebox_override("pressed", title_empty)
	title.add_theme_stylebox_override("focus", title_empty)
	title.add_theme_stylebox_override("disabled", title_empty)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	title.add_theme_constant_override("h_separation", 0)
	title.add_theme_font_size_override("font_size", 30)
	title.flat = true
	title.focus_mode = Control.FOCUS_NONE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 48)

	var input_normal := _make_lineedit_style(Color(0.97, 0.98, 1.0, 0.96), Color(0.72, 0.78, 0.88, 1.0))
	var input_focus := _make_lineedit_style(Color(1, 1, 1, 1), Color(0.20, 0.55, 0.95, 1.0))
	var input_readonly := _make_lineedit_style(Color(0.93, 0.94, 0.96, 1.0), Color(0.75, 0.75, 0.78, 1.0))

	for field in [email, code]:
		field.add_theme_stylebox_override("normal", input_normal)
		field.add_theme_stylebox_override("focus", input_focus)
		field.add_theme_stylebox_override("read_only", input_readonly)
		field.add_theme_color_override("font_color", Color(0.10, 0.12, 0.16, 1.0))
		field.add_theme_color_override("font_placeholder_color", Color(0.45, 0.50, 0.58, 1.0))
		field.add_theme_constant_override("minimum_character_width", 24)
		field.add_theme_font_size_override("font_size", 18)
		field.alignment = HORIZONTAL_ALIGNMENT_LEFT
		field.caret_blink = true
		field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		field.custom_minimum_size = Vector2(248, 56)

	var btn_normal := _make_button_style(Color(0.17, 0.46, 0.92, 1.0), Color(0.11, 0.30, 0.66, 1.0))
	var btn_hover := _make_button_style(Color(0.22, 0.52, 0.98, 1.0), Color(0.16, 0.36, 0.74, 1.0))
	var btn_pressed := _make_button_style(Color(0.11, 0.35, 0.78, 1.0), Color(0.08, 0.24, 0.55, 1.0))
	var btn_disabled := _make_button_style(Color(0.70, 0.74, 0.80, 1.0), Color(0.58, 0.62, 0.68, 1.0))

	for btn in [btn_send, btn_validate, btn_cancel]:
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.95, 0.95))
		btn.add_theme_font_size_override("font_size", 18)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(248, 58)
	btn_cancel.custom_minimum_size = Vector2(198.4, 46.4)
@onready var lbl_step_email: Label = $UI/LblStepEmail
@onready var lbl_step_send_code: Label = $UI/LblStepSendOtp
@onready var lbl_step_code: Label = $UI/LblStepCode
@onready var lbl_step_validate: Label = $UI/LblStepValidateOtp

func _force_step2_text() -> void:
	if lbl_step_send_code == null:
		return
	lbl_step_send_code.text = tr("login.step.send_code_hint")
	lbl_step_send_code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_step_send_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_step_send_code.custom_minimum_size = Vector2(0, 56)

func _apply_login_label_font_sizes() -> void:
	for lbl in [lbl_step_email, lbl_step_send_code, lbl_step_code, lbl_step_validate]:
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))


func _apply_login_i18n_texts() -> void:
	if lbl_step_email != null:
		lbl_step_email.text = tr("login.step.email")
		lbl_step_email.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if lbl_step_send_code != null:
		lbl_step_send_code.text = tr("login.step.send_code_hint")
		lbl_step_send_code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_step_send_code.custom_minimum_size = Vector2(0, 44)
	if lbl_step_code != null:
		lbl_step_code.text = tr("login.step.code")
		lbl_step_code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if lbl_step_validate != null:
		lbl_step_validate.text = tr("login.step.validate")
		lbl_step_validate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _show_login_explainer_popup() -> void:
	if get_node_or_null("LoginExplainerPopup") != null:
		return

	var popup := Control.new()
	popup.name = "LoginExplainerPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	add_child(popup)

	var card := Panel.new()
	card.name = "LoginExplainerCard"
	card.size = Vector2(760, 430)
	card.position = (get_viewport_rect().size - card.size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	popup.add_child(card)

	var bg := TextureRect.new()
	bg.name = "LoginExplainerBG"
	var bg_atlas := AtlasTexture.new()
	bg_atlas.atlas = load("res://assets/images/backgrounds/save.png") as Texture2D
	bg_atlas.region = Rect2(238, 208, 1059, 604)
	bg.texture = bg_atlas
	bg.position = Vector2.ZERO
	bg.size = card.size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)
	card.move_child(bg, 0)

	var title := Label.new()
	title.name = "LoginExplainerTitle"
	title.text = "Why do we ask for your email?"
	title.position = Vector2(28, 22)
	title.size = Vector2(704, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var body := Label.new()
	body.name = "LoginExplainerBody"
	body.text = "• Create a unique user profile

• Appear in the global leaderboard

• Requested only once

• A one-time code is sent for secure verification

• Safe, secure and confidential"
	body.position = Vector2(54, 90)
	body.size = Vector2(652, 230)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	body.add_theme_constant_override("line_spacing", 5)
	card.add_child(body)

	var ok_btn := Button.new()
	ok_btn.name = "BtnLoginExplainerOK"
	ok_btn.text = "OK"
	ok_btn.position = Vector2(594, 352)
	ok_btn.size = Vector2(138, 50)
	var ok_normal := _make_button_style(Color(0.12, 0.68, 0.28, 1.0), Color(0.08, 0.48, 0.20, 1.0))
	var ok_hover := _make_button_style(Color(0.16, 0.76, 0.34, 1.0), Color(0.10, 0.56, 0.24, 1.0))
	var ok_pressed := _make_button_style(Color(0.08, 0.54, 0.22, 1.0), Color(0.06, 0.38, 0.16, 1.0))
	ok_btn.add_theme_stylebox_override("normal", ok_normal)
	ok_btn.add_theme_stylebox_override("hover", ok_hover)
	ok_btn.add_theme_stylebox_override("pressed", ok_pressed)
	ok_btn.add_theme_font_size_override("font_size", 20)
	ok_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	ok_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	ok_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	ok_btn.pressed.connect(func() -> void:
		popup.queue_free()
	)
	card.add_child(ok_btn)


func _play_login_intro() -> void:
	var bg := get_node_or_null("Background") as CanvasItem
	var ui := get_node_or_null("UI") as Control
	if bg != null:
		bg.modulate.a = 0.0
	if ui != null:
		ui.modulate.a = 0.0
		ui.position.y -= 16.0
	await get_tree().process_frame
	var tw := create_tween()
	tw.set_parallel(true)
	if bg != null:
		tw.tween_property(bg, "modulate:a", 1.0, 0.45)
	if ui != null:
		tw.tween_property(ui, "modulate:a", 1.0, 0.40)
		tw.tween_property(ui, "position:y", ui.position.y + 16.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_login_ball_float() -> void:
	var ball := get_node_or_null("UI/TitleRow/BallLeft") as Control
	if ball == null:
		return
	var start_y := ball.position.y
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(ball, "position:y", start_y - 4.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ball, "position:y", start_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


signal auth_success
signal cancel_requested

const API_BASE := "https://api.basketmanager-game.com"
const PATH_AUTH_START := "/v1/auth/start"
const PATH_AUTH_VERIFY := "/v1/auth/verify"

@onready var email: LineEdit = $UI/Email
@onready var code: LineEdit = $UI/Code
@onready var btn_send: Button = $UI/BtnSendOtp
@onready var btn_val: Button = $UI/BtnValidateOtp
@onready var btn_cancel: Button = $UI/BtnCancel
@onready var status: Label = $UI/Status
@onready var http: HTTPRequest = $Http

var _pending_action := ""   # "start" ou "verify"



func _apply_i18n() -> void:
	if lbl_step_email != null:
		lbl_step_email.text = tr("login.step_email")
	if lbl_step_send_code != null:
		lbl_step_send_code.text = tr("login.step_send_code")
	if lbl_step_code != null:
		lbl_step_code.text = tr("login.step_code")
	if lbl_step_validate != null:
		lbl_step_validate.text = tr("login.step_validate")
	if btn_send != null:
		btn_send.text = tr("login.btn.send_code")
	if btn_val != null:
		btn_val.text = tr("login.btn.validate")
	if btn_cancel != null:
		btn_cancel.text = tr("login.btn.cancel")

func _ready() -> void:
	_apply_login_modern_styles()
	_apply_login_label_font_sizes()
	_apply_login_i18n_texts()
	_play_login_intro()
	_play_login_ball_float()
	call_deferred("_show_login_explainer_popup")
	_apply_i18n()
	print("[LOGIN_READY] script=", get_script().resource_path, " node=", name)
	status.text = "Status: idle"
	btn_send.pressed.connect(_on_send)
	btn_val.pressed.connect(_on_validate)
	btn_cancel.pressed.connect(_on_cancel)
	call_deferred("_force_step2_text")

	if http.request_completed.is_connected(_on_http_completed):
		http.request_completed.disconnect(_on_http_completed)
	http.request_completed.connect(_on_http_completed)

	print("[DBG] Http node=", http, " path=", http.get_path())
	
	http.timeout = 90.0
	print("[HTTP] timeout=", http.timeout)

func _on_cancel() -> void:
	if FileAccess.file_exists("user://save_cloud_signup_return_menu.txt"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_cloud_signup_return_menu.txt"))
		var tree := get_tree()
		if tree != null:
			tree.call_deferred("change_scene_to_file", "res://scenes/Menu.tscn")
		return
	emit_signal("cancel_requested")

func _on_send() -> void:
	# anti double-clic / anti requêtes concurrentes
	if _pending_action != "":
		print("[LOGIN] ignore send: pending_action=", _pending_action)
		return

	var e := email.text.strip_edges()
	if e == "":
		status.text = "Status: email requis"
		return

	status.text = "Status: envoi code..."
	btn_send.disabled = true
	btn_val.disabled = true

	_pending_action = "start"
	_http_post_json(API_BASE + PATH_AUTH_START, {"email": e})


func _on_validate() -> void:
	# anti double-clic / anti requêtes concurrentes
	if _pending_action != "":
		print("[LOGIN] ignore validate: pending_action=", _pending_action)
		return

	var e := email.text.strip_edges()
	var c := code.text.strip_edges()

	if e == "":
		status.text = "Status: email requis"
		return
	if c == "":
		status.text = "Status: code requis"
		return

	status.text = "Status: validation..."
	btn_send.disabled = true
	btn_val.disabled = true

	_pending_action = "verify"
	_http_post_json(API_BASE + PATH_AUTH_VERIFY, {"email": e, "code": c})


func _http_post_json(url: String, payload: Dictionary) -> void:
	print("[HTTP] POST ", url, " payload=", payload)

	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify(payload)

	http.timeout = 30
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	print("[HTTP] request() err=", err)

	if err != OK:
		status.text = "Status: HTTP request() error = " + str(err)
		btn_send.disabled = false
		btn_val.disabled = false
		_pending_action = ""


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	btn_send.disabled = false
	btn_val.disabled = false

	var txt := body.get_string_from_utf8()
	var data := {}
	if txt != "":
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed

	print("[HTTP] result=", result, " code=", response_code, " body=", txt)

	if response_code < 200 or response_code >= 300:
		var msg := "Status: erreur HTTP " + str(response_code)
		if data.has("detail"):
			msg += " (" + str(data["detail"]) + ")"
		if data.has("error"):
			msg += " (" + str(data["error"]) + ")"
		status.text = msg
		_pending_action = ""
		return

	if _pending_action == "start":
		status.text = "Status: code envoyé"
		_pending_action = ""
		return

	if _pending_action == "verify":
		# DEBUG brut (avant extraction)
		print("[DBG][VERIFY_RAW] keys=", data.keys())
		print("[DBG][VERIFY_RAW] access_token=", str(data.get("access_token", "")).left(20), "...")
		print("[DBG][VERIFY_RAW] refresh_token=", str(data.get("refresh_token", "")).left(20), "...")
		print("[DBG][VERIFY_RAW] token_type=", str(data.get("token_type", "")))

		# extraction unique
		var at := str(data.get("access_token", "")).strip_edges()
		var rt := str(data.get("refresh_token", "")).strip_edges()
		var puid := str(data.get("profile_uuid", "")).strip_edges()
		var tt := "Bearer"  # normalise : l'API renvoie "bearer" mais le backend attend "Bearer"

		if at == "":
			status.text = "Status: connecté mais token manquant (API)"
			print("[AUTH] ERROR: missing access_token in response:", data)
			_pending_action = ""
			return

		# stockage unique
		Session.set_tokens(at, rt, tt)
		Session.profile_uuid = puid

		print("[DBG][LOGIN_SESSION] id=", Session.get_instance_id(),
			" script=", Session.get_script().resource_path,
			" access_len=", str(Session.access_token).length(),
			" profile_uuid=", str(Session.profile_uuid))

		print("[AUTH] stored access_token len=", Session.access_token.length(), " token_type=", Session.token_type)

		# persistance locale
		_save_session_local()

		status.text = "Status: connecté ✅"
		_pending_action = ""

		print("[DBG][SESSION_MARK]", Session.SESSION_MARK)

		if FileAccess.file_exists("user://save_cloud_signup_return_menu.txt"):
			var tree := get_tree()
			if tree != null:
				tree.call_deferred("change_scene_to_file", "res://scenes/Menu.tscn")
			return

		emit_signal("auth_success")
		return


func _save_session_local() -> void:
	var d := {
		"profile_uuid": str(Session.profile_uuid),
		"refresh_token": str(Session.refresh_token)
	}
	var f := FileAccess.open("user://session.json", FileAccess.WRITE)
	if f == null:
		print("[FILE] cannot write user://session.json")
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	print("[FILE] wrote:user://session.json")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_i18n()
