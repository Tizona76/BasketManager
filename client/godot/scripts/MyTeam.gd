extends Control

signal back_requested

const Save := preload("res://scripts/Save.gd")
const PlayerLife := preload("res://scripts/PlayerLife.gd")

@onready var btn_back: Button = get_node_or_null("BtnBack") as Button
@onready var lbl_total_salary: Label = get_node_or_null("LblTotalSalary") as Label
@onready var scroll: ScrollContainer = get_node_or_null("Scroll") as ScrollContainer
@onready var rows: VBoxContainer = get_node_or_null("Scroll/Rows") as VBoxContainer
@onready var btn_sort_poste: Button = get_node_or_null("SortBar/BtnSortPoste") as Button
@onready var btn_sort_age: Button = get_node_or_null("SortBar/BtnSortAge") as Button
@onready var btn_sort_tir: Button = null
@onready var btn_sort_perf: Button = get_node_or_null("SortBar/BtnSortPerf") as Button
@onready var btn_sort_motivation: Button = get_node_or_null("SortBar/BtnSortMotivation") as Button
@onready var btn_sort_salaire: Button = get_node_or_null("SortBar/BtnSortSalaire") as Button
@onready var btn_confirm_sell: Button = get_node_or_null("BtnConfirmSell") as Button

var avatar_meta: Dictionary = {}
var current_sort: String = "poste"
var sort_ascending: bool = true
var pending_sell_ids: Array[int] = []
var pending_match_ids: Array[int] = []
var lbl_avg_age: Label
var lbl_avg_perf: Label
var lbl_avg_salary: Label
var lbl_selected_to_play: Label
var btn_confirm_match_selection: Button
var btn_auto_save_match_selection: Button
var img_auto_save_token: TextureRect
var myteam_table_header: HBoxContainer
var lineup_summary_popup: Control = null
var lineup_summary_card: Panel = null
var _sell_tooltip_popup: Panel = null
var _lineup_save_tooltip_popup: Panel = null

const AUTO_SAVE_MATCH_SELECTION_TOKENS: int = 8


func _bm_has_auto_save_lineup_token() -> bool:
	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()
	return PlayerLife.get_tokens(d) >= AUTO_SAVE_MATCH_SELECTION_TOKENS


func _bm_make_back_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_bottom = bottom_w
	sb.border_color = Color(0.60, 0.0, 0.0, 1.0)
	sb.shadow_color = glow
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _bm_style_back_button() -> void:
	if btn_back == null:
		return
	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)

	btn_back.add_theme_stylebox_override("normal", normal)
	btn_back.add_theme_stylebox_override("hover", hover)
	btn_back.add_theme_stylebox_override("pressed", pressed)
	btn_back.add_theme_stylebox_override("disabled", disabled)
	btn_back.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_back.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_back.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_back.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	btn_back.add_theme_font_size_override("font_size", 24 if _bm_myteam_is_mobile_layout() else 22)


func _bm_make_confirm_lineup_style(bg: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_bottom = 3
	sb.border_color = border
	sb.shadow_color = shadow
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


func _bm_style_confirm_lineup_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _bm_make_confirm_lineup_style(Color(0.10, 0.62, 0.24, 1.0), Color(0.03, 0.34, 0.12, 1.0), Color(0.0, 0.0, 0.0, 0.35)))
	btn.add_theme_stylebox_override("hover", _bm_make_confirm_lineup_style(Color(0.14, 0.74, 0.30, 1.0), Color(0.04, 0.42, 0.16, 1.0), Color(0.10, 0.80, 0.28, 0.22)))
	btn.add_theme_stylebox_override("pressed", _bm_make_confirm_lineup_style(Color(0.06, 0.45, 0.17, 1.0), Color(0.02, 0.26, 0.09, 1.0), Color(0.0, 0.0, 0.0, 0.25)))
	btn.add_theme_stylebox_override("disabled", _bm_make_confirm_lineup_style(Color(0.16, 0.22, 0.20, 0.65), Color(0.06, 0.18, 0.10, 0.70), Color(0.0, 0.0, 0.0, 0.15)))
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))


func _bm_make_confirm_sell_active_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_bottom = 3
	sb.border_color = Color(0.22, 0.08, 0.25, 1.0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _bm_style_confirm_sell_active_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _bm_make_confirm_sell_active_style(Color("#5B2A64")))
	btn.add_theme_stylebox_override("hover", _bm_make_confirm_sell_active_style(Color("#74347E")))
	btn.add_theme_stylebox_override("pressed", _bm_make_confirm_sell_active_style(Color("#47204F")))


func _bm_make_match_select_style(bg: Color, border: Color, shadow: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 3
	sb.border_color = border
	sb.shadow_color = shadow
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _bm_style_match_select_button(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var normal_bg := Color(0.02, 0.12, 0.24, 1.0)
	var hover_bg := Color(0.04, 0.18, 0.34, 1.0)
	var pressed_bg := Color(0.01, 0.08, 0.17, 1.0)
	var border := Color(1.00, 0.42, 0.12, 0.95)
	if selected:
		normal_bg = Color(0.78, 0.31, 0.08, 1.0)
		hover_bg = Color(0.90, 0.38, 0.10, 1.0)
		pressed_bg = Color(0.62, 0.22, 0.06, 1.0)
		border = Color(1.00, 0.73, 0.28, 1.0)
	btn.add_theme_stylebox_override("normal", _bm_make_match_select_style(normal_bg, border, Color(0.0, 0.0, 0.0, 0.35)))
	btn.add_theme_stylebox_override("hover", _bm_make_match_select_style(hover_bg, border, Color(1.0, 0.45, 0.14, 0.22)))
	btn.add_theme_stylebox_override("pressed", _bm_make_match_select_style(pressed_bg, border, Color(0.0, 0.0, 0.0, 0.30)))
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.60))


func _bm_style_sell_row_button(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var normal_bg := Color(0.25, 0.04, 0.06, 1.0)
	var hover_bg := Color(0.36, 0.06, 0.08, 1.0)
	var pressed_bg := Color(0.18, 0.02, 0.04, 1.0)
	var border := Color(1.0, 0.22, 0.12, 0.95)
	if selected:
		normal_bg = Color(0.88, 0.06, 0.06, 1.0)
		hover_bg = Color(1.0, 0.10, 0.10, 1.0)
		pressed_bg = Color(0.64, 0.02, 0.03, 1.0)
		border = Color(1.0, 0.52, 0.28, 1.0)
	btn.add_theme_stylebox_override("normal", _bm_make_match_select_style(normal_bg, border, Color(0.0, 0.0, 0.0, 0.35)))
	btn.add_theme_stylebox_override("hover", _bm_make_match_select_style(hover_bg, border, Color(1.0, 0.15, 0.08, 0.25)))
	btn.add_theme_stylebox_override("pressed", _bm_make_match_select_style(pressed_bg, border, Color(0.0, 0.0, 0.0, 0.30)))
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.60))


