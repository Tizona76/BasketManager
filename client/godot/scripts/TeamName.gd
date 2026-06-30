extends Control

signal submit_team_name(team_name: String)
signal back_requested

@onready var input_team: LineEdit = get_node_or_null("Center/Box/WrapInput/InputTeam") as LineEdit
@onready var btn_confirm: BaseButton = get_node_or_null("Center/Box/BtnConfirmer") as BaseButton
@onready var btn_back: BaseButton = get_node_or_null("Center/Box/BtnRetour") as BaseButton
@onready var lbl_title: Label = get_node_or_null("Center/Box/LblTitle") as Label

var _dlg: AcceptDialog
var _dlg_edit: LineEdit

func _ready() -> void:
	# Fallbacks si les chemins changent
	if input_team == null:
		input_team = find_child("InputTeam", true, false) as LineEdit
	if btn_confirm == null:
		btn_confirm = find_child("BtnConfirmer", true, false) as BaseButton
	if btn_back == null:
		btn_back = find_child("BtnRetour", true, false) as BaseButton
	if lbl_title == null:
		lbl_title = find_child("LblTitle", true, false) as Label

	_setup_fallback_dialog()
	call_deferred("_focus_input")

	# Connect boutons (anti-double)
	if btn_confirm != null:
		var cb := Callable(self, "_on_confirm")
		if not btn_confirm.pressed.is_connected(cb):
			btn_confirm.pressed.connect(cb)

	if btn_back != null:
		var cb2 := Callable(self, "_on_back")
		if not btn_back.pressed.is_connected(cb2):
			btn_back.pressed.connect(cb2)

	if input_team != null:
		var cb3 := Callable(self, "_on_text_submitted")
		if not input_team.text_submitted.is_connected(cb3):
			input_team.text_submitted.connect(cb3)

	_apply_i18n()
	call_deferred("_ensure_teamname_bouncing_ball")
	print("[TEAMNAME] ready. input=", input_team, " confirm=", btn_confirm, " back=", btn_back)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_i18n()

func _apply_i18n() -> void:
	if lbl_title != null:
		var t := tr("teamname.title")
		if t == "teamname.title":
			t = tr("TEAMNAME_TITLE")
		lbl_title.text = t

	if btn_confirm != null:
		var c := tr("teamname.create")
		if c == "teamname.create":
			c = tr("TEAMNAME_CREATE")
		btn_confirm.text = c
		var _fs_confirm := int(btn_confirm.get_theme_font_size("font_size"))
		btn_confirm.add_theme_font_size_override("font_size", _fs_confirm + 4)

	if btn_back != null:
		var b := tr("teamname.back")
		if b == "teamname.back":
			b = tr("BTN_BACK")
		btn_back.text = b

	if input_team != null:
		var ph := tr("teamname.placeholder")
		if ph == "teamname.placeholder":
			ph = "Team name"
		input_team.placeholder_text = ph

	# Dialog (best effort)
	if _dlg != null:
		var dt := tr("teamname.title")
		if dt == "teamname.title":
			dt = tr("TEAMNAME_TITLE")
		_dlg.title = dt
		_dlg.dialog_text = dt

		var ok := _dlg.get_ok_button()
		if ok != null:
			var v := tr("selection.validate")
			if v == "selection.validate":
				v = "Valider"
			ok.text = v

func _setup_fallback_dialog() -> void:
	if _dlg != null:
		return

	_dlg = AcceptDialog.new()
	_dlg.title = "Nom de l'équipe"
	_dlg.dialog_text = "Saisis le nom de ton équipe :"
	add_child(_dlg)
	_dlg.hide()

	_dlg_edit = LineEdit.new()
	_dlg_edit.custom_minimum_size = Vector2(320, 0)
	_dlg_edit.placeholder_text = "Ex: Panthères"

	# Insère dans le contenu du dialog
	var content: Node = _dlg.get_label().get_parent()
	content.add_child(_dlg_edit)

	_dlg.register_text_enter(_dlg_edit)

	var cb := Callable(self, "_on_fallback_confirmed")
	if not _dlg.confirmed.is_connected(cb):
		_dlg.confirmed.connect(cb)


func _ensure_teamname_bouncing_ball() -> void:
	var old_ball := get_node_or_null("ImgBallTeamName")
	if old_ball != null:
		old_ball.queue_free()

	var old_dbg := get_node_or_null("DbgBallBlock")
	if old_dbg != null:
		old_dbg.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	var dbg := ColorRect.new()
	dbg.name = "DbgBallBlock"
	dbg.color = Color(1, 0, 0, 0.95)
	dbg.size = Vector2(140, 140)
	dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dbg.z_index = 9999
	add_child(dbg)
	dbg.set_as_top_level(true)

	var vp := get_viewport_rect().size
	dbg.global_position = Vector2(
		(vp.x - dbg.size.x) * 0.5,
		(vp.y - dbg.size.y) * 0.5 - 120.0
	)

	var base_y := dbg.global_position.y
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(dbg, "global_position:y", base_y - 18.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dbg, "global_position:y", base_y, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.10)

	print("[TEAMNAME][DBG] red block created at ", dbg.global_position, " viewport=", vp)

func _focus_input() -> void:
	if input_team == null:
		print("[TEAMNAME][WARN] InputTeam missing")
		return

	# Best effort focus DOM (web only)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function(){
				try{
					const c = document.querySelector('canvas');
					if (c) { c.tabIndex = 0; c.focus(); }
				}catch(e){}
			})();
		""")

	input_team.editable = true
	input_team.focus_mode = Control.FOCUS_ALL
	input_team.mouse_filter = Control.MOUSE_FILTER_STOP
	input_team.grab_focus()
	input_team.select_all()

func _on_back() -> void:
	print("[TEAMNAME] back_requested")
	emit_signal("back_requested")

func _on_text_submitted(_t: String) -> void:
	_on_confirm()

func _on_confirm() -> void:
	if input_team == null:
		print("[TEAMNAME][WARN] InputTeam missing")
		return

	var team_name := input_team.text.strip_edges()
	if team_name == "":
		_open_fallback_dialog()
		return

	# Lock UI
	if btn_confirm != null:
		btn_confirm.disabled = true
	if btn_back != null:
		btn_back.disabled = true
	input_team.editable = false

	print("[TEAMNAME] EMIT submit_team_name =", team_name)
	emit_signal("submit_team_name", team_name)

func _open_fallback_dialog() -> void:
	if _dlg == null or _dlg_edit == null:
		return
	_dlg_edit.text = ""
	_dlg.popup_centered()
	_dlg_edit.grab_focus()

func _on_fallback_confirmed() -> void:
	if _dlg_edit == null:
		return
	var team_name := _dlg_edit.text.strip_edges()
	if team_name == "":
		_open_fallback_dialog()
		return

	if input_team != null:
		input_team.text = team_name

	print("[TEAMNAME] EMIT submit_team_name (fallback) =", team_name)
	emit_signal("submit_team_name", team_name)
