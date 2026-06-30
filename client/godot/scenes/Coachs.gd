extends Control
@onready var title_hover: Control = get_node_or_null("TitleHover") as Control
@onready var title_tooltip_panel: Panel = get_node_or_null("TitleTooltipPanel") as Panel
@onready var title_tooltip_label: Label = get_node_or_null("TitleTooltipPanel/TitleTooltipLabel") as Label
@onready var lbl_title_coachs: Label = get_node_or_null("Title") as Label
@onready var quote_coach_junior: RichTextLabel = get_node_or_null("ScrollCoachs/Content/QuoteCoachJunior") as RichTextLabel
@onready var quote_coach_confirme: RichTextLabel = get_node_or_null("ScrollCoachs/Content/QuoteCoachConfirme") as RichTextLabel
@onready var quote_coach_elite: RichTextLabel = get_node_or_null("ScrollCoachs/Content/QuoteCoachElite") as RichTextLabel


const PL = preload("res://scripts/PlayerLife.gd")
const SaveRef = preload("res://scripts/Save.gd")

const COACH_UI_CONFIG := {
	"coach_junior": {
		"contract_text": "Contract: 2 seasons",
		"payment_text": "Payment: euros / tokens / mix"
	},
	"coach_confirme": {
		"contract_text": "Contract: 3 seasons",
		"payment_text": "Payment: euros / tokens / mix"
	},
	"coach_elite": {
		"contract_text": "Contract: 2 seasons",
		"payment_text": "Payment: euros / tokens / mix"
	}
}

@onready var BtnBack: Button = get_node_or_null("BtnBack") as Button
@onready var BtnCoachJunior: Button = get_node_or_null("ScrollCoachs/Content/BtnCoachJunior") as Button
@onready var BtnCoachConfirme: Button = get_node_or_null("ScrollCoachs/Content/BtnCoachConfirme") as Button
@onready var BtnCoachElite: Button = get_node_or_null("ScrollCoachs/Content/BtnCoachElite") as Button

@onready var LblCoachJunior: Label = get_node_or_null("ScrollCoachs/Content/LblCoachJunior") as Label
@onready var LblCoachConfirme: Label = get_node_or_null("ScrollCoachs/Content/LblCoachConfirme") as Label
@onready var LblCoachElite: Label = get_node_or_null("ScrollCoachs/Content/LblCoachElite") as Label

@onready var LblIntro: Label = get_node_or_null("LblIntro") as Label
@onready var ImgCoachJunior: TextureRect = get_node_or_null("ImgCoachJunior") as TextureRect
@onready var ImgCoachConfirme: TextureRect = get_node_or_null("ImgCoachConfirme") as TextureRect
@onready var ImgCoachElite: TextureRect = get_node_or_null("ImgCoachElite") as TextureRect

@onready var InfoPanel: Panel = get_node_or_null("InfoPanel") as Panel
@onready var LblInfo: Label = get_node_or_null("InfoPanel/LblInfo") as Label
@onready var LblTokensAvailable: Label = get_node_or_null("InfoPanel/LblTokensAvailable") as Label
@onready var LblInfoTokens: Label = get_node_or_null("InfoPanel/LblInfoTokens") as Label
@onready var BtnBuyCoach: Button = get_node_or_null("InfoPanel/BtnBuyCoach") as Button
@onready var LblInfoError: Label = get_node_or_null("InfoPanel/LblInfoError") as Label
@onready var BtnCloseInfoPanel: Button = get_node_or_null("InfoPanel/BtnCloseInfoPanel") as Button

@onready var BtnUnlockJunior: Button = get_node_or_null("ScrollCoachs/Content/UnlockJunior/BtnUnlock") as Button
@onready var BtnUnlockConfirme: Button = get_node_or_null("ScrollCoachs/Content/UnlockConfirme/BtnUnlock") as Button
@onready var BtnUnlockElite: Button = get_node_or_null("ScrollCoachs/Content/UnlockElite/BtnUnlock") as Button

@onready var UnlockJunior: Control = get_node_or_null("ScrollCoachs/Content/UnlockJunior") as Control
@onready var UnlockConfirme: Control = get_node_or_null("ScrollCoachs/Content/UnlockConfirme") as Control
@onready var UnlockElite: Control = get_node_or_null("ScrollCoachs/Content/UnlockElite") as Control


var selected_coach_id: String = ""

func _bm_get_contract_duration(coach_id: String) -> int:
	match coach_id:
		"coach_junior":
			return 2
		"coach_confirme":
			return 3
		"coach_elite":
			return 2
		_:
			return 1