func _bm_show_sell_tooltip(anchor: Control) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	_bm_hide_sell_tooltip()

	var panel := Panel.new()
	panel.name = "SellTooltipPopup"
	panel.set_as_top_level(true)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	panel.size = Vector2(390, 92)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.08, 0.14, 0.96)
	bg.border_color = Color(1.0, 0.42, 0.12, 0.95)
	bg.border_width_bottom = 3
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", bg)

	var lbl := Label.new()
	lbl.text = tr("myteam.sell.tooltip")
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 14
	lbl.offset_top = 8
	lbl.offset_right = -14
	lbl.offset_bottom = -8
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(lbl)

	add_child(panel)
	var vp := get_viewport_rect().size
	var pos := anchor.global_position + Vector2(anchor.size.x + 12.0, -26.0)
	pos.x = clampf(pos.x, 8.0, max(8.0, vp.x - panel.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, max(8.0, vp.y - panel.size.y - 8.0))
	panel.global_position = pos
	_sell_tooltip_popup = panel


func _bm_hide_sell_tooltip() -> void:
	if _sell_tooltip_popup != null and is_instance_valid(_sell_tooltip_popup):
		_sell_tooltip_popup.queue_free()
	_sell_tooltip_popup = null


func _bm_bind_sell_tooltip(btn: Button) -> void:
	if btn == null:
		return
	btn.tooltip_text = ""
	btn.mouse_entered.connect(func(): _bm_show_sell_tooltip(btn))
	btn.mouse_exited.connect(_bm_hide_sell_tooltip)


func _bm_show_lineup_save_tooltip() -> void:
	if btn_auto_save_match_selection == null or not is_instance_valid(btn_auto_save_match_selection):
		return
	_bm_hide_lineup_save_tooltip()

	var panel := Panel.new()
	panel.name = "LineupSaveTooltipPopup"
	panel.set_as_top_level(true)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	var tooltip_text := tr("myteam.lineup_save.tooltip")
	var tooltip_width := clampf(float(tooltip_text.length()) * 5.8, 455.0, 560.0)
	panel.size = Vector2(tooltip_width, 86)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.08, 0.14, 0.96)
	bg.border_color = Color(1.0, 0.42, 0.12, 0.95)
	bg.border_width_bottom = 3
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", bg)

	var lbl := Label.new()
	lbl.text = tooltip_text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 14
	lbl.offset_top = 8
	lbl.offset_right = -14
	lbl.offset_bottom = -8
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 23)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	panel.add_child(lbl)

	add_child(panel)
	var vp := get_viewport_rect().size
	var pos := btn_auto_save_match_selection.global_position + Vector2((btn_auto_save_match_selection.size.x - panel.size.x) * 0.5, -panel.size.y - 8.0)
	pos.x = clampf(pos.x, 8.0, max(8.0, vp.x - panel.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, max(8.0, vp.y - panel.size.y - 8.0))
	panel.global_position = pos
	_lineup_save_tooltip_popup = panel


func _bm_hide_lineup_save_tooltip() -> void:
	if _lineup_save_tooltip_popup != null and is_instance_valid(_lineup_save_tooltip_popup):
		_lineup_save_tooltip_popup.queue_free()
	_lineup_save_tooltip_popup = null


func _bm_bind_lineup_save_tooltip(btn: Button) -> void:
	if btn == null:
		return
	btn.tooltip_text = ""
	var show_cb := Callable(self, "_bm_show_lineup_save_tooltip")
	var hide_cb := Callable(self, "_bm_hide_lineup_save_tooltip")
	if not btn.mouse_entered.is_connected(show_cb):
		btn.mouse_entered.connect(show_cb)
	if not btn.mouse_exited.is_connected(hide_cb):
		btn.mouse_exited.connect(hide_cb)



var _bm_myteam_touch_scroll_active: bool = false
var _bm_myteam_touch_last_y: float = 0.0


func _bm_myteam_is_mobile_landscape() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return false
	if OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return vp.x < 1200.0


func _bm_myteam_is_mobile_layout() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _bm_myteam_apply_mobile_landscape_scroll() -> void:
	if not _bm_myteam_is_mobile_landscape():
		return
	if scroll == null:
		return

	scroll.visible = true
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if rows != null:
		rows.visible = true
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var mobile_rows_top_spacer := rows.get_node_or_null("MyTeamMobileRowsTopSpacer") as Control
		if mobile_rows_top_spacer == null:
			mobile_rows_top_spacer = Control.new()
			mobile_rows_top_spacer.name = "MyTeamMobileRowsTopSpacer"
			rows.add_child(mobile_rows_top_spacer)
			rows.move_child(mobile_rows_top_spacer, 0)
		mobile_rows_top_spacer.custom_minimum_size = Vector2(0, 6)
		mobile_rows_top_spacer.visible = true

func _bm_setup_mobile_scroll() -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if _bm_myteam_is_mobile_layout():
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	

func _ready() -> void:
	_bm_setup_mobile_scroll()
	call_deferred("_bm_myteam_apply_mobile_landscape_scroll")
	if btn_back != null and not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	_bm_style_back_button()

	if btn_sort_poste != null and not btn_sort_poste.pressed.is_connected(_on_sort_poste_pressed):
		btn_sort_poste.pressed.connect(_on_sort_poste_pressed)
	if btn_sort_age != null and not btn_sort_age.pressed.is_connected(_on_sort_age_pressed):
		btn_sort_age.pressed.connect(_on_sort_age_pressed)
	if btn_sort_perf != null and not btn_sort_perf.pressed.is_connected(_on_sort_perf_pressed):
		btn_sort_perf.pressed.connect(_on_sort_perf_pressed)
	if btn_sort_motivation != null and not btn_sort_motivation.pressed.is_connected(_on_sort_motivation_pressed):
		btn_sort_motivation.pressed.connect(_on_sort_motivation_pressed)
	if btn_sort_salaire != null and not btn_sort_salaire.pressed.is_connected(_on_sort_salaire_pressed):
		btn_sort_salaire.pressed.connect(_on_sort_salaire_pressed)
	if btn_confirm_sell != null and not btn_confirm_sell.pressed.is_connected(_on_confirm_sell_pressed):
		btn_confirm_sell.pressed.connect(_on_confirm_sell_pressed)
	_bm_style_confirm_sell_active_button(btn_confirm_sell)
	if btn_confirm_match_selection != null and not btn_confirm_match_selection.pressed.is_connected(_on_confirm_match_selection_pressed):
		btn_confirm_match_selection.pressed.connect(_on_confirm_match_selection_pressed)
	if btn_auto_save_match_selection != null and not btn_auto_save_match_selection.pressed.is_connected(_on_auto_save_match_selection_pressed):
		btn_auto_save_match_selection.pressed.connect(_on_auto_save_match_selection_pressed)

	if btn_sort_poste != null:
		I18nSvc.apply_node(btn_sort_poste)
	if btn_sort_age != null:
		I18nSvc.apply_node(btn_sort_age)
	if btn_sort_perf != null:
		I18nSvc.apply_node(btn_sort_perf)
	if btn_sort_motivation != null:
		I18nSvc.apply_node(btn_sort_motivation)
	if btn_sort_salaire != null:
		I18nSvc.apply_node(btn_sort_salaire)
	if btn_confirm_sell != null:
		I18nSvc.apply_node(btn_confirm_sell)
		if _bm_myteam_is_mobile_layout():
			var fs_confirm_sell: int = int(btn_confirm_sell.get_theme_font_size("font_size"))
			if fs_confirm_sell > 0:
				btn_confirm_sell.add_theme_font_size_override("font_size", fs_confirm_sell + 2)
		call_deferred("_bm_myteam_apply_mobile_landscape_confirm_sell_right")

	_load_avatar_meta()
	_load_pending_match_ids()
	_ensure_match_selection_footer()
	_build_team()

func _on_back_pressed() -> void:
	emit_signal("back_requested")
	if get_tree() != null and get_tree().current_scene == self:
		var path := "res://scenes/Menu.tscn"
		print("[MYTEAM] change_scene_to_file path=", path, " exists=", ResourceLoader.exists(path))
		var err := get_tree().change_scene_to_file(path)
		print("[MYTEAM] change_scene_to_file err=", err)

func _toggle_sort(sort_name: String, default_ascending: bool) -> void:
	if current_sort == sort_name:
		sort_ascending = not sort_ascending
	else:
		current_sort = sort_name
		sort_ascending = default_ascending
	_build_team()

func _on_sort_poste_pressed() -> void:
	_toggle_sort("poste", true)

func _on_sort_age_pressed() -> void:
	_toggle_sort("age", false)

func _on_sort_perf_pressed() -> void:
	_toggle_sort("perf", false)

func _on_sort_motivation_pressed() -> void:
	_toggle_sort("motivation", false)

func _on_sort_salaire_pressed() -> void:
	_toggle_sort("salaire", false)

func _toggle_pending_sell(pid: int) -> void:
	if pid in pending_sell_ids:
		pending_sell_ids.erase(pid)
	else:
		pending_sell_ids.append(pid)
	_build_team()

func _is_match_selection_unlocked() -> bool:
	var d: Dictionary = Save.read_dict()
	var season_round: int = int(d.get("season_round", 0))
	var season_number: int = int(d.get("season_number", 1))

	if season_number <= 1:
		return season_round >= 5

	return season_round >= 0

func _load_pending_match_ids() -> void:
	pending_match_ids.clear()
	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()
	if d.has("roster") and typeof(d["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = d["roster"]
		if roster.has("match_selected_ids") and roster["match_selected_ids"] is Array:
			for raw_id in (roster["match_selected_ids"] as Array):
				pending_match_ids.append(int(raw_id))

func _ensure_match_selection_footer() -> void:
	if lbl_selected_to_play != null and not is_instance_valid(lbl_selected_to_play):
		lbl_selected_to_play = null
	if btn_confirm_match_selection != null and not is_instance_valid(btn_confirm_match_selection):
		btn_confirm_match_selection = null
	if btn_auto_save_match_selection != null and not is_instance_valid(btn_auto_save_match_selection):
		btn_auto_save_match_selection = null

	if lbl_selected_to_play == null:
		lbl_selected_to_play = get_node_or_null("LblSelectedToPlay") as Label
	if lbl_selected_to_play == null:
		lbl_selected_to_play = Label.new()
		lbl_selected_to_play.name = "LblSelectedToPlay"
		add_child(lbl_selected_to_play)

	if btn_confirm_match_selection == null:
		btn_confirm_match_selection = get_node_or_null("BtnConfirmMatchSelection") as Button
	if btn_confirm_match_selection == null:
		btn_confirm_match_selection = Button.new()
		btn_confirm_match_selection.name = "BtnConfirmMatchSelection"
		add_child(btn_confirm_match_selection)

	if btn_auto_save_match_selection == null:
		btn_auto_save_match_selection = get_node_or_null("BtnAutoSaveMatchSelection") as Button
	if btn_auto_save_match_selection == null:
		btn_auto_save_match_selection = Button.new()
		btn_auto_save_match_selection.name = "BtnAutoSaveMatchSelection"
		add_child(btn_auto_save_match_selection)

	if img_auto_save_token == null:
		img_auto_save_token = get_node_or_null("ImgAutoSaveToken") as TextureRect
	if img_auto_save_token == null:
		img_auto_save_token = TextureRect.new()
		img_auto_save_token.name = "ImgAutoSaveToken"
		add_child(img_auto_save_token)

	lbl_selected_to_play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_selected_to_play.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_selected_to_play.size = Vector2(340, 30)
	lbl_selected_to_play.position = Vector2((size.x - 340.0) * 0.5, size.y - 84.0)
	lbl_selected_to_play.add_theme_font_size_override("font_size", 22)
	lbl_selected_to_play.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	btn_confirm_match_selection.text = tr("myteam.btn.confirm_match_selection")
	btn_confirm_match_selection.size = Vector2(240, 48)
	btn_confirm_match_selection.position = Vector2(size.x * 0.5 + 10.0, size.y - 48.0)
	btn_confirm_match_selection.add_theme_font_size_override("font_size", 20)
	_bm_style_confirm_lineup_button(btn_confirm_match_selection)
	btn_confirm_match_selection.visible = false
	btn_confirm_match_selection.disabled = true

	btn_auto_save_match_selection.text = "Save lineup = " + str(AUTO_SAVE_MATCH_SELECTION_TOKENS)
	btn_auto_save_match_selection.size = Vector2(265, 48)
	btn_auto_save_match_selection.position = Vector2(size.x * 0.5 - 275.0, size.y - 48.0)
	btn_auto_save_match_selection.add_theme_font_size_override("font_size", 20)
	btn_auto_save_match_selection.visible = false
	btn_auto_save_match_selection.disabled = true

	var auto_token_path := "res://assets/images/token.png"
	if img_auto_save_token != null:
		if ResourceLoader.exists(auto_token_path):
			img_auto_save_token.texture = load(auto_token_path)
		img_auto_save_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_auto_save_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_auto_save_token.custom_minimum_size = Vector2(24, 24)
		img_auto_save_token.size = Vector2(24, 24)
		img_auto_save_token.position = Vector2(btn_auto_save_match_selection.position.x + 233.0, btn_auto_save_match_selection.position.y + 13.0)
		img_auto_save_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_auto_save_token.visible = false

	if not btn_confirm_match_selection.pressed.is_connected(_on_confirm_match_selection_pressed):
		btn_confirm_match_selection.pressed.connect(_on_confirm_match_selection_pressed)
	if not btn_auto_save_match_selection.pressed.is_connected(_on_auto_save_match_selection_pressed):
		btn_auto_save_match_selection.pressed.connect(_on_auto_save_match_selection_pressed)


func _refresh_match_selection_footer() -> void:
	if lbl_selected_to_play != null and not is_instance_valid(lbl_selected_to_play):
		lbl_selected_to_play = null
	if btn_confirm_match_selection != null and not is_instance_valid(btn_confirm_match_selection):
		btn_confirm_match_selection = null
	if btn_auto_save_match_selection != null and not is_instance_valid(btn_auto_save_match_selection):
		btn_auto_save_match_selection = null

	if lbl_selected_to_play == null or btn_confirm_match_selection == null or btn_auto_save_match_selection == null:
		return

	if not _is_match_selection_unlocked():
		_bm_close_lineup_summary_popup()
		lbl_selected_to_play.visible = false
		btn_confirm_match_selection.visible = false
		btn_confirm_match_selection.disabled = true
		btn_auto_save_match_selection.visible = false
		btn_auto_save_match_selection.disabled = true
		if img_auto_save_token != null:
			img_auto_save_token.visible = false
		return

	lbl_selected_to_play.visible = true
	lbl_selected_to_play.text = tr("myteam.selected_to_play_count") + " : " + str(pending_match_ids.size()) + "/8"

	var ready := pending_match_ids.size() == 8
	var show_auto_save := ready and _bm_has_auto_save_lineup_token()
	btn_confirm_match_selection.visible = ready
	btn_confirm_match_selection.disabled = not ready
	_bm_style_confirm_lineup_button(btn_confirm_match_selection)
	_bm_refresh_lineup_summary_popup(ready)
	btn_auto_save_match_selection.visible = show_auto_save
	btn_auto_save_match_selection.disabled = not show_auto_save
	if img_auto_save_token != null:
		img_auto_save_token.visible = show_auto_save


func _bm_myteam_tr_or_fallback(key: String, fallback: String) -> String:
	var v := tr(key)
	if v == key or v.strip_edges() == "":
		return fallback
	return v


func _bm_get_current_lineup_summary() -> Dictionary:
	var selected_players: Array = []
	var players: Array = _get_selected_players_real()
	for p_raw in players:
		if typeof(p_raw) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = p_raw
		if int(pd.get("id", -1)) in pending_match_ids:
			selected_players.append(pd)

	var count := selected_players.size()
	if count <= 0:
		return {"attack": 0.0, "defense": 0.0, "energy": 0.0}

	var sum_attack := 0.0
	var sum_defense := 0.0
	var sum_energy := 0.0

	for pd in selected_players:
		var tir := float(pd.get("tir", 0.0))
		var precision := float(pd.get("precision", pd.get("accuracy", 0.0)))
		if precision <= 1.5:
			precision *= 100.0
		var vitesse := float(pd.get("vitesse", pd.get("speed", 0.0)))
		var defense := float(pd.get("defense", 0.0))
		var motivation := float(pd.get("motivation", 0.0))

		sum_attack += (tir + precision) * 0.5
		sum_defense += defense
		sum_energy += (vitesse + motivation) * 0.5

	return {
		"attack": sum_attack / float(count),
		"defense": sum_defense / float(count),
		"energy": sum_energy / float(count)
	}


func _bm_add_lineup_summary_label(parent: Control, text_value: String, pos: Vector2, sz: Vector2, fs: int, color: Color, center: bool = true) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	parent.add_child(lbl)
	return lbl


func _bm_close_lineup_summary_popup() -> void:
	if btn_confirm_match_selection != null and is_instance_valid(btn_confirm_match_selection):
		var parent_now := btn_confirm_match_selection.get_parent()
		if parent_now != null and parent_now != self:
			parent_now.remove_child(btn_confirm_match_selection)
			add_child(btn_confirm_match_selection)
			btn_confirm_match_selection.position = Vector2(size.x * 0.5 + 10.0, size.y - 48.0)

	if btn_auto_save_match_selection != null and is_instance_valid(btn_auto_save_match_selection):
		var parent_auto := btn_auto_save_match_selection.get_parent()
		if parent_auto != null and parent_auto != self:
			parent_auto.remove_child(btn_auto_save_match_selection)
			add_child(btn_auto_save_match_selection)
			btn_auto_save_match_selection.position = Vector2(size.x * 0.5 - 275.0, size.y - 48.0)

	if img_auto_save_token != null and is_instance_valid(img_auto_save_token):
		var parent_token := img_auto_save_token.get_parent()
		if parent_token != null and parent_token != self:
			parent_token.remove_child(img_auto_save_token)
			add_child(img_auto_save_token)
			img_auto_save_token.position = Vector2(btn_auto_save_match_selection.position.x + 233.0, btn_auto_save_match_selection.position.y + 13.0)

	var existing := get_node_or_null("LineupSummaryPopup")
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	lineup_summary_popup = null
	lineup_summary_card = null


func _bm_refresh_lineup_summary_popup(ready: bool) -> void:
	if not ready:
		_bm_close_lineup_summary_popup()
		return
	if btn_confirm_match_selection == null or not is_instance_valid(btn_confirm_match_selection):
		return
	if btn_auto_save_match_selection == null or not is_instance_valid(btn_auto_save_match_selection):
		return

	_bm_close_lineup_summary_popup()

	var summary := _bm_get_current_lineup_summary()
	var attack := float(summary.get("attack", 0.0))
	var defense := float(summary.get("defense", 0.0))
	var energy := float(summary.get("energy", 0.0))
	var show_auto_save := _bm_has_auto_save_lineup_token()

	lineup_summary_popup = Control.new()
	lineup_summary_popup.name = "LineupSummaryPopup"
	lineup_summary_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	lineup_summary_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lineup_summary_popup.z_index = 220
	add_child(lineup_summary_popup)

	var card_w := 560.0
	var card_h := 214.0
	lineup_summary_card = Panel.new()
	lineup_summary_card.name = "LineupSummaryCard"
	lineup_summary_card.size = Vector2(card_w, card_h)
	lineup_summary_card.custom_minimum_size = Vector2(card_w, card_h)
	lineup_summary_card.position = Vector2((get_viewport_rect().size.x - card_w) * 0.5, get_viewport_rect().size.y - card_h - 24.0)
	lineup_summary_card.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.96)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.62, 0.12, 0.50)
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	lineup_summary_card.add_theme_stylebox_override("panel", sb)
	lineup_summary_popup.add_child(lineup_summary_card)

	_bm_add_lineup_summary_label(lineup_summary_card, _bm_myteam_tr_or_fallback("myteam.lineup_summary.title", "Lineup ready"), Vector2(24, 14), Vector2(card_w - 48, 34), 26, Color(1, 1, 1, 1))
	_bm_add_lineup_summary_label(lineup_summary_card, _bm_myteam_tr_or_fallback("myteam.lineup_summary.subtitle", "Decision impact preview"), Vector2(24, 48), Vector2(card_w - 48, 24), 18, Color(0.82, 0.88, 1.0, 0.92))

	var col_w := 150.0
	var start_x := 50.0
	var row_y := 86.0
	_bm_add_lineup_summary_label(lineup_summary_card, "Attack\n" + str(int(round(attack))), Vector2(start_x, row_y), Vector2(col_w, 58), 20, Color(1.00, 0.72, 0.20, 1.0))
	_bm_add_lineup_summary_label(lineup_summary_card, "Defense\n" + str(int(round(defense))), Vector2(start_x + col_w + 5.0, row_y), Vector2(col_w, 58), 20, Color(0.42, 0.92, 1.00, 1.0))
	_bm_add_lineup_summary_label(lineup_summary_card, "Energy\n" + str(int(round(energy))), Vector2(start_x + (col_w + 5.0) * 2.0, row_y), Vector2(col_w, 58), 20, Color(0.35, 1.00, 0.55, 1.0))

	var old_parent_auto := btn_auto_save_match_selection.get_parent()
	if old_parent_auto != null:
		old_parent_auto.remove_child(btn_auto_save_match_selection)
	lineup_summary_card.add_child(btn_auto_save_match_selection)
	btn_auto_save_match_selection.position = Vector2((card_w * 0.5) - 260.0, card_h - 58.0)
	btn_auto_save_match_selection.size = Vector2(220, 48)
	btn_auto_save_match_selection.visible = show_auto_save
	btn_auto_save_match_selection.disabled = not show_auto_save
	var sb_auto := StyleBoxFlat.new()
	sb_auto.bg_color = Color(0.95, 0.48, 0.08, 1.0)
	sb_auto.corner_radius_top_left = 10
	sb_auto.corner_radius_top_right = 10
	sb_auto.corner_radius_bottom_left = 10
	sb_auto.corner_radius_bottom_right = 10
	sb_auto.border_width_bottom = 3
	sb_auto.border_color = Color(0.55, 0.20, 0.02, 1.0)
	sb_auto.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb_auto.shadow_size = 8
	sb_auto.shadow_offset = Vector2(0, 4)
	btn_auto_save_match_selection.add_theme_stylebox_override("normal", sb_auto)
	var sb_auto_hover := sb_auto.duplicate()
	sb_auto_hover.bg_color = Color(1.0, 0.58, 0.12, 1.0)
	btn_auto_save_match_selection.add_theme_stylebox_override("hover", sb_auto_hover)
	btn_auto_save_match_selection.add_theme_stylebox_override("pressed", sb_auto)
	btn_auto_save_match_selection.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_auto_save_match_selection.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	_bm_bind_lineup_save_tooltip(btn_auto_save_match_selection)

	if img_auto_save_token != null and is_instance_valid(img_auto_save_token):
		var old_parent_token := img_auto_save_token.get_parent()
		if old_parent_token != null:
			old_parent_token.remove_child(img_auto_save_token)
			lineup_summary_card.add_child(img_auto_save_token)
			img_auto_save_token.custom_minimum_size = Vector2(30.36, 30.36)
			img_auto_save_token.size = Vector2(30.36, 30.36)
			img_auto_save_token.position = Vector2(btn_auto_save_match_selection.position.x + 184.0, btn_auto_save_match_selection.position.y + 10.2)
			img_auto_save_token.visible = show_auto_save

	var old_parent := btn_confirm_match_selection.get_parent()
	if old_parent != null:
		old_parent.remove_child(btn_confirm_match_selection)
	lineup_summary_card.add_child(btn_confirm_match_selection)
	btn_confirm_match_selection.position = Vector2((card_w * 0.5) + 20.0, card_h - 58.0)
	btn_confirm_match_selection.size = Vector2(240, 48)
	btn_confirm_match_selection.visible = true
	btn_confirm_match_selection.disabled = false
	_bm_style_confirm_lineup_button(btn_confirm_match_selection)


func _save_pending_match_ids() -> void:
	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()
	if not d.has("roster") or typeof(d["roster"]) != TYPE_DICTIONARY:
		d["roster"] = {}
	var roster: Dictionary = d["roster"]
	roster["match_selected_ids"] = pending_match_ids.duplicate()
	d["roster"] = roster
	Save.write_dict(d)

func _toggle_pending_match(pid: int) -> void:
	if pid in pending_match_ids:
		pending_match_ids.erase(pid)
	else:
		if pending_match_ids.size() >= 8:
			return
		pending_match_ids.append(pid)
	_save_pending_match_ids()
	_build_team()

func _on_confirm_sell_pressed() -> void:
	if pending_sell_ids.is_empty():
		return

	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()

	if d.has("roster") and typeof(d["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = d["roster"]

		if roster.has("selected_ids") and roster["selected_ids"] is Array:
			var selected_ids_src: Array = (roster["selected_ids"] as Array).duplicate()
			var selected_ids: Array = []
			for raw_id in selected_ids_src:
				var keep := true
				for pid in pending_sell_ids:
					if str(raw_id) == str(pid) or str(raw_id) == str(float(pid)):
						keep = false
						break
				if keep:
					selected_ids.append(raw_id)
			roster["selected_ids"] = selected_ids

		if roster.has("match_selected_ids") and roster["match_selected_ids"] is Array:
			var match_ids_src: Array = (roster["match_selected_ids"] as Array).duplicate()
			var match_ids: Array = []
			for raw_mid in match_ids_src:
				var keep_match := true
				for pid in pending_sell_ids:
					if str(raw_mid) == str(pid) or str(raw_mid) == str(float(pid)):
						keep_match = false
						break
				if keep_match:
					match_ids.append(raw_mid)
			roster["match_selected_ids"] = match_ids

		if roster.has("players") and roster["players"] is Array:
			var new_roster_players: Array = []
			for row_raw in (roster["players"] as Array):
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_raw
				var row_id_str := str(row.get("id", ""))
				var drop := false
				for pid in pending_sell_ids:
					if row_id_str == str(pid):
						drop = true
						break
				if drop:
					continue
				new_roster_players.append(row)
			roster["players"] = new_roster_players

		d["roster"] = roster

	if d.has("mercato") and typeof(d["mercato"]) == TYPE_DICTIONARY:
		var m: Dictionary = d["mercato"]
		if m.has("purchased_ids") and m["purchased_ids"] is Array:
			var purchased_ids_src: Array = (m["purchased_ids"] as Array).duplicate()
			var purchased_ids: Array = []
			for raw_id in purchased_ids_src:
				var keep := true
				for pid in pending_sell_ids:
					if str(raw_id) == str(pid) or str(raw_id) == str(float(pid)):
						keep = false
						break
				if keep:
					purchased_ids.append(raw_id)
			m["purchased_ids"] = purchased_ids
		d["mercato"] = m

	if d.has("players") and d["players"] is Array:
		var new_players: Array = []
		for jv in (d["players"] as Array):
			if typeof(jv) != TYPE_DICTIONARY:
				continue
			var j: Dictionary = jv
			if int(j.get("id", -1)) in pending_sell_ids:
				continue
			new_players.append(j)
		d["players"] = new_players

	var sal_total := 0
	if d.has("roster") and typeof(d["roster"]) == TYPE_DICTIONARY:
		var roster_after: Dictionary = d["roster"]
		if roster_after.has("players") and roster_after["players"] is Array:
			for row_raw in (roster_after["players"] as Array):
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_raw
				sal_total += int(row.get("salary", 0))
	d["salary_total_per_match"] = int(round(float(sal_total) / 22.0))

	PlayerLife.ensure_finance_schema(d)
	Save.write_dict(d)
	pending_sell_ids.clear()
	_build_team()

# ------------------------------------------------------------
# DATA SOURCE = mêmes joueurs que Selection
# ------------------------------------------------------------


func _ensure_avg_labels() -> void:
	if lbl_avg_age == null:
		lbl_avg_age = get_node_or_null("LblAvgAgeMyTeam") as Label
	if lbl_avg_age == null:
		lbl_avg_age = Label.new()
		lbl_avg_age.name = "LblAvgAgeMyTeam"
		add_child(lbl_avg_age)

	if lbl_avg_perf == null:
		lbl_avg_perf = get_node_or_null("LblAvgPerfMyTeam") as Label
	if lbl_avg_perf == null:
		lbl_avg_perf = Label.new()
		lbl_avg_perf.name = "LblAvgPerfMyTeam"
		add_child(lbl_avg_perf)

	if lbl_avg_salary == null:
		lbl_avg_salary = get_node_or_null("LblAvgSalaryMyTeam") as Label
	if lbl_avg_salary == null:
		lbl_avg_salary = Label.new()
		lbl_avg_salary.name = "LblAvgSalaryMyTeam"
		add_child(lbl_avg_salary)

	for lbl in [lbl_avg_age, lbl_avg_perf, lbl_avg_salary]:
		if lbl == null:
			continue
		var avg_fs: int = 19
		if _bm_myteam_is_mobile_layout():
			avg_fs = 23
		lbl.add_theme_font_size_override("font_size", avg_fs)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	lbl_avg_age.position = Vector2(size.x - 410.0, 24.0)
	lbl_avg_perf.position = Vector2(size.x - 410.0, 50.0)
	lbl_avg_salary.position = Vector2(size.x - 410.0, 76.0)
	lbl_avg_age.size = Vector2(480.0, 24.0)
	lbl_avg_perf.size = Vector2(480.0, 24.0)
	lbl_avg_salary.size = Vector2(480.0, 24.0)

func _on_confirm_match_selection_pressed() -> void:
	if pending_match_ids.size() != 8:
		return
	_save_pending_match_ids()
	Save.ensure_exists(str(Session.profile_uuid))
	var d_confirm: Dictionary = Save.read_dict()
	if d_confirm.has("roster") and typeof(d_confirm["roster"]) == TYPE_DICTIONARY:
		var roster_confirm: Dictionary = d_confirm["roster"] as Dictionary
		roster_confirm["auto_save_match_selection_paid"] = false
		d_confirm["roster"] = roster_confirm
		Save.write_dict(d_confirm)
	_bm_close_lineup_summary_popup()
	var tree := get_tree()
	if tree != null and ResourceLoader.exists("res://scenes/MatchSim.tscn"):
		tree.change_scene_to_file("res://scenes/MatchSim.tscn")


func _on_auto_save_match_selection_pressed() -> void:
	if pending_match_ids.size() != 8:
		return
	Save.ensure_exists(str(Session.profile_uuid))
	var d_confirm: Dictionary = Save.read_dict()
	if not d_confirm.has("roster") or typeof(d_confirm["roster"]) != TYPE_DICTIONARY:
		d_confirm["roster"] = {}
	var roster_confirm: Dictionary = d_confirm["roster"]
	if not PlayerLife.spend_tokens(d_confirm, AUTO_SAVE_MATCH_SELECTION_TOKENS, "auto_save_match_selection_season"):
		_refresh_match_selection_footer()
		return
	roster_confirm["auto_save_match_selection_paid"] = true
	roster_confirm["match_selected_ids"] = pending_match_ids.duplicate()
	d_confirm["roster"] = roster_confirm
	Save.write_dict(d_confirm)
	_bm_close_lineup_summary_popup()
	var tree := get_tree()
	if tree != null and ResourceLoader.exists("res://scenes/MatchSim.tscn"):
		tree.change_scene_to_file("res://scenes/MatchSim.tscn")
	else:
		_refresh_match_selection_footer()


func _show_auto_save_match_selection_popup() -> void:
	var already := get_node_or_null("AutoSaveMatchSelectionPopup")
	if already != null:
		return

	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()
	if not d.has("roster") or typeof(d["roster"]) != TYPE_DICTIONARY:
		d["roster"] = {}
	var roster: Dictionary = d["roster"]

	if bool(roster.get("auto_save_match_selection_paid", false)):
		_bm_close_lineup_summary_popup()
		var tree_paid := get_tree()
		if tree_paid != null and ResourceLoader.exists("res://scenes/MatchSim.tscn"):
			tree_paid.change_scene_to_file("res://scenes/MatchSim.tscn")
		else:
			_refresh_match_selection_footer()
		return

	var tokens_balance: int = PlayerLife.get_tokens(d)
	var can_pay: bool = PlayerLife.can_spend_tokens(d, AUTO_SAVE_MATCH_SELECTION_TOKENS)

	var popup := Control.new()
	popup.name = "AutoSaveMatchSelectionPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 300
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.58)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(dark)

	var popup_w := 686.4
	var popup_h := 382.8

	var card := Panel.new()
	card.custom_minimum_size = Vector2(popup_w, popup_h)
	card.size = Vector2(popup_w, popup_h)
	card.position = Vector2(
		(get_viewport_rect().size.x - popup_w) * 0.5,
		(get_viewport_rect().size.y - popup_h) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.97)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.75, 0.25, 0.35)
	card.add_theme_stylebox_override("panel", sb)
	popup.add_child(card)

	var season_number_ui: int = int(d.get("season_number", 1))

	var title := Label.new()
	title.text = "Confirm auto-save for all matches this season " + str(season_number_ui)
	title.position = Vector2(28, 24)
	title.size = Vector2(popup_w - 56, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var body := Label.new()
	body.text = "Your lineup will be saved and reused automatically for all matches this season."
	body.position = Vector2(34, 108)
	body.size = Vector2(popup_w - 68, 82)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.96))
	card.add_child(body)

	var cost_lbl := Label.new()
	cost_lbl.text = "Cost: " + str(AUTO_SAVE_MATCH_SELECTION_TOKENS)
	cost_lbl.position = Vector2(56, 190)
	cost_lbl.size = Vector2(popup_w - 112, 28)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 22)
	cost_lbl.add_theme_color_override("font_color", Color(1.00, 0.78, 0.22, 1.0))
	card.add_child(cost_lbl)

	var token_path := "res://assets/images/token.png"
	if ResourceLoader.exists(token_path):
		var cost_token := TextureRect.new()
		cost_token.texture = load(token_path)
		cost_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_token.custom_minimum_size = Vector2(27.5, 27.5)
		cost_token.size = Vector2(27.5, 27.5)
		cost_token.position = Vector2((popup_w * 0.5) + 54.0, 193.0)
		cost_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost_token)

	var balance_lbl := Label.new()
	balance_lbl.text = "Your balance: " + str(tokens_balance)
	balance_lbl.position = Vector2(56, 226)
	balance_lbl.size = Vector2(popup_w - 112, 28)
	balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_lbl.add_theme_font_size_override("font_size", 19)
	balance_lbl.add_theme_color_override("font_color", (Color(0.55, 1.0, 0.55, 1.0) if can_pay else Color(1.0, 0.45, 0.45, 1.0)))
	card.add_child(balance_lbl)

	if ResourceLoader.exists(token_path):
		var balance_token := TextureRect.new()
		balance_token.texture = load(token_path)
		balance_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		balance_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		balance_token.custom_minimum_size = Vector2(22, 22)
		balance_token.size = Vector2(22, 22)
		balance_token.position = Vector2((popup_w * 0.5) + 78.0, 229.0)
		balance_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(balance_token)

	var btn_confirm := Button.new()
	btn_confirm.text = "Confirm"
	btn_confirm.custom_minimum_size = Vector2(220, 64)
	btn_confirm.size = Vector2(180, 48)
	btn_confirm.position = Vector2((popup_w - 180.0) * 0.5, popup_h - 74.0)
	btn_confirm.disabled = not can_pay
	btn_confirm.add_theme_font_size_override("font_size", 20)

	var sb_btn := StyleBoxFlat.new()
	sb_btn.bg_color = Color(0.20, 0.55, 0.95, 1.0)
	sb_btn.corner_radius_top_left = 12
	sb_btn.corner_radius_top_right = 12
	sb_btn.corner_radius_bottom_left = 12
	sb_btn.corner_radius_bottom_right = 12
	sb_btn.content_margin_left = 16
	sb_btn.content_margin_right = 16
	sb_btn.content_margin_top = 8
	sb_btn.content_margin_bottom = 8
	btn_confirm.add_theme_stylebox_override("normal", sb_btn)

	var sb_btn_hover := sb_btn.duplicate()
	sb_btn_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
	btn_confirm.add_theme_stylebox_override("hover", sb_btn_hover)
	btn_confirm.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_confirm.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

	btn_confirm.pressed.connect(func():
		Save.ensure_exists(str(Session.profile_uuid))
		var d_confirm: Dictionary = Save.read_dict()
		if not d_confirm.has("roster") or typeof(d_confirm["roster"]) != TYPE_DICTIONARY:
			d_confirm["roster"] = {}
		var roster_confirm: Dictionary = d_confirm["roster"]

		if not PlayerLife.can_spend_tokens(d_confirm, AUTO_SAVE_MATCH_SELECTION_TOKENS):
			popup.queue_free()
			_refresh_match_selection_footer()
			return

		if not PlayerLife.spend_tokens(d_confirm, AUTO_SAVE_MATCH_SELECTION_TOKENS, "auto_save_match_selection_season"):
			popup.queue_free()
			_refresh_match_selection_footer()
			return

		roster_confirm["auto_save_match_selection_paid"] = true
		roster_confirm["match_selected_ids"] = pending_match_ids.duplicate()
		d_confirm["roster"] = roster_confirm
		Save.write_dict(d_confirm)
		popup.queue_free()
		_bm_close_lineup_summary_popup()

		var tree := get_tree()
		if tree != null and ResourceLoader.exists("res://scenes/MatchSim.tscn"):
			tree.change_scene_to_file("res://scenes/MatchSim.tscn")
		else:
			_refresh_match_selection_footer()
	)
	card.add_child(btn_confirm)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(48, 48)
	btn_close.size = Vector2(34, 34)
	btn_close.position = Vector2(popup_w - 46.0, 12.0)
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(func():
		popup.queue_free()
	)
	card.add_child(btn_close)


func _build_team() -> void:
	if rows == null:
		return

	_ensure_avg_labels()

	var lbl_active_coach := get_node_or_null("LblActiveCoachMyTeam") as Label
	if lbl_active_coach == null:
		lbl_active_coach = Label.new()
		lbl_active_coach.name = "LblActiveCoachMyTeam"
		add_child(lbl_active_coach)

	var d_coach: Dictionary = Save.read_dict()
	var active_coach_txt := ""
	if typeof(d_coach) == TYPE_DICTIONARY:
		var coachs: Dictionary = d_coach.get("coachs", {}) as Dictionary
		var active_coach_id: String = str(coachs.get("active", "")).strip_edges()
		if active_coach_id != "":
			var coach_name_map := {
				"coach_junior": "Teddy",
				"coach_confirme": "James",
				"coach_elite": "Alan"
			}
			var duration_map := {
				"coach_junior": 2,
				"coach_confirme": 3,
				"coach_elite": 2
			}
			var current_season: int = maxi(1, int(d_coach.get("season_number", 1)))
			var hired_season: int = maxi(1, int(coachs.get("last_hired_season", current_season)))
			var duration: int = int(duration_map.get(active_coach_id, 1))
			var used: int = current_season - hired_season + 1
			var seasons_left: int = maxi(0, duration - used + 1)
			if seasons_left > 0:
				active_coach_txt = "Coach " + str(coach_name_map.get(active_coach_id, active_coach_id)) + " active — " + str(seasons_left) + " season" + ("" if seasons_left == 1 else "s") + " left"

	lbl_active_coach.visible = (active_coach_txt != "")
	lbl_active_coach.text = active_coach_txt
	lbl_active_coach.position = Vector2(28.0, 18.0)
	lbl_active_coach.size = Vector2(430.0, 34.0)
	lbl_active_coach.add_theme_font_size_override("font_size", 23)
	lbl_active_coach.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45, 1.0))
	lbl_active_coach.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 0.98))
	lbl_active_coach.add_theme_constant_override("outline_size", 4)

	for c in rows.get_children():
		c.queue_free()

	_ensure_table_header()

	var players: Array = _get_selected_players_real()
	print("[MYTEAM][BUILD] players_count=", players.size())
	for dbg_p in players:
		if dbg_p is Dictionary:
			var dbg_pd := dbg_p as Dictionary
			print("[MYTEAM][SRC] id=", str(dbg_pd.get("id", "")), " nom=", str(dbg_pd.get("nom", dbg_pd.get("name", ""))))
	_sort_players(players)

	var total_salary: int = 0
	var sum_age: float = 0.0
	var sum_perf: float = 0.0
	var sum_salary: int = 0
	var count: int = 0

	for p in players:
		var pd := p as Dictionary
		print("[MYTEAM][ROW] id=", str(pd.get("id", "")), " nom=", str(pd.get("nom", pd.get("name", ""))))
		var sal := _myteam_display_salary_annual_from_player(pd)
		total_salary += sal
		sum_age += float(pd.get("age", 0))
		sum_perf += float(pd.get("pondération", 0.0))
		sum_salary += sal
		count += 1
		rows.add_child(_create_player_row(p))

	if lbl_total_salary != null:
		lbl_total_salary.text = "Total = " + _fmt_salary(total_salary)

	if btn_confirm_sell != null:
		btn_confirm_sell.disabled = pending_sell_ids.is_empty()

	if count > 0:
		if lbl_avg_age != null:
			lbl_avg_age.text = tr("selection.avg_age") + " = " + ("%.1f" % (sum_age / float(count)))
		if lbl_avg_perf != null:
			lbl_avg_perf.text = tr("selection.avg_perf") + " = " + ("%.1f" % (sum_perf / float(count)))
		if lbl_avg_salary != null:
			lbl_avg_salary.text = tr("selection.avg_salary") + " = " + _fmt_salary(int(round(float(sum_salary) / float(count))))
	else:
		if lbl_avg_age != null:
			lbl_avg_age.text = tr("selection.avg_age") + " = -"
		if lbl_avg_perf != null:
			lbl_avg_perf.text = tr("selection.avg_perf") + " = -"
		if lbl_avg_salary != null:
			lbl_avg_salary.text = tr("selection.avg_salary") + " = -"

	_refresh_match_selection_footer()
	call_deferred("_bm_myteam_apply_mobile_row_texts_plus2")
	call_deferred("_bm_myteam_apply_mobile_landscape_scroll")
	call_deferred("_bm_myteam_lock_mobile_layout_positions")