func _bm_get_active_coach_id() -> String:
	var d: Dictionary = SaveRef.read_dict()
	if d.is_empty():
		return ""
	PL.ensure_progression_wallet_schema(d)
	var coachs: Dictionary = d.get("coachs", {}) as Dictionary
	return str(coachs.get("active", "")).strip_edges()

func _bm_get_seasons_progress_text(coach_id: String) -> String:
	var d: Dictionary = SaveRef.read_dict()
	if d.is_empty():
		return ""
	PL.ensure_progression_wallet_schema(d)
	var coachs: Dictionary = d.get("coachs", {}) as Dictionary
	var active_id: String = str(coachs.get("active", "")).strip_edges()
	if active_id != coach_id:
		return ""

	var duration: int = _bm_get_contract_duration(coach_id)
	var current_season: int = maxi(1, int(d.get("season_number", 1)))
	var hired_season: int = maxi(1, int(coachs.get("last_hired_season", current_season)))
	var used: int = maxi(1, current_season - hired_season + 1)
	used = mini(used, duration)
	return "Seasons : %d/%d" % [used, duration]

func _bm_ensure_seasons_label(parent_node: Control, label_name: String, x: float, y: float, txt: String) -> void:
	if parent_node == null:
		return
	var lbl := parent_node.get_node_or_null(label_name) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = label_name
		parent_node.add_child(lbl)
	lbl.text = txt
	lbl.visible = (txt != "")
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(152, 36)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 0.98))
	lbl.add_theme_constant_override("outline_size", 4)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.14, 0.28, 0.92)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.25, 0.62, 1.0, 0.95)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 4
	lbl.add_theme_stylebox_override("normal", sb)

func _bm_apply_unlock_visual(node: Control, enabled_visual: bool) -> void:
	if node == null:
		return
	node.modulate = (Color(1, 1, 1, 1) if enabled_visual else Color(0.45, 0.45, 0.45, 0.92))

func _bm_refresh_active_coach_visuals() -> void:
	var active_id: String = _bm_get_active_coach_id()
	var contract_running: bool = (active_id != "")

	_bm_apply_unlock_visual(UnlockJunior, active_id == "" or active_id == "coach_junior")
	_bm_apply_unlock_visual(UnlockConfirme, active_id == "" or active_id == "coach_confirme")
	_bm_apply_unlock_visual(UnlockElite, active_id == "" or active_id == "coach_elite")

	if BtnUnlockJunior != null:
		BtnUnlockJunior.disabled = contract_running
	if BtnUnlockConfirme != null:
		BtnUnlockConfirme.disabled = contract_running
	if BtnUnlockElite != null:
		BtnUnlockElite.disabled = contract_running

	var content_root := get_node_or_null("ScrollCoachs/Content") as Control
	if content_root == null:
		content_root = self

	_bm_ensure_seasons_label(content_root, "LblSeasonsJunior", 250.0, 146.0, _bm_get_seasons_progress_text("coach_junior"))
	_bm_ensure_seasons_label(content_root, "LblSeasonsConfirme", 250.0, 506.0, _bm_get_seasons_progress_text("coach_confirme"))
	_bm_ensure_seasons_label(content_root, "LblSeasonsElite", 250.0, 846.0, _bm_get_seasons_progress_text("coach_elite"))

func _ready() -> void:
	_bm_apply_coach_quotes_i18n()
	_bm_setup_title_tooltip()
	if BtnBack != null:
		BtnBack.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		BtnBack.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
		BtnBack.add_theme_font_size_override("font_size", 22)

		var sb_normal := StyleBoxFlat.new()
		sb_normal.bg_color = Color(0.90, 0.05, 0.05, 1.0)
		sb_normal.corner_radius_top_left = 10
		sb_normal.corner_radius_top_right = 10
		sb_normal.corner_radius_bottom_left = 10
		sb_normal.corner_radius_bottom_right = 10
		sb_normal.border_width_bottom = 3
		sb_normal.border_color = Color(0.60, 0.0, 0.0, 1.0)
		sb_normal.shadow_color = Color(0, 0, 0, 0.35)
		sb_normal.shadow_size = 6
		sb_normal.shadow_offset = Vector2(0, 4)
		sb_normal.content_margin_left = 20
		sb_normal.content_margin_right = 20
		sb_normal.content_margin_top = 10
		sb_normal.content_margin_bottom = 10

		var sb_hover := sb_normal.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(1.0, 0.10, 0.10, 1.0)
		sb_hover.border_width_bottom = 4
		sb_hover.shadow_color = Color(0, 0, 0, 0.45)
		sb_hover.shadow_size = 8

		var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
		sb_pressed.bg_color = Color(0.70, 0.02, 0.02, 1.0)
		sb_pressed.border_width_bottom = 2
		sb_pressed.shadow_color = Color(0, 0, 0, 0.25)
		sb_pressed.shadow_size = 4

		BtnBack.add_theme_stylebox_override("normal", sb_normal)
		BtnBack.add_theme_stylebox_override("hover", sb_hover)
		BtnBack.add_theme_stylebox_override("pressed", sb_pressed)
	if BtnBack != null and not BtnBack.pressed.is_connected(_on_btn_back):
		BtnBack.pressed.connect(_on_btn_back)

	if BtnCoachJunior != null and not BtnCoachJunior.pressed.is_connected(_on_btn_coach_junior):
		BtnCoachJunior.pressed.connect(_on_btn_coach_junior)

	if BtnCoachConfirme != null and not BtnCoachConfirme.pressed.is_connected(_on_btn_coach_confirme):
		BtnCoachConfirme.pressed.connect(_on_btn_coach_confirme)

	if BtnCoachElite != null and not BtnCoachElite.pressed.is_connected(_on_btn_coach_elite):
		BtnCoachElite.pressed.connect(_on_btn_coach_elite)

	_connect_unlock_capsules()
	_bm_refresh_active_coach_visuals()
	_setup_buy_button_style()
	if BtnBuyCoach != null and not BtnBuyCoach.pressed.is_connected(_on_btn_buy_coach):
		BtnBuyCoach.pressed.connect(_on_btn_buy_coach)
		BtnBuyCoach.text = tr("common.confirm")
	if BtnCloseInfoPanel != null and not BtnCloseInfoPanel.pressed.is_connected(_on_btn_close_info_panel):
		BtnCloseInfoPanel.pressed.connect(_on_btn_close_info_panel)

	if InfoPanel != null:
		InfoPanel.visible = false

	_fill_inline_label("coach_junior", LblCoachJunior)
	_fill_inline_label("coach_confirme", LblCoachConfirme)
	_fill_inline_label("coach_elite", LblCoachElite)


func _on_btn_back() -> void:
	var tree := get_tree()
	if tree == null:
		print("[COACHS][ERR] get_tree() is null")
		return
	var path := "res://scenes/Menu.tscn"
	print("[COACHS] change_scene_to_file path=", path, " exists=", ResourceLoader.exists(path))
	var err := tree.change_scene_to_file(path)
	print("[COACHS] change_scene_to_file err=", err)

func _coach_status_text(coach_id: String) -> String:
	var save: Dictionary = PL.load_savegame()
	PL.ensure_progression_wallet_schema(save)

	var unlocked: bool = PL.is_coachs_unlocked(save)
	var coachs: Dictionary = save.get("coachs", {}) as Dictionary
	var owned: Array = (coachs.get("owned", []) as Array)

	if owned.has(coach_id):
		return "Owned"
	if unlocked:
		return "Available"
	return "Locked"



func _get_displayed_tokens_cost(coach_id: String) -> int:
	var node: Node = null
	match coach_id:
		"coach_junior":
			node = get_node_or_null("ScrollCoachs/Content/UnlockJunior")
		"coach_confirme":
			node = get_node_or_null("ScrollCoachs/Content/UnlockConfirme")
		"coach_elite":
			node = get_node_or_null("ScrollCoachs/Content/UnlockElite")
		_:
			node = null

	var ui_amount: int = 0
	if node != null:
		ui_amount = maxi(0, int(node.get("amount")))

	if ui_amount > 0:
		return ui_amount

	var data: Dictionary = PL.get_coach_price_data(coach_id)
	return maxi(0, int(data.get("tokens_cost", 0)))


func _fmt_int_spaces(v: int) -> String:
	var s: String = str(maxi(0, int(v)))
	var out: String = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func _fill_inline_label(coach_id: String, lbl: Label) -> void:
	if lbl == null:
		return

	var data: Dictionary = PL.get_coach_price_data(coach_id)
	if data.is_empty():
		lbl.text = "Coach data unavailable"
		return

	var coach_cfg: Dictionary = COACH_UI_CONFIG.get(coach_id, {
		"contract_text": "Contract: -",
		"payment_text": "Payment: -"
	}) as Dictionary
	var contract_txt: String = str(coach_cfg.get("contract_text", "Contract: -"))
	var payment_txt: String = str(coach_cfg.get("payment_text", "Payment: -"))

	var euros_cost: int = int(data.get("euros_cost", 0))
	var tokens_cost: int = _get_displayed_tokens_cost(coach_id)
	var status_txt: String = _coach_status_text(coach_id)
	var owned: bool = (status_txt == "Owned")
	lbl.text = contract_txt + "\nCost: " + _fmt_int_spaces(euros_cost) + " / season"

	if owned:
		lbl.add_theme_color_override("font_color", Color(0.42, 1.0, 0.42, 1))
	else:
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _on_btn_coach_junior() -> void:
	selected_coach_id = "coach_junior"