func _make_header_button(title: String, min_w: float, cb: Callable, expand: bool = true) -> Button:
	var b := Button.new()
	b.text = title
	b.size_flags_horizontal = 0
	b.custom_minimum_size = Vector2(min_w, 34)
	b.size = Vector2(min_w, 34)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	b.pressed.connect(cb)
	return b


func _on_sort_tir_pressed() -> void:
	_toggle_sort("tir", false)

func _on_sort_stars_pressed() -> void:
	_toggle_sort("stars", false)

func _on_sort_speed_pressed() -> void:
	_toggle_sort("vitesse", false)

func _on_sort_defense_pressed() -> void:
	_toggle_sort("defense", false)

func _on_sort_accuracy_pressed() -> void:
	_toggle_sort("precision", false)

func _make_header_visual_button(title: String, min_w: float) -> Button:
	var b := Button.new()
	b.text = title
	b.disabled = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_horizontal = 0
	b.custom_minimum_size = Vector2(min_w, 34)
	b.size = Vector2(min_w, 34)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	return b


func _make_header_label(title: String, min_w: float) -> Label:
	var l := Label.new()
	l.text = title
	l.size_flags_horizontal = 0
	l.custom_minimum_size = Vector2(min_w, 40)
	l.size = Vector2(min_w, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	return l


func _make_header_column(btn: Button, min_w: float = 82.0) -> Control:
	var box := CenterContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(min_w, 34)
	box.add_child(btn)
	return box


func _make_header_placeholder(min_w: float) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(min_w, 40)
	return box


func _ensure_table_header() -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	if myteam_table_header != null and is_instance_valid(myteam_table_header):
		myteam_table_header.queue_free()

	myteam_table_header = HBoxContainer.new()
	myteam_table_header.name = "MyTeamTableHeader"
	myteam_table_header.custom_minimum_size = Vector2(0, 50)
	myteam_table_header.size = Vector2(maxf(0.0, scroll.size.x - 12.0), 50.0)
	myteam_table_header.position = Vector2(scroll.position.x + 6.0, scroll.position.y - 10.0)
	myteam_table_header.alignment = BoxContainer.ALIGNMENT_CENTER
	myteam_table_header.add_theme_constant_override("separation", 6)
	myteam_table_header.z_index = 50
	myteam_table_header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var avatar_slot := VBoxContainer.new()
	avatar_slot.custom_minimum_size = Vector2(88, 34)
	avatar_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	myteam_table_header.add_child(avatar_slot)

	myteam_table_header.add_child(_make_header_column(_make_header_button("RANK", 58.0, Callable(self, "_on_sort_stars_pressed"), false), 72.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("POS.", 49.0, Callable(self, "_on_sort_poste_pressed"), false), 82.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("AGE", 32.0, Callable(self, "_on_sort_age_pressed"), false), 62.0))
	btn_sort_tir = _make_header_button(tr("player.attr.tir"), 52.0, Callable(self, "_on_sort_tir_pressed"), false)
	myteam_table_header.add_child(_make_header_column(btn_sort_tir, 72.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("SPEED", 58.0, Callable(self, "_on_sort_speed_pressed"), false), 72.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("DEFENSE", 74.0, Callable(self, "_on_sort_defense_pressed"), false), 82.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("ACCURACY", 80.0, Callable(self, "_on_sort_accuracy_pressed"), false), 88.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button(tr("selection.header.motivation"), 64.0, Callable(self, "_on_sort_motivation_pressed"), false), 82.0))
	myteam_table_header.add_child(_make_header_column(_make_header_button("SALARY", 60.0, Callable(self, "_on_sort_salaire_pressed"), false), 92.0))

	if _is_match_selection_unlocked():
		myteam_table_header.add_child(_make_header_column(_make_header_visual_button(tr("myteam.btn.select_to_play"), 112.0), 120.0))
	var sell_header := _make_header_visual_button(tr("myteam.btn.sell"), 90.0)
	sell_header.mouse_filter = Control.MOUSE_FILTER_PASS
	_bm_bind_sell_tooltip(sell_header)
	myteam_table_header.add_child(_make_header_column(sell_header, 110.0))

	add_child(myteam_table_header)


func _sort_players(players: Array) -> void:
	match current_sort:
		"poste":
			players.sort_custom(func(a, b):
				var av := str((a as Dictionary).get("poste", ""))
				var bv := str((b as Dictionary).get("poste", ""))
				return av < bv if sort_ascending else av > bv
			)
		"age":
			players.sort_custom(func(a, b):
				var av := int((a as Dictionary).get("age", 0))
				var bv := int((b as Dictionary).get("age", 0))
				return av < bv if sort_ascending else av > bv
			)
		"stars":
			players.sort_custom(func(a, b):
				var av := _myteam_star_count(a as Dictionary)
				var bv := _myteam_star_count(b as Dictionary)
				return av < bv if sort_ascending else av > bv
			)
		"tir":
			players.sort_custom(func(a, b):
				var av := int((a as Dictionary).get("tir", 0))
				var bv := int((b as Dictionary).get("tir", 0))
				return av < bv if sort_ascending else av > bv
			)
		"vitesse":
			players.sort_custom(func(a, b):
				var av := int((a as Dictionary).get("vitesse", 0))
				var bv := int((b as Dictionary).get("vitesse", 0))
				return av < bv if sort_ascending else av > bv
			)
		"defense":
			players.sort_custom(func(a, b):
				var av := int((a as Dictionary).get("defense", 0))
				var bv := int((b as Dictionary).get("defense", 0))
				return av < bv if sort_ascending else av > bv
			)
		"precision":
			players.sort_custom(func(a, b):
				var av := float((a as Dictionary).get("precision", 0.0))
				var bv := float((b as Dictionary).get("precision", 0.0))
				return av < bv if sort_ascending else av > bv
			)
		"perf":
			players.sort_custom(func(a, b):
				var av := float((a as Dictionary).get("pondération", 0.0))
				var bv := float((b as Dictionary).get("pondération", 0.0))
				return av < bv if sort_ascending else av > bv
			)
		"motivation":
			players.sort_custom(func(a, b):
				var av := float((a as Dictionary).get("motivation", 0.0))
				var bv := float((b as Dictionary).get("motivation", 0.0))
				return av < bv if sort_ascending else av > bv
			)
		"salaire":
			players.sort_custom(func(a, b):
				var av := _myteam_display_salary_annual_from_player(a as Dictionary)
				var bv := _myteam_display_salary_annual_from_player(b as Dictionary)
				return av < bv if sort_ascending else av > bv
			)


func _sell_player(p: Dictionary) -> void:
	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()

	var pid := int(p.get("id", -1))
	if pid < 0:
		return

	if d.has("roster") and typeof(d["roster"]) == TYPE_DICTIONARY:
		var roster: Dictionary = d["roster"]

		if roster.has("selected_ids") and roster["selected_ids"] is Array:
			var selected_ids: Array = (roster["selected_ids"] as Array).duplicate()
			selected_ids.erase(pid)
			roster["selected_ids"] = selected_ids

		if roster.has("players") and roster["players"] is Array:
			var new_roster_players: Array = []
			for row_raw in (roster["players"] as Array):
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue
				var row: Dictionary = row_raw
				if str(row.get("id", "")) == str(pid):
					continue
				new_roster_players.append(row)
			roster["players"] = new_roster_players

		d["roster"] = roster

	if d.has("mercato") and typeof(d["mercato"]) == TYPE_DICTIONARY:
		var m: Dictionary = d["mercato"]
		if m.has("purchased_ids") and m["purchased_ids"] is Array:
			var purchased_ids: Array = (m["purchased_ids"] as Array).duplicate()
			purchased_ids.erase(pid)
			m["purchased_ids"] = purchased_ids
		d["mercato"] = m

	PlayerLife.ensure_finance_schema(d)
	PlayerLife.write_savegame(d)
	_build_team()

func _get_selected_players_real() -> Array:
	Save.ensure_exists(str(Session.profile_uuid))
	var d: Dictionary = Save.read_dict()

	var selected_ids: Array = []
	if d.has("roster") and typeof(d["roster"]) == TYPE_DICTIONARY:
		selected_ids = (d["roster"] as Dictionary).get("selected_ids", [])

	var purchased_ids: Array = []
	if d.has("mercato") and typeof(d["mercato"]) == TYPE_DICTIONARY:
		purchased_ids = ((d["mercato"] as Dictionary).get("purchased_ids", []) as Array).duplicate()
	if purchased_ids.size() > 4:
		purchased_ids = purchased_ids.slice(0, 4)

	var all_players: Array = _avatar_players()
	var by_avatar_id: Dictionary = {}
	for p in all_players:
		by_avatar_id[int(p.get("id", -1))] = p

	var by_saved_id: Dictionary = {}
	if d.has("players_by_id") and typeof(d["players_by_id"]) == TYPE_DICTIONARY:
		by_saved_id = d["players_by_id"] as Dictionary

	var out: Array = []
	var saved_players: Array = []
	if d.has("players") and typeof(d["players"]) == TYPE_ARRAY:
		saved_players = d["players"] as Array

	for pid_v in selected_ids:
		var pid: int = int(pid_v)
		var skey := str(pid)

		if by_saved_id.has(skey) and (by_saved_id[skey] is Dictionary):
			out.append((by_saved_id[skey] as Dictionary).duplicate(true))
			continue

		var found_saved := false
		for jv in saved_players:
			if typeof(jv) == TYPE_DICTIONARY and int((jv as Dictionary).get("id", -1)) == pid:
				out.append((jv as Dictionary).duplicate(true))
				found_saved = true
				break

		if found_saved:
			continue

		if not by_avatar_id.has(pid):
			continue
		var avatar_p: Dictionary = by_avatar_id[pid]
		var j: Dictionary = _bm_init_player_from_avatar(avatar_p)
		out.append(j)

	for pid_v in purchased_ids:
		var pid_txt := str(pid_v).strip_edges()
		if pid_txt == "":
			continue
		var skey := str(int(float(pid_txt)))
		if not by_saved_id.has(skey):
			continue
		if not (by_saved_id[skey] is Dictionary):
			continue
		out.append((by_saved_id[skey] as Dictionary).duplicate(true))

	return out

# ------------------------------------------------------------
# UI
# ------------------------------------------------------------

func _myteam_stat_color(v: int) -> Color:
	if v < 50:
		return Color(0.9, 0.3, 0.3)
	elif v < 70:
		return Color(0.95, 0.75, 0.2)
	else:
		return Color(0.3, 0.9, 0.4)


func _myteam_star_count(p: Dictionary) -> int:
	var tir := int(p.get("tir", 0))
	var vitesse := int(p.get("vitesse", 0))
	var defense := int(p.get("defense", 0))
	var motivation := int(p.get("motivation", 0))
	var avg := int(round(float(tir + vitesse + defense + motivation) / 4.0))
	return clampi(int(round(float(avg) / 20.0)), 1, 5)


func _myteam_stars_text(p: Dictionary) -> String:
	var stars := _myteam_star_count(p)
	return str(stars) + "/5"


func _myteam_display_fatigue_value(p: Dictionary) -> String:
	var raw_fatigue: int = int(p.get("fatigue", p.get("matchs_consecutifs", 0)))
	var locale := TranslationServer.get_locale().to_lower()
	if locale.begins_with("en"):
		return str(clampi(100 - raw_fatigue, 0, 100))
	return str(raw_fatigue)

func _create_player_row(p: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	var pid := int(p.get("id", -1))
	var is_match_selected: bool = (pid in pending_match_ids)
	style.bg_color = (Color(0.92, 0.52, 0.12, 0.30) if is_match_selected else Color(0.03, 0.06, 0.12, 0.26))
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = (Color(1.0, 0.62, 0.20, 0.42) if is_match_selected else Color(1, 1, 1, 0.10))
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)

	var v_avatar := VBoxContainer.new()
	v_avatar.custom_minimum_size = Vector2(82, 84)
	v_avatar.alignment = BoxContainer.ALIGNMENT_CENTER

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(58, 58)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_STOP
	avatar.pivot_offset = avatar.custom_minimum_size * 0.5

	var avatar_path: String = str(p.get("avatar_path", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar.texture = load(avatar_path) as Texture2D
	avatar.mouse_entered.connect(func() -> void:
		avatar.scale = Vector2(1.50, 1.50)
	)
	avatar.mouse_exited.connect(func() -> void:
		avatar.scale = Vector2.ONE
	)
	avatar.gui_input.connect(func(event: InputEvent, player_data := p.duplicate(true)) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_bm_show_player_card_popup(player_data)
				accept_event()
	)

	var first_name := Label.new()
	first_name.text = str(p.get("nom", ""))
	first_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first_name.add_theme_font_size_override("font_size", 20)
	first_name.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	first_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))

	v_avatar.add_child(avatar)
	v_avatar.add_child(first_name)
	h.add_child(v_avatar)

	h.add_child(_cell(_myteam_stars_text(p), 72.0, Color(1.0, 0.78, 0.22, 1.0), true))
	h.add_child(_cell(_tr_poste(str(p.get("poste", ""))), 82.0, Color(0.94, 0.96, 1.0, 1.0), true))
	h.add_child(_cell(str(p.get("age", "")), 62.0, Color(0.94, 0.96, 1.0, 1.0), true))
	h.add_child(_cell(str(int(p.get("tir", 0))), 72.0, Color(0.94, 0.96, 1.0, 1.0), true))
	h.add_child(_cell(str(int(p.get("vitesse", 0))), 72.0, _myteam_stat_color(int(p.get("vitesse", 0))), true))
	h.add_child(_cell(str(int(p.get("defense", 0))), 82.0, _myteam_stat_color(int(p.get("defense", 0))), true))
	h.add_child(_cell("%.2f" % float(p.get("precision", 0.0)), 88.0, _myteam_stat_color(int(p.get("precision", 0))), true))
	h.add_child(_cell(str(int(p.get("motivation", 0))), 82.0, _myteam_stat_color(int(p.get("motivation", 0))), true))
	h.add_child(_cell(_fmt_salary(_myteam_display_salary_annual_from_player(p)), 92.0))

	if _is_match_selection_unlocked():
		var btn_match_select := Button.new()
		btn_match_select.custom_minimum_size = Vector2(46, 46)
		btn_match_select.add_theme_font_size_override("font_size", 18)
		btn_match_select.text = ""
		_bm_style_match_select_button(btn_match_select, is_match_selected)
		btn_match_select.pressed.connect(func(): _toggle_pending_match(pid))
		var match_select_cell := CenterContainer.new()
		match_select_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match_select_cell.custom_minimum_size = Vector2(120.0, 0)
		match_select_cell.add_child(btn_match_select)
		h.add_child(match_select_cell)

	var btn_sell := Button.new()
	btn_sell.custom_minimum_size = Vector2(37, 37)
	btn_sell.text = ""
	_bm_style_sell_row_button(btn_sell, pid in pending_sell_ids)
	btn_sell.pressed.connect(func(): _toggle_pending_sell(pid))
	var sell_cell := CenterContainer.new()
	sell_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_cell.custom_minimum_size = Vector2(110.0, 0)
	sell_cell.add_child(btn_sell)
	h.add_child(sell_cell)

	return panel


func _bm_player_card_close() -> void:
	var existing := get_node_or_null("PlayerCardPopup")
	if existing != null and is_instance_valid(existing):
		existing.queue_free()


func _bm_player_card_position_text(poste: String) -> String:
	match String(poste).strip_edges().to_lower():
		"meneur", "point guard":
			return _bm_myteam_tr_or_fallback("player.position.point_guard", "Point Guard")
		"arrière", "arriere", "shooting guard":
			return _bm_myteam_tr_or_fallback("player.position.shooting_guard", "Shooting Guard")
		"ailier", "small forward":
			return _bm_myteam_tr_or_fallback("player.position.small_forward", "Small Forward")
		"ailier fort", "power forward":
			return _bm_myteam_tr_or_fallback("player.position.point_forward", "Power Forward")
		"pivot", "center":
			return _bm_myteam_tr_or_fallback("player.position.center", "Center")
		_:
			return poste


func _bm_player_card_percent(value: Variant) -> float:
	var f := float(value)
	if f <= 1.5:
		f *= 100.0
	return clampf(f, 0.0, 100.0)


func _bm_player_card_add_label(parent: Control, text_value: String, pos: Vector2, sz: Vector2, fs: int, color: Color, center: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	parent.add_child(lbl)
	return lbl


func _bm_player_card_add_stat(parent: VBoxContainer, label_text: String, value: Variant, keep_decimals: bool = false) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 26)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	row.add_child(lbl)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(180, 10)
	track.color = Color(1, 1, 1, 0.18)
	row.add_child(track)

	var bar := ColorRect.new()
	bar.color = Color(0.95, 0.50, 0.12, 1.0)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(180.0 * (_bm_player_card_percent(value) / 100.0), 10)
	track.add_child(bar)

	var val := Label.new()
	val.text = ("%.2f" % float(value)) if keep_decimals else str(int(round(float(value))))
	val.custom_minimum_size = Vector2(52, 26)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 17)
	val.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	row.add_child(val)



class PlayerProfileQuadrantGraph extends Control:
	var scores: Dictionary = {}

	func set_scores(v: Dictionary) -> void:
		scores = v
		queue_redraw()

	func _draw() -> void:
		_bm_draw_duel_graph(Vector2(50.0, 76.0), 50.8, "attaque", "defense", tr("player.card.graph.attack"), tr("player.card.graph.defense"), Color(0.88, 0.32, 0.12, 0.94), Color(0.24, 0.47, 0.68, 0.94))
		_bm_draw_duel_graph(Vector2(176.0, 76.0), 50.8, "physique", "mental", tr("player.card.graph.physical"), tr("player.card.graph.mental"), Color(0.88, 0.62, 0.18, 0.94), Color(0.48, 0.30, 0.62, 0.94))

	func _bm_draw_duel_graph(center: Vector2, radius: float, key_a: String, key_b: String, label_a: String, label_b: String, color_a: Color, color_b: Color) -> void:
		var value_a := clampf(float(scores.get(key_a, 0.0)), 0.0, 100.0)
		var value_b := clampf(float(scores.get(key_b, 0.0)), 0.0, 100.0)
		var total: float = max(1.0, value_a + value_b)
		var split_angle: float = -PI * 0.5 + TAU * (value_a / total)
		var font := get_theme_default_font()

		_bm_draw_sector(center, radius, -PI * 0.5, split_angle, color_a)
		_bm_draw_sector(center, radius, split_angle, -PI * 0.5 + TAU, color_b)
		draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.38), 2.0)
		draw_circle(center, radius * 0.16, Color(0.04, 0.07, 0.12, 0.88))

		var mid_a: float = (-PI * 0.5 + split_angle) * 0.5
		var mid_b: float = (split_angle + (-PI * 0.5 + TAU)) * 0.5
		var pos_a := center + Vector2(cos(mid_a), sin(mid_a)) * (radius * 0.52)
		var pos_b := center + Vector2(cos(mid_b), sin(mid_b)) * (radius * 0.52)
		draw_string(font, pos_a - Vector2(13, -6), str(int(round(value_a))), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 1))
		draw_string(font, pos_b - Vector2(13, -6), str(int(round(value_b))), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 1))
		draw_string(font, center + Vector2(-34, -60), label_a, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.94))
		draw_string(font, center + Vector2(-22, 66), label_b, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.94))
		draw_line(center + Vector2(-11, -39), center + Vector2(-20, -53), Color(1, 1, 1, 0.62), 1.0)
		draw_line(center + Vector2(14, 39), center + Vector2(32, 58), Color(1, 1, 1, 0.62), 1.0)

	func _bm_draw_sector(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
		var pts: PackedVector2Array = [center]
		for step in range(25):
			var a: float = start_angle + ((end_angle - start_angle) * float(step) / 24.0)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_polygon(pts, PackedColorArray([color]))


func _bm_player_profile_scores(data: Dictionary) -> Dictionary:
	var precision := float(data.get("precision", 0.0))
	if precision <= 1.5:
		precision *= 100.0
	var pct_2pts := float(data.get("pct_2pts", precision))
	if pct_2pts <= 1.5:
		pct_2pts *= 100.0
	var pct_3pts := float(data.get("pct_3pts", precision))
	if pct_3pts <= 1.5:
		pct_3pts *= 100.0
	var attaque := (float(data.get("tir", 0)) + precision + pct_2pts + pct_3pts) / 4.0
	var defense_score := float(data.get("defense", 0))
	var mental := float(data.get("motivation", 0))
	var fatigue_score := 100.0 - float(data.get("fatigue", 0))
	var physique := (float(data.get("vitesse", 0)) + float(data.get("endurance", 0)) + fatigue_score) / 3.0
	return {
		"attaque": clampf(attaque, 0.0, 100.0),
		"defense": clampf(defense_score, 0.0, 100.0),
		"mental": clampf(mental, 0.0, 100.0),
		"physique": clampf(physique, 0.0, 100.0),
	}



func _bm_show_player_graph_tooltip(card: Control, anchor: Control, text_value: String) -> void:
	var tooltip := card.get_node_or_null("PlayerProfileGraphCustomTooltip") as Panel
	if tooltip == null:
		tooltip = Panel.new()
		tooltip.name = "PlayerProfileGraphCustomTooltip"
		tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip.z_index = 80
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.03, 0.06, 0.96)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(1.0, 0.58, 0.14, 0.65)
		tooltip.add_theme_stylebox_override("panel", sb)
		card.add_child(tooltip)

		var lbl := Label.new()
		lbl.name = "LblGraphTooltip"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = Vector2(12, 10)
		lbl.size = Vector2(414, 102)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		tooltip.add_child(lbl)

	var tooltip_h := 118.0
	var label := tooltip.get_node_or_null("LblGraphTooltip") as Label
	if label != null:
		var display_text := text_value
		var line_count: int = max(1, display_text.split("\n").size())
		tooltip_h = max(118.0, float(line_count) * 24.0 + 38.0)
		label.text = display_text
		label.size = Vector2(414, tooltip_h - 12.0)

	tooltip.size = Vector2(442, tooltip_h)
	var desired := Vector2(anchor.position.x, -tooltip.size.y - 8.0)
	var max_x: float = max(0.0, card.size.x - tooltip.size.x - 12.0)
	tooltip.position = Vector2(clampf(desired.x, 12.0, max_x), desired.y)
	tooltip.visible = true
	card.move_child(tooltip, card.get_child_count() - 1)