func _on_btn_coach_confirme() -> void:
	selected_coach_id = "coach_confirme"

func _on_btn_coach_elite() -> void:
	selected_coach_id = "coach_elite"


func _connect_unlock_capsules() -> void:
	if BtnUnlockJunior != null and not BtnUnlockJunior.pressed.is_connected(_on_btn_unlock_junior):
		BtnUnlockJunior.pressed.connect(_on_btn_unlock_junior)
	if BtnUnlockConfirme != null and not BtnUnlockConfirme.pressed.is_connected(_on_btn_unlock_confirme):
		BtnUnlockConfirme.pressed.connect(_on_btn_unlock_confirme)
	if BtnUnlockElite != null and not BtnUnlockElite.pressed.is_connected(_on_btn_unlock_elite):
		BtnUnlockElite.pressed.connect(_on_btn_unlock_elite)


func _setup_buy_button_style() -> void:
	if BtnBuyCoach == null:
		return
	BtnBuyCoach.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	BtnBuyCoach.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	BtnBuyCoach.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.18, 0.42, 0.88, 1)
	sb_normal.corner_radius_top_left = 8
	sb_normal.corner_radius_top_right = 8
	sb_normal.corner_radius_bottom_left = 8
	sb_normal.corner_radius_bottom_right = 8

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.25, 0.50, 0.96, 1)
	sb_hover.corner_radius_top_left = 8
	sb_hover.corner_radius_top_right = 8
	sb_hover.corner_radius_bottom_left = 8
	sb_hover.corner_radius_bottom_right = 8

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(0.12, 0.32, 0.72, 1)
	sb_pressed.corner_radius_top_left = 8
	sb_pressed.corner_radius_top_right = 8
	sb_pressed.corner_radius_bottom_left = 8
	sb_pressed.corner_radius_bottom_right = 8

	BtnBuyCoach.add_theme_stylebox_override("normal", sb_normal)
	BtnBuyCoach.add_theme_stylebox_override("hover", sb_hover)
	BtnBuyCoach.add_theme_stylebox_override("pressed", sb_pressed)


func _coach_confirm_text(coach_id: String) -> String:
	var data: Dictionary = PL.get_coach_price_data(coach_id)
	if data.is_empty():
		return "Coach data unavailable"

	var coach_cfg: Dictionary = COACH_UI_CONFIG.get(coach_id, {
		"contract_text": "Contract: -",
		"payment_text": "Payment: -"
	}) as Dictionary

	var contract_txt: String = str(coach_cfg.get("contract_text", "Contract: -"))
	var euros_cost: int = int(data.get("euros_cost", 0))
	var tokens_cost: int = _get_displayed_tokens_cost(coach_id)

	return contract_txt + "
Cost: " + _fmt_int_spaces(euros_cost) + " / season"


func _open_unlock_confirm(coach_id: String) -> void:
	selected_coach_id = coach_id
	if LblInfo != null:
		LblInfo.text = _coach_confirm_text(coach_id)
	var data: Dictionary = PL.get_coach_price_data(coach_id)
	if LblInfoTokens != null:
		LblInfoTokens.text = str(_get_displayed_tokens_cost(coach_id))
	if BtnBuyCoach != null:
		BtnBuyCoach.text = tr("common.confirm")
	if LblInfoError != null:
		LblInfoError.visible = false
		LblInfoError.text = ""
	if InfoPanel != null:
		InfoPanel.visible = true

	var d = SaveRef.read_dict()
	if LblTokensAvailable != null and not d.is_empty():
		var tokens_now: int = PL.get_tokens(d)
		var tokens_needed: int = _get_displayed_tokens_cost(coach_id)
		LblTokensAvailable.text = "Available: " + str(tokens_now)
		if tokens_now < tokens_needed:
			LblTokensAvailable.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22, 1))
		else:
			LblTokensAvailable.add_theme_color_override("font_color", Color(0.20, 0.82, 0.32, 1))


func _on_btn_unlock_junior() -> void:
	_open_unlock_confirm("coach_junior")


func _on_btn_unlock_confirme() -> void:
	_open_unlock_confirm("coach_confirme")