func _bm_hide_player_graph_tooltip(card: Control) -> void:
	var tooltip := card.get_node_or_null("PlayerProfileGraphCustomTooltip") as Control
	if tooltip != null:
		tooltip.visible = false

func _bm_add_player_profile_graph(card: Control, data: Dictionary) -> void:
	var graph := PlayerProfileQuadrantGraph.new()
	graph.name = "PlayerProfileGraph"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.size = Vector2(249, 249)
	graph.position = Vector2(488, 24)
	graph.set_scores(_bm_player_profile_scores(data))
	card.add_child(graph)

	var graph_tip_left := Control.new()
	graph_tip_left.name = "PlayerProfileGraphAttackDefenseTooltipArea"
	graph_tip_left.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_tip_left.size = Vector2(118, graph.size.y)
	graph_tip_left.position = graph.position
	graph_tip_left.tooltip_text = ""
	graph_tip_left.mouse_entered.connect(func() -> void:
		_bm_show_player_graph_tooltip(card, graph_tip_left, tr("player.card.graph.tooltip.attack_defense"))
	)
	graph_tip_left.mouse_exited.connect(func() -> void:
		_bm_hide_player_graph_tooltip(card)
	)
	card.add_child(graph_tip_left)

	var graph_tip_right := Control.new()
	graph_tip_right.name = "PlayerProfileGraphPhysicalMentalTooltipArea"
	graph_tip_right.mouse_filter = Control.MOUSE_FILTER_STOP
	graph_tip_right.size = Vector2(131, graph.size.y)
	graph_tip_right.position = graph.position + Vector2(118, 0)
	graph_tip_right.tooltip_text = ""
	graph_tip_right.mouse_entered.connect(func() -> void:
		_bm_show_player_graph_tooltip(card, graph_tip_right, tr("player.card.graph.tooltip.physical_mental"))
	)
	graph_tip_right.mouse_exited.connect(func() -> void:
		_bm_hide_player_graph_tooltip(card)
	)
	card.add_child(graph_tip_right)

func _bm_show_player_card_popup(data: Dictionary) -> void:
	if get_node_or_null("PlayerCardPopup") != null:
		return

	var popup := Control.new()
	popup.name = "PlayerCardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 320
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.62)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card_w := 792.0
	var card_h := 430.0
	var card := Panel.new()
	card.name = "PlayerCard"
	card.size = Vector2(card_w, card_h)
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.position = Vector2((get_viewport_rect().size.x - card_w) * 0.5, (get_viewport_rect().size.y - card_h) * 0.5)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.035, 0.075, 0.98)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.58, 0.14, 0.72)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 7)
	card.add_theme_stylebox_override("panel", sb)
	popup.add_child(card)

	var avatar_path := str(data.get("avatar_path", ""))
	var avatar_big := TextureRect.new()
	avatar_big.position = Vector2(34, 82)
	avatar_big.size = Vector2(190, 190)
	avatar_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar_big.texture = load(avatar_path) as Texture2D
	card.add_child(avatar_big)
	_bm_add_player_profile_graph(card, data)

	_bm_player_card_add_label(card, str(data.get("nom", data.get("name", ""))), Vector2(24, 278), Vector2(210, 44), 34, Color(1, 1, 1, 1), true)

	var badge := Panel.new()
	badge.position = Vector2(34, 326)
	badge.size = Vector2(210, 34)
	var sb_badge := StyleBoxFlat.new()
	sb_badge.bg_color = Color(0.95, 0.48, 0.10, 1.0)
	sb_badge.corner_radius_top_left = 17
	sb_badge.corner_radius_top_right = 17
	sb_badge.corner_radius_bottom_left = 17
	sb_badge.corner_radius_bottom_right = 17
	badge.add_theme_stylebox_override("panel", sb_badge)
	card.add_child(badge)
	_bm_player_card_add_label(badge, _bm_player_card_position_text(str(data.get("poste", data.get("pos", "")))), Vector2(12, 2), Vector2(186, 30), 18, Color(1, 1, 1, 1), true)

	_bm_player_card_add_label(card, _bm_myteam_tr_or_fallback("player.card.age", "Age") + " : " + str(int(float(data.get("age", 0)))), Vector2(254, 130), Vector2(210, 28), 20, Color(0.92, 0.95, 1.0, 1.0))
	_bm_player_card_add_label(card, _bm_myteam_tr_or_fallback("player.card.salary", "Salary") + " : " + _fmt_salary(_myteam_display_salary_annual_from_player(data)), Vector2(254, 160), Vector2(300, 28), 20, Color(0.92, 0.95, 1.0, 1.0))
	if data.has("pondération") or data.has("ponderation") or data.has("stars"):
		var rating := str(data.get("pondération", data.get("ponderation", data.get("stars", ""))))
		_bm_player_card_add_label(card, _bm_myteam_tr_or_fallback("player.card.rating", "Rating") + " : " + rating, Vector2(254, 100), Vector2(260, 30), 22, Color(1.0, 0.78, 0.22, 1.0))

	var stats := VBoxContainer.new()
	stats.position = Vector2(254, 230)
	stats.size = Vector2(420, 170)
	stats.add_theme_constant_override("separation", 3)
	card.add_child(stats)
	if data.has("tir"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.shooting", "Shooting"), data.get("tir"))
	if data.has("vitesse"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.speed", "Speed"), data.get("vitesse"))
	if data.has("defense"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.defense", "Defense"), data.get("defense"))
	if data.has("precision"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.accuracy", "Accuracy"), data.get("precision"), true)
	if data.has("motivation"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.motivation", "Motivation"), data.get("motivation"))
	if data.has("endurance"):
		_bm_player_card_add_stat(stats, _bm_myteam_tr_or_fallback("player.card.endurance", "Endurance"), data.get("endurance"))

	if bool(data.get("blessure", false)):
		_bm_player_card_add_label(card, _bm_myteam_tr_or_fallback("player.card.injured", "Injured"), Vector2(34, 292), Vector2(190, 30), 20, Color(1.0, 0.35, 0.35, 1.0), true)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.position = Vector2(card_w - 52.0, 14.0)
	btn_close.size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(_bm_player_card_close)
	card.add_child(btn_close)


func _cell(value: String, min_w: float = 82.0, font_color: Color = Color(0.94, 0.96, 1.0, 1.0), mobile_plus2: bool = false) -> Control:
	var box := CenterContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(min_w, 0)

	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_color_override("font_color", font_color)
	v.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	var cell_fs: int = 20
	if _bm_myteam_is_mobile_layout():
		cell_fs = 24
	v.add_theme_font_size_override("font_size", cell_fs)
	if mobile_plus2:
		v.set_meta("bm_myteam_mobile_content_plus2", true)

	box.add_child(v)
	return box

func _myteam_display_salary_annual_from_player(p: Dictionary) -> int:
	var sal := int(p.get("salaire", p.get("salary", 0)))
	if sal >= 50000:
		return sal
	var perf := float(p.get("pondération", p.get("ponderation", p.get("overall", p.get("rating", 0)))))
	if perf > 0.0:
		return clampi(int(round(70000.0 + perf * 500.0)), 70000, 130000)
	return maxi(0, sal)

func _fmt_salary(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s.substr(i, 1) + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out + " €"

# ------------------------------------------------------------
# Helpers repris de Selection.gd pour garantir la même logique
# ------------------------------------------------------------

func _bm_rng_for_pid(pid: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pid) * 1103515245 + 12345
	return rng

func _bm_calc_ponderation(j: Dictionary) -> float:
	var poste: String = str(j.get("poste", ""))
	var precision: float = float(j.get("precision", 0.75)) * 100.0
	var tir: float = float(j.get("tir", precision))
	var vitesse: float = float(j.get("vitesse", 70))
	var force: float = float(j.get("force", 70))
	var defense: float = float(j.get("defense", 70))
	var endurance: float = float(j.get("endurance", 70))

	var ponderation: float = 0.0
	if poste == "Meneur":
		ponderation = precision * 0.20 + tir * 0.10 + vitesse * 0.30 + endurance * 0.20 + defense * 0.10 + force * 0.10
	elif poste == "Ailier":
		ponderation = precision * 0.18 + tir * 0.12 + vitesse * 0.22 + force * 0.20 + defense * 0.13 + endurance * 0.15
	elif poste == "Pivot":
		ponderation = force * 0.30 + defense * 0.25 + precision * 0.10 + tir * 0.05 + endurance * 0.15 + vitesse * 0.15
	elif poste == "Arrière":
		ponderation = precision * 0.18 + tir * 0.10 + vitesse * 0.28 + endurance * 0.20 + defense * 0.14 + force * 0.10
	else:
		ponderation = precision * 0.18 + tir * 0.10 + vitesse * 0.22 + force * 0.20 + defense * 0.15 + endurance * 0.15

	var age: int = int(j.get("age", 25))
	var coef_age: float = 1.0
	if age <= 22:
		coef_age = 0.9
	elif age <= 26:
		coef_age = 1.0
	elif age <= 30:
		coef_age = 1.05
	elif age <= 34:
		coef_age = 0.95
	else:
		coef_age = 0.85
	ponderation *= coef_age

	var matchs_consecutifs: int = int(j.get("matchs_consecutifs", 0))
	var coef_matchs_consecutifs: float = 1.0
	if matchs_consecutifs >= 8:
		coef_matchs_consecutifs = 0.92
	elif matchs_consecutifs >= 6:
		coef_matchs_consecutifs = 0.95
	elif matchs_consecutifs >= 6:
		coef_matchs_consecutifs = 0.98
	ponderation *= coef_matchs_consecutifs

	var repos: int = int(j.get("repos_consecutifs", 0))
	if repos > 0:
		var coef_repos := 1.0
		if repos == 1:
			coef_repos = 1.02
		elif repos == 2:
			coef_repos = 1.04
		elif repos == 3:
			coef_repos = 1.00
		elif repos == 4:
			coef_repos = 0.96
		else:
			coef_repos = 0.92
		ponderation *= coef_repos

	var est_blesse := bool(j.get("blessure", false)) or int(j.get("matches_conval", 0)) > 0
	if est_blesse:
		ponderation *= (1.0 - 0.30)

	var motivation: float = float(j.get("motivation", 80))
	ponderation *= 1.0 + (motivation - 80.0) / 200.0

	return snapped(ponderation, 0.01)

func _bm_init_player_from_avatar(p: Dictionary) -> Dictionary:
	var pid: int = int(p.get("id", -1))
	var rng := _bm_rng_for_pid(pid)

	var postes: Array[String] = ["Meneur", "Ailier", "Pivot", "Arrière"]
	var poste: String = postes[rng.randi_range(0, postes.size() - 1)]
	var age: int = rng.randi_range(18, 35)

	var precision: float = rng.randf_range(0.60, 0.95)
	var tir: int = rng.randi_range(55, 95)
	var vitesse: int = rng.randi_range(55, 95)
	var force: int = rng.randi_range(55, 95)
	var defense: int = rng.randi_range(55, 95)
	var endurance: int = rng.randi_range(55, 95)

	var j: Dictionary = {
		"id": pid,
		"avatar_key": str(p.get("avatar_key", "")),
		"avatar_path": str(p.get("avatar_path", "")),
		"nom": str(p.get("name", "")),
		"poste": poste,
		"age": age,
		"precision": precision,
		"tir": tir,
		"vitesse": vitesse,
		"force": force,
		"defense": defense,
		"endurance": endurance,
		"matchs_consecutifs": 0,
		"repos_consecutifs": 0,
		"fatigue": 0,
		"blessure": false,
		"matches_conval": 0
	}

	j["pondération"] = _bm_calc_ponderation(j)

	var base_motivation: int = 80
	if age < 23:
		base_motivation = rng.randi_range(75, 95)
	elif age > 30:
		base_motivation = rng.randi_range(60, 80)
	else:
		base_motivation = rng.randi_range(65, 90)

	if float(j["pondération"]) > 80.0:
		base_motivation += 5
	elif float(j["pondération"]) < 65.0:
		base_motivation -= 5

	j["motivation"] = clamp(base_motivation, 50, 100)

	var salaire_int: int = int(70000 + float(j["pondération"]) * 500.0)
	salaire_int = clamp(salaire_int, 70000, 130000)
	j["salaire"] = salaire_int

	return j

func _load_avatar_meta() -> void:
	avatar_meta.clear()
	var path := "res://data/avatars_meta.csv"
	if not FileAccess.file_exists(path):
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return

	var text := f.get_as_text().replace("\r", "")
	var lines := text.split("\n", false)

	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if line == "" or i == 0:
			continue
		var parts := line.split(",", false)
		if parts.size() < 3:
			continue
		var k := parts[0].strip_edges()
		var g := parts[1].strip_edges()
		var n := parts[2].strip_edges()
		if k == "" or n == "":
			continue
		avatar_meta[k] = {"gender": g, "first_name": n}

func _avatar_players() -> Array:
	var arr: Array = []
	var base_root: String = "res://assets/images/avatars"
	var dir := DirAccess.open(base_root)
	if dir == null:
		return arr

	dir.list_dir_begin()
	while true:
		var fn := dir.get_next()
		if fn == "":
			break
		if dir.current_is_dir():
			continue
		var low := fn.to_lower()
		if not (low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp")):
			continue

		var stem := fn.get_basename()
		var avatar_key := stem
		var name := stem.replace("_", " ").capitalize()

		if avatar_meta.has(avatar_key):
			var meta: Dictionary = avatar_meta[avatar_key]
			name = str(meta.get("first_name", name))

		arr.append({
			"id": arr.size(),
			"name": name,
			"avatar_key": avatar_key,
			"avatar_path": base_root + "/" + fn
		})

	dir.list_dir_end()
	return arr


func _tr_poste(poste: String) -> String:
	match String(poste).strip_edges().to_lower():
		"meneur", "point guard":
			return "P.G."
		"arrière", "arriere", "shooting guard":
			return "S.G."
		"ailier", "small forward":
			return "S.F."
		"ailier fort", "power forward":
			return "P.F."
		"pivot", "center":
			return "C."
		_:
			return poste


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_bm_myteam_apply_mobile_landscape_scroll")
		call_deferred("_bm_myteam_lock_mobile_layout_positions")


func _bm_myteam_apply_mobile_row_texts_plus2() -> void:
	if not _bm_myteam_is_mobile_layout():
		return
	if rows == null:
		return

	for row in rows.get_children():
		if row == null:
			continue

		for lbl_node in row.find_children("*", "Label", true, false):
			var lbl := lbl_node as Label
			if lbl == null:
				continue
			if not bool(lbl.get_meta("bm_myteam_mobile_content_plus2", false)):
				continue
			if lbl.has_meta("bm_myteam_mobile_row_text_plus2_done"):
				continue
			lbl.set_meta("bm_myteam_mobile_row_text_plus2_done", true)
			var fs: int = int(lbl.get_theme_font_size("font_size"))
			if fs > 0:
				lbl.add_theme_font_size_override("font_size", fs + 2)

	for lbl_avg in [lbl_avg_age, lbl_avg_perf, lbl_avg_salary]:
		if lbl_avg == null:
			continue
		if lbl_avg.has_meta("bm_myteam_mobile_avg_plus2_done"):
			continue
		lbl_avg.set_meta("bm_myteam_mobile_avg_plus2_done", true)
		var afs: int = int(lbl_avg.get_theme_font_size("font_size"))
		if afs > 0:
			lbl_avg.add_theme_font_size_override("font_size", afs + 1)

	if lbl_total_salary != null and not lbl_total_salary.has_meta("bm_myteam_mobile_total_plus2_done"):
		lbl_total_salary.set_meta("bm_myteam_mobile_total_plus2_done", true)
		var tfs: int = int(lbl_total_salary.get_theme_font_size("font_size"))
		if tfs > 0:
			lbl_total_salary.add_theme_font_size_override("font_size", tfs + 4)
			lbl_total_salary.add_theme_constant_override("outline_size", 1)
			lbl_total_salary.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))


func _input(event: InputEvent) -> void:
	if not _bm_myteam_is_mobile_layout():
		return
	if scroll == null:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_bm_myteam_touch_scroll_active = touch.pressed
		_bm_myteam_touch_last_y = touch.position.y
		return

	if event is InputEventScreenDrag and _bm_myteam_touch_scroll_active:
		var drag := event as InputEventScreenDrag

		var vbar := scroll.get_v_scroll_bar()
		var hbar := scroll.get_h_scroll_bar()

		scroll.scroll_vertical = clampi(
			scroll.scroll_vertical - int(drag.relative.y),
			0,
			int(vbar.max_value) if vbar != null else 999999
		)

		scroll.scroll_horizontal = clampi(
			scroll.scroll_horizontal - int(drag.relative.x),
			0,
			int(hbar.max_value) if hbar != null else 999999
		)

		get_viewport().set_input_as_handled()


func _bm_myteam_apply_mobile_landscape_confirm_sell_right() -> void:
	if not _bm_myteam_is_mobile_landscape():
		return
	if btn_confirm_sell == null:
		return

	var vp: Vector2 = get_viewport_rect().size
	btn_confirm_sell.anchor_left = 1.0
	btn_confirm_sell.anchor_right = 1.0
	btn_confirm_sell.offset_left = -330.0
	btn_confirm_sell.offset_right = -124.0
	btn_confirm_sell.position.x = vp.x - 330.0


func _bm_myteam_lock_mobile_layout_positions() -> void:
	if not _bm_myteam_is_mobile_layout():
		return

	var vp: Vector2 = get_viewport_rect().size

	if myteam_table_header != null and is_instance_valid(myteam_table_header) and scroll != null:
		myteam_table_header.position = Vector2(scroll.position.x + 6.0, scroll.position.y - 10.0)
		myteam_table_header.size = Vector2(maxf(0.0, scroll.size.x - 12.0), 50.0)

	if lbl_avg_age != null:
		lbl_avg_age.anchor_left = 1.0
		lbl_avg_age.anchor_right = 1.0
		lbl_avg_age.position = Vector2(vp.x - 410.0, 24.0)
		lbl_avg_age.size = Vector2(380.0, 24.0)

	if lbl_avg_perf != null:
		lbl_avg_perf.anchor_left = 1.0
		lbl_avg_perf.anchor_right = 1.0
		lbl_avg_perf.position = Vector2(vp.x - 410.0, 50.0)
		lbl_avg_perf.size = Vector2(380.0, 24.0)

	if lbl_avg_salary != null:
		lbl_avg_salary.anchor_left = 1.0
		lbl_avg_salary.anchor_right = 1.0
		lbl_avg_salary.position = Vector2(vp.x - 410.0, 76.0)
		lbl_avg_salary.size = Vector2(380.0, 24.0)