func _on_btn_unlock_elite() -> void:
	_open_unlock_confirm("coach_elite")


func _on_btn_buy_coach() -> void:
	var cid: String = str(selected_coach_id).strip_edges()
	if cid == "":
		return

	var d: Dictionary = SaveRef.read_dict()
	if d.is_empty():
		return

	var data: Dictionary = PL.get_coach_price_data(cid)
	if data.is_empty():
		return

	var tokens_cost: int = _get_displayed_tokens_cost(cid)
	var tokens_now: int = PL.get_tokens(d)
	if tokens_now < tokens_cost:
		print("[COACHS][BLOCK_BUY] cid=", cid, " tokens_now=", tokens_now, " tokens_cost=", tokens_cost)
		if LblInfoError != null:
			LblInfoError.text = tr("coach.popup.not_enough_tokens")
			LblInfoError.visible = true
		return

	var ok: bool = PL.buy_coach(d, cid, 0, tokens_cost, "coach_unlock_confirm")
	if not ok:
		if LblInfoError != null:
			LblInfoError.text = tr("coach.popup.not_enough_tokens")
			LblInfoError.visible = true
		return

	SaveRef.write_dict(d)
	_refresh_tokens_hud_from_save(d)
	_bm_refresh_active_coach_visuals()

	if InfoPanel != null:
		InfoPanel.visible = false

	_fill_inline_label("coach_junior", LblCoachJunior)
	_fill_inline_label("coach_confirme", LblCoachConfirme)
	_fill_inline_label("coach_elite", LblCoachElite)


func _refresh_tokens_hud_from_save(d: Dictionary) -> void:
	var tokens_ui: int = PL.get_tokens(d)
	var root: Node = get_tree().current_scene
	if root == null:
		root = self

	for n in root.find_children("LblHudTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = "Tokens " + str(tokens_ui)

	for n in root.find_children("LblTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = str(tokens_ui)


func _bm_apply_coach_quotes_i18n() -> void:
	if quote_coach_junior != null:
		quote_coach_junior.text = '[font_size=24][i]"' + tr("coach.quote.junior") + '"[/i][/font_size]'
	if quote_coach_confirme != null:
		quote_coach_confirme.text = '[font_size=24][i]"' + tr("coach.quote.confirme") + '"[/i][/font_size]'
	if quote_coach_elite != null:
		quote_coach_elite.text = '[font_size=24][i]"' + tr("coach.quote.elite") + '"[/i][/font_size]'


func _bm_apply_coach_title_tooltip_i18n() -> void:
	if lbl_title_coachs != null:
		lbl_title_coachs.tooltip_text = tr("coach.title.tooltip")

func _bm_show_title_tooltip() -> void:
	if title_tooltip_panel != null:
		title_tooltip_panel.visible = true

func _bm_hide_title_tooltip() -> void:
	if title_tooltip_panel != null:
		title_tooltip_panel.visible = false

func _bm_setup_title_tooltip() -> void:
	if title_tooltip_label != null:
		title_tooltip_label.text = tr("coach.title.tooltip")
	if title_tooltip_panel != null:
		title_tooltip_panel.visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.14, 0.94)
		sb.border_color = Color(0.45, 0.78, 1.0, 0.95)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		title_tooltip_panel.add_theme_stylebox_override("panel", sb)

	if title_hover != null:
		if not title_hover.mouse_entered.is_connected(_bm_show_title_tooltip):
			title_hover.mouse_entered.connect(_bm_show_title_tooltip)
		if not title_hover.mouse_exited.is_connected(_bm_hide_title_tooltip):
			title_hover.mouse_exited.connect(_bm_hide_title_tooltip)


func _on_btn_close_info_panel() -> void:
	if InfoPanel != null:
		InfoPanel.visible = false

func _bm_get_seasons_left(coach_id: String) -> int:
	var d: Dictionary = SaveRef.read_dict()
	if d.is_empty():
		return 0

	var coachs: Dictionary = d.get("coachs", {}) as Dictionary
	if str(coachs.get("active", "")) != coach_id:
		return 0

	var start: int = int(coachs.get("last_hired_season", 0))
	var current: int = int(d.get("season_number", 1))
	var duration: int = int(COACH_UI_CONFIG.get(coach_id, {}).get("duration_seasons", 1))

	var used: int = current - start + 1
	return max(0, duration - used + 1)

func _bm_set_capsule_state(node: Node, enabled: bool) -> void:
	if node == null:
		return
	node.modulate = Color(1,1,1,1) if enabled else Color(0.5,0.5,0.5,1)
	node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
