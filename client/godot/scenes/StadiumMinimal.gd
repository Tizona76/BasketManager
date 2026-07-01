extends Control


# --- SHOP / BOUTIQUE (TOP-LEVEL CONSTS) --------------------------------------
const SHOP_BG_PATH: String = "res://assets/images/backgrounds/boutique.png"
const UPGRADE_BG_PATH: String = "res://assets/images/stades/stade_11.png"

const SHOP_PRODUCTS: Array = [
	{"id":"ballon",	  "label":"Ballon"},
	{"id":"casquette","label":"Casquette"},
	{"id":"drapeau",  "label":"Drapeau"},
	{"id":"tshirt",	  "label":"T-shirt"},
	{"id":"echarpe",  "label":"Écharpe"},
	{"id":"gourde",	  "label":"Gourde"},
	{"id":"mochila",  "label":"Mochila"},
]

const SHOP_STOCK_BY_LEVEL: Dictionary = {
	1: {"ballon":180, "casquette":220, "drapeau":160, "tshirt":140, "echarpe":0, "gourde":0, "mochila":0},
	2: {"ballon":50, "casquette":40, "drapeau":35, "tshirt":30, "echarpe":15, "gourde":0, "mochila":0},
	3: {"ballon":60, "casquette":50, "drapeau":45, "tshirt":40, "echarpe":25, "gourde":15, "mochila":0},
	4: {"ballon":70, "casquette":60, "drapeau":55, "tshirt":50, "echarpe":35, "gourde":25, "mochila":15},
	5: {"ballon":80, "casquette":70, "drapeau":65, "tshirt":60, "echarpe":45, "gourde":35, "mochila":25},
}

const SHOP_DEFAULT_PRICES: Dictionary = {
	"ballon":12, "casquette":10, "drapeau":8, "tshirt":15, "echarpe":9, "gourde":11, "mochila":18
}

const SHOP_LOCKED_MODULATE := Color(0.65, 0.65, 0.65, 1.0)

# --- SHOP / BOUTIQUE (TOP-LEVEL VARS) ----------------------------------------
# (add-only safety) : requis par _ensure_shop_panel()
var _shop_level_cached: int = 1
var _shop_price_by_id: Dictionary = {}
var _shop_price_le_by_id: Dictionary = {}
var _shop_row_by_id: Dictionary = {}
var _shop_total_label: Label = null

const PlayerLife := preload("res://scripts/PlayerLife.gd")
const StadiumDataRef := preload("res://scripts/StadiumData.gd")
### STADIUM_TICKETING_MINIMAL
const STADIUM_FONT_BOOST_FACTOR: float = 2.3
const STADIUM_CAPACITY_DEFAULT := 5500

var save: Dictionary = {}

# --- Billetterie (équations style .py) ---
const CAT_A := "A"
const CAT_B := "B"
const CAT_C := "C"

const SPLIT_A := 0.20
const SPLIT_B := 0.35
const SPLIT_C := 0.45

const PRICE_MULT_A := 1.6
const PRICE_MULT_B := 1.0
const PRICE_MULT_C := 0.6

func _round_to_10(v: int) -> int:
	return int((v + 5) / 10) * 10

func _compute_ticketing_limits(capacity_total: int) -> Dictionary:
	# { "max": {"A":int,"B":int,"C":int}, "price": {"A":int,"B":int,"C":int} }
	var cap: int = maxi(0, capacity_total)
	if cap <= 0:
		return {}

	# 1) Plafonds de places
	var a: int = _round_to_10(int(float(cap) * SPLIT_A))
	var b: int = _round_to_10(int(float(cap) * SPLIT_B))
	var c: int = cap - a - b  # somme exacte

	if c < 0:
		c = 0

	var sum_abc: int = a + b + c
	if sum_abc > cap:
		var over: int = sum_abc - cap
		var take_b: int = mini(over, b)
		b -= take_b
		over -= take_b
		if over > 0:
			var take_a: int = mini(over, a)
			a -= take_a

	# 2) Prix max progressifs (simple, lisible, non cassant)
	var club_level: int = maxi(1, int(SeasonState.club_level))
	var base_price := 8.5 + float(club_level - 1) * 0.6
	var pa := int(round(base_price * PRICE_MULT_A))
	var pb := int(round(base_price * PRICE_MULT_B))
	var pc := int(round(base_price * PRICE_MULT_C))

	return {
		"max": {CAT_A: a, CAT_B: b, CAT_C: c},
		"price": {CAT_A: pa, CAT_B: pb, CAT_C: pc}
	}

func _stadium_apply_ticketing_limits(capacity_total: int) -> void:
	# Applique max places + prix suggérés sur TES LineEdit existants
	var pack: Dictionary = _compute_ticketing_limits(capacity_total)
	var max_map: Dictionary = pack.get("max", {})
	var price_map: Dictionary = pack.get("price", {})

	var price_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceA") as LineEdit
	var price_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceB") as LineEdit
	var price_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceC") as LineEdit

	var seats_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsA") as LineEdit
	var seats_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsB") as LineEdit
	var seats_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsC") as LineEdit

	# Prix suggérés : uniquement si vide (non destructif)
	if price_a != null and price_a.text.strip_edges() == "":
		price_a.text = str(int(price_map.get(CAT_A, 0)))
	if price_b != null and price_b.text.strip_edges() == "":
		price_b.text = str(int(price_map.get(CAT_B, 0)))
	if price_c != null and price_c.text.strip_edges() == "":
		price_c.text = str(int(price_map.get(CAT_C, 0)))

	# Clamp places selon max catégorie + capacité (réduit C en priorité)
	if seats_a == null or seats_b == null or seats_c == null:
		return

	var cap: int = maxi(0, capacity_total)
	if cap <= 0:
		return
	var a_max: int = int(max_map.get(CAT_A, cap))
	var b_max: int = int(max_map.get(CAT_B, cap))
	var c_max: int = int(max_map.get(CAT_C, cap))

	var a: int = _safe_int(seats_a.text)
	var b: int = _safe_int(seats_b.text)
	var c: int = _safe_int(seats_c.text)

	if a < 0: a = 0
	if b < 0: b = 0
	if c < 0: c = 0

	if a > a_max: a = a_max
	if b > b_max: b = b_max
	if c > c_max: c = c_max

	var c_cap_max: int = maxi(0, cap - a - b)
	if c > c_cap_max:
		c = c_cap_max

	seats_a.text = str(a)
	seats_b.text = str(b)
	seats_c.text = str(c)

const STADIUM_CONTENT_ZOOM: float = 1.18

@onready var BtnRetour: Button = get_node_or_null("BtnRetour") as Button
@onready var LblCapacity: Label = get_node_or_null("LblCapacity") as Label
var LblStadiumLevel: Label = null
@onready var popup_stadium_intro: Panel = get_node_or_null("Overlays/PopupStadiumIntro") as Panel
@onready var btn_close_stadium_intro: Button = get_node_or_null("Overlays/PopupStadiumIntro/BtnCloseStadiumIntro") as Button
@onready var lbl_stadium_intro: RichTextLabel = get_node_or_null("Overlays/PopupStadiumIntro/LblStadiumIntro") as RichTextLabel
@onready var save_node: Node = get_node_or_null("/root/SaveSingleton")
@onready var save_node_check: Node = get_node_or_null("/root/SaveSingleton")





# BM_STADIUM_LIMITS_TOOLTIP_V1
var _bm_limits_tip: Panel = null

func _bm_show_limits_tooltip(text: String) -> void:
	if text.strip_edges() == "":
		return
	if _bm_limits_tip != null and is_instance_valid(_bm_limits_tip):
		_bm_limits_tip.queue_free()

	_bm_limits_tip = Panel.new()
	_bm_limits_tip.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_bm_limits_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bm_limits_tip.custom_minimum_size = Vector2(520, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	sb.border_color = Color(1.0, 0.72, 0.20, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_bm_limits_tip.add_theme_stylebox_override("panel", sb)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_left = 12
	m.offset_top = 10
	m.offset_right = -12
	m.offset_bottom = -10

	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(500, 0)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	m.add_child(lbl)
	_bm_limits_tip.add_child(m)
	add_child(_bm_limits_tip)

	var mp := get_viewport().get_mouse_position()
	var vp := get_viewport_rect().size

	# Position par défaut (à gauche)
	var pos := mp + Vector2(-520, 18)

	# Clamp horizontal (évite sortie écran gauche)
	if pos.x < 10:
		pos.x = mp.x + 20

	# Clamp droite (sécurité)
	if pos.x + 520 > vp.x:
		pos.x = vp.x - 530

	# Clamp vertical (optionnel safe)
	if pos.y + 120 > vp.y:
		pos.y = vp.y - 130

	_bm_limits_tip.global_position = pos
	_bm_limits_tip.visible = true

func _bm_hide_limits_tooltip() -> void:
	if _bm_limits_tip != null and is_instance_valid(_bm_limits_tip):
		_bm_limits_tip.queue_free()
	_bm_limits_tip = null

# BM_SHOP_HEADER_TOOLTIPS_SIMPLE_V1
func _on_shop_price_hover_entered() -> void:
	var t := _stadium_tr("stadium.shop.tooltip.price_limit")
	if t == "" or t == "stadium.shop.tooltip.price_limit":
		t = "Max price depends on your stadium level. Upgrade stadium to increase it."
	_bm_show_limits_tooltip(t)

func _on_shop_stock_hover_entered() -> void:
	var t := _stadium_tr("stadium.shop.tooltip.stock_limit")
	if t == "" or t == "stadium.shop.tooltip.stock_limit":
		t = "Available stock depends on your stadium level. Upgrade stadium to increase it."
	_bm_show_limits_tooltip(t)


func _bm_add_limits_help_button(parent: Control, text: String) -> void:
	if parent == null or parent.get_node_or_null("BtnLimitsHelp") != null:
		return
	var b := Button.new()
	b.name = "BtnLimitsHelp"
	b.text = "?"
	b.custom_minimum_size = Vector2(42, 42)
	b.add_theme_font_size_override("font_size", 26)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_entered.connect(func(): _bm_show_limits_tooltip(text))
	b.mouse_exited.connect(_bm_hide_limits_tooltip)
	b.pressed.connect(func():
		if _bm_limits_tip == null:
			_bm_show_limits_tooltip(text)
		else:
			_bm_hide_limits_tooltip()
	)
	parent.add_child(b)

func _stadium_apply_i18n_action_buttons() -> void:
	var _map := {
		"stadium_btn_ticketing": [
			"UI/BtnBilletterie", "UI/BtnTicketing", "BtnBilletterie", "BtnTicketing"
		],
		"stadium_btn_shop": [
			"UI/BtnBoutique", "UI/BtnShop", "BtnBoutique", "BtnShop"
		],
		"stadium_btn_upgrade": [
			"UI/BtnEvolutionStade", "UI/BtnUpgrade", "BtnEvolutionStade", "BtnUpgrade"
		]
	}
	for _key in _map.keys():
		for _path in _map[_key]:
			var _n := get_node_or_null(_path)
			if _n != null and _n is Button:
				(_n as Button).text = tr(_key)
				break

func _ready() -> void:
	var d_unlock_enter: Dictionary = PlayerLife.load_savegame()
	if typeof(d_unlock_enter) == TYPE_DICTIONARY and not bool(d_unlock_enter.get("early_flow_stadium_unlocked", false)):
		d_unlock_enter["early_flow_stadium_unlocked"] = true
		PlayerLife.write_savegame(d_unlock_enter)
		print("[STADIUM][EARLY_FLOW] Stadium unlocked for Menu (on enter)")
	_stadium_apply_i18n_action_buttons()
	call_deferred("_bm_stadium_mobile_entry_buttons_plus20_textplus2")
	print("[STADIUM] ready")
	call_deferred("_bm_refresh_price_adjust_mission_counter")
	save = PlayerLife.load_savegame()

	if popup_stadium_intro != null:
		var popup_data = PlayerLife.load_savegame()
		if not popup_data.has("stadium_intro_seen") or popup_data["stadium_intro_seen"] == false:
			popup_stadium_intro.visible = true
			popup_stadium_intro.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			popup_stadium_intro.visible = false
		popup_stadium_intro.set_as_top_level(true)
		popup_stadium_intro.z_index = 9999
		var _sb_intro_bg := StyleBoxFlat.new()
		_sb_intro_bg.bg_color = Color(0.055, 0.065, 0.095, 0.90)
		_sb_intro_bg.corner_radius_top_left = 18
		_sb_intro_bg.corner_radius_top_right = 18
		_sb_intro_bg.corner_radius_bottom_left = 18
		_sb_intro_bg.corner_radius_bottom_right = 18
		_sb_intro_bg.border_width_left = 2
		_sb_intro_bg.border_width_top = 2
		_sb_intro_bg.border_width_right = 2
		_sb_intro_bg.border_width_bottom = 2
		_sb_intro_bg.border_color = Color(0.85, 0.75, 0.25, 0.24)
		popup_stadium_intro.add_theme_stylebox_override("panel", _sb_intro_bg)
		if _bm_stadium_is_mobile_layout():
			popup_stadium_intro.size = popup_stadium_intro.size * 1.15
			popup_stadium_intro.position = (get_viewport_rect().size - popup_stadium_intro.size) * 0.5
		else:
			popup_stadium_intro.size = Vector2(popup_stadium_intro.size.x, popup_stadium_intro.size.y + 70.0)
			popup_stadium_intro.position = (get_viewport_rect().size - popup_stadium_intro.size) * 0.5

	if lbl_stadium_intro != null:
		lbl_stadium_intro.bbcode_enabled = true
		var _title := tr("stadium_intro_title")
		if _title == "" or _title == "stadium_intro_title":
			_title = "Stadium"

		var _capacity := tr("stadium_intro_capacity")
		if _capacity == "" or _capacity == "stadium_intro_capacity":
			_capacity = ">> Manage your stadium and increase its capacity"

		var _shop := tr("stadium_intro_shop")
		if _shop == "" or _shop == "stadium_intro_shop":
			_shop = ">> Shop: set your prices to generate revenue"

		var _ticketing := tr("stadium_intro_ticketing")
		if _ticketing == "" or _ticketing == "stadium_intro_ticketing":
			_ticketing = ">> Ticketing: adjust prices and seat numbers to optimize your earnings"

		if _bm_stadium_is_mobile_layout():
			lbl_stadium_intro.text = "[center][font_size=28][b]" + _title + "[/b][/font_size][/center]\n\n" + "[font_size=28]" + _capacity + "\n\n" + _shop + "\n\n" + _ticketing + "[/font_size]"
		else:
			lbl_stadium_intro.text = "[center][font_size=24][b]" + _title + "[/b][/font_size][/center]\n\n" + "[font_size=24]" + _capacity + "\n\n" + _shop + "\n\n" + _ticketing + "[/font_size]"

	if btn_close_stadium_intro != null:
		btn_close_stadium_intro.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_close_stadium_intro.disabled = false
		btn_close_stadium_intro.visible = true
		btn_close_stadium_intro.text = tr("popup_intro_close")
		if _bm_stadium_is_mobile_layout():
			btn_close_stadium_intro.add_theme_font_size_override("font_size", btn_close_stadium_intro.get_theme_font_size("font_size") + 4)
		var _sb_close := StyleBoxFlat.new()
		_sb_close.bg_color = Color(0.20, 0.55, 0.95, 1.0)
		_sb_close.corner_radius_top_left = 12
		_sb_close.corner_radius_top_right = 12
		_sb_close.corner_radius_bottom_left = 12
		_sb_close.corner_radius_bottom_right = 12
		_sb_close.content_margin_left = 16
		_sb_close.content_margin_right = 16
		_sb_close.content_margin_top = 8
		_sb_close.content_margin_bottom = 8
		btn_close_stadium_intro.add_theme_stylebox_override("normal", _sb_close)

		var _sb_close_hover := _sb_close.duplicate()
		_sb_close_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
		btn_close_stadium_intro.add_theme_stylebox_override("hover", _sb_close_hover)

		btn_close_stadium_intro.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if btn_close_stadium_intro.pressed.is_connected(_on_close_stadium_intro_pressed):
			btn_close_stadium_intro.pressed.disconnect(_on_close_stadium_intro_pressed)
		btn_close_stadium_intro.pressed.connect(_on_close_stadium_intro_pressed)

	call_deferred("_ensure_ticketing_confirm_button")
	call_deferred("_stadium_apply_i18n")

	if BtnRetour == null:
		BtnRetour = find_child("BtnRetour", true, false) as Button

	if BtnRetour != null:
		BtnRetour.disabled = false
		BtnRetour.visible = true
		BtnRetour.mouse_filter = Control.MOUSE_FILTER_STOP
		var _gp_back := BtnRetour.global_position
		BtnRetour.set_as_top_level(true)
		BtnRetour.global_position = _gp_back
		BtnRetour.z_index = 100
		var cb := Callable(self, "_on_btn_retour_pressed")
		if not BtnRetour.pressed.is_connected(cb):
			BtnRetour.pressed.connect(cb)

	# --- StadiumMinimal init (safe) ---
	_stadium_apply_i18n()
	_stadium_bind_tabs()
	_stadium_refresh_tabs_visibility()
	_stadium_bind_ticketing_inputs()
	call_deferred("_stadium_fix_ticketing_mouse")
	call_deferred("_load_ticketing_from_save")
	_ensure_ticket_cat_a_icon()
	_ensure_ticket_cat_b_icon()
	_ensure_ticket_cat_c_icon()
	_stadium_boost_ticketing_fonts()
	_ensure_ticketing_close_button()
	call_deferred("_ensure_capacity_label")
	call_deferred("_stadium_hide_title_and_fix_popularity")
	call_deferred("_stadium_fix_popularity_badges_visual")

func _bm_has_confirmed_stadium_setup() -> bool:
	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var has_ticketing := false
	if d.has("stadium") and typeof(d["stadium"]) == TYPE_DICTIONARY:
		var st: Dictionary = d["stadium"] as Dictionary
		if st.has("ticketing") and typeof(st["ticketing"]) == TYPE_DICTIONARY:
			var tt: Dictionary = st["ticketing"] as Dictionary
			has_ticketing = int(tt.get("price_a", 0)) > 0 and int(tt.get("price_b", 0)) > 0 and int(tt.get("price_c", 0)) > 0
	var has_shop := false
	if d.has("shop") and typeof(d["shop"]) == TYPE_DICTIONARY:
		var shop: Dictionary = d["shop"] as Dictionary
		var items_any: Variant = shop.get("items", {})
		if typeof(items_any) == TYPE_DICTIONARY:
			var items: Dictionary = items_any as Dictionary
			for pid in items.keys():
				var row_any: Variant = items[pid]
				if typeof(row_any) == TYPE_DICTIONARY and int((row_any as Dictionary).get("price", 0)) > 0:
					has_shop = true
					break
	return has_ticketing and has_shop


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


func _bm_stadium_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _bm_apply_back_button_style(btn: Button) -> void:
	if btn == null:
		return

	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	btn.add_theme_font_size_override("font_size", 24 if _bm_stadium_is_mobile_layout() else 22)

func _bm_stadium_mobile_entry_buttons_plus20_textplus2() -> void:
	if not _bm_stadium_is_mobile_layout():
		return
	for path in ["Tabs/BtnTabShop", "Tabs/BtnTabTicketing", "Tabs/BtnTabUpgrade", "UI/BtnBoutique", "UI/BtnShop", "BtnBoutique", "BtnShop", "UI/BtnBilletterie", "UI/BtnTicketing", "BtnBilletterie", "BtnTicketing", "UI/BtnEvolutionStade", "UI/BtnUpgrade", "BtnEvolutionStade", "BtnUpgrade"]:
		var btn := get_node_or_null(path) as Button
		if btn == null:
			continue
		if not btn.has_meta("bm_mobile_stadium_entry_plus20_done"):
			btn.set_meta("bm_mobile_stadium_entry_plus20_done", true)
			var base := btn.custom_minimum_size
			if base.x <= 1.0 or base.y <= 1.0:
				base = btn.size
			btn.custom_minimum_size = base * 1.30
		btn.add_theme_font_size_override("font_size", 30)

func _on_btn_retour_pressed() -> void:
	if _bm_has_confirmed_stadium_setup():
		var d_unlock: Dictionary = PlayerLife.load_savegame()
		if typeof(d_unlock) == TYPE_DICTIONARY:
			d_unlock["early_flow_stadium_unlocked"] = true
			PlayerLife.write_savegame(d_unlock)
			print("[STADIUM][EARLY_FLOW] Stadium unlocked for Menu")
	# Retour vers écran Management (fallbacks) — même schéma que MenuSaison.gd
	var candidates := [
		"res://scenes/Management.tscn",
		"res://scenes/Gestion.tscn",
		"res://scenes/MenuGestion.tscn",
		"res://scenes/Menu.tscn",
		"res://scenes/Main.tscn",
	]
	for pth in candidates:
		if ResourceLoader.exists(pth):
			get_tree().change_scene_to_file(pth)
			return
	push_warning("[StadiumMinimal] Aucun écran Management trouvé (candidates).")

func _shop_apply_confirm_style(btn: Button) -> void:
	if btn == null:
		return
	btn.modulate = Color(1, 1, 1, 1)
	btn.add_theme_color_override("font_color", Color(1,1,1,1))
	btn.add_theme_color_override("font_hover_color", Color(1,1,1,1))
	btn.add_theme_color_override("font_pressed_color", Color(1,1,1,1))
	btn.add_theme_font_size_override("font_size", 22)

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.70, 0.25, 1.0)
	sb_n.corner_radius_top_left = 10
	sb_n.corner_radius_top_right = 10
	sb_n.corner_radius_bottom_left = 10
	sb_n.corner_radius_bottom_right = 10
	sb_n.content_margin_left = 18
	sb_n.content_margin_right = 18
	sb_n.content_margin_top = 10
	sb_n.content_margin_bottom = 10
	sb_n.border_width_left = 2
	sb_n.border_width_right = 2
	sb_n.border_width_top = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(0.08, 0.55, 0.18, 1.0)
	sb_n.shadow_size = 6
	sb_n.shadow_offset = Vector2(0, 4)
	sb_n.shadow_color = Color(0, 0, 0, 0.35)

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.16, 0.80, 0.30, 1.0)

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.10, 0.60, 0.20, 1.0)
	sb_p.shadow_size = 2
	sb_p.shadow_offset = Vector2(0, 1)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)

	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = false
	btn.visible = true


func _shop_place_confirm_button() -> void:
	var btn := find_child("BtnConfirmShop", true, false) as Button
	if btn == null:
		return

	_shop_apply_confirm_style(btn)

	if BtnRetour != null:
		if BtnRetour.custom_minimum_size.x > 0 and BtnRetour.custom_minimum_size.y > 0:
			btn.custom_minimum_size = BtnRetour.custom_minimum_size
		else:
			btn.custom_minimum_size = BtnRetour.size

	var gp := btn.global_position
	btn.set_as_top_level(true)
	btn.global_position = gp
	btn.z_index = 100
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var vpw := get_viewport_rect().size.x
	var bw := btn.size.x
	if bw <= 1.0:
		bw = max(btn.custom_minimum_size.x, 220.0)

	if BtnRetour != null:
		var margin := BtnRetour.global_position.x
		btn.global_position = Vector2(vpw - margin - bw, BtnRetour.global_position.y)
	else:
		btn.global_position = Vector2(vpw - bw - 20.0, 20.0)

func _shop_force_light_text(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Label:
			var lbl := child as Label
			if lbl.name == "LblLastSales":
				var stock_lbl := lbl.get_parent().get_node_or_null("LblStock") as Label
				var last_sales := _safe_int(lbl.text)
				var stock := _safe_int(stock_lbl.text if stock_lbl != null else "0")
				var sales_color := Color(0.18, 0.95, 0.28, 1) if last_sales < stock else Color(1, 0.18, 0.18, 1)
				lbl.modulate = sales_color
				lbl.add_theme_color_override("font_color", sales_color)
			else:
				lbl.modulate = Color(1, 1, 1, 1)
				lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		_shop_force_light_text(child)


func _stadium_tr(key: String) -> String:
	# Finance-style: tr(key) puis fallback local si la clé n’est pas traduite (tr renvoie la clé)
	var v: String = tr(key)
	if v != "" and v != key:
		return v

	var loc: String = TranslationServer.get_locale()
	var lang: String = loc.split("_")[0] if loc.find("_") != -1 else loc

	var fb: Dictionary = {
		"btn.back": {"fr":"Retour","en":"Back","es":"Volver","it":"Indietro","pt":"Voltar"},

		"stadium.title": {"fr":"Stadium","en":"Stadium","es":"Estadio","it":"Stadio","pt":"Estádio"},
		"stadium.tab.shop": {"fr":"Boutique","en":"Shop","es":"Tienda","it":"Negozio","pt":"Loja"},
		"stadium.tab.ticketing": {"fr":"Billetterie","en":"Ticketing","es":"Billetterie","it":"Biglietteria","pt":"Bilheteria"},
		"stadium.tab.cafe": {"fr":"Cafétéria","en":"Cafeteria","es":"Cafetería","it":"Caffetteria","pt":"Cafetaria"},
				"stadium.upgrade.works_in_progress_title": {"fr":"Travaux en cours","en":"Works in progress","es":"Obras en curso","it":"Lavori in corso","pt":"Obras em andamento"},
		"stadium.upgrade.remaining_matches": {"fr":"{remaining} match(s) restant(s)","en":"{remaining} match(es) remaining","es":"{remaining} partido(s) restante(s)","it":"{remaining} partita/e rimanente/i","pt":"{remaining} partida(s) restante(s)"},
		"stadium.upgrade.acceleration_available": {"fr":"Accélération possible après lancement : {tokens} tokens","en":"Acceleration available after launch: {tokens} tokens"},
		"stadium.upgrade.accel_confirm": {"fr":"Travaux vers le niveau {level}\nCoût d'accélération : {tokens} tokens\nTemps restant actuel : {remaining} match(s)\nTemps restant après accélération : {after} match(s)\nTokens disponibles : {available}","en":"Works toward level {level}\nAcceleration cost: {tokens} tokens\nCurrent remaining time: {remaining} match(es)\nRemaining time after acceleration: {after} match(es)\nAvailable tokens: {available}","es":"Obras hacia el nivel {level}\nCoste de aceleración: {tokens} tokens\nTiempo restante actual: {remaining} partido(s)\nTiempo restante tras la aceleración: {after} partido(s)\nTokens disponibles: {available}","it":"Lavori verso il livello {level}\nCosto accelerazione: {tokens} token\nTempo rimanente attuale: {remaining} partita/e\nTempo rimanente dopo accelerazione: {after} partita/e\nToken disponibili: {available}","pt":"Obras para o nível {level}\nCusto da aceleração: {tokens} tokens\nTempo restante atual: {remaining} partida(s)\nTempo restante após aceleração: {after} partida(s)\nTokens disponíveis: {available}"},
"stadium.tab.upgrade": {"fr":"Évolution Stade","en":"Stadium Upgrade","es":"Mejora del estadio","it":"Evoluzione stadio","pt":"Evolução do estádio"},

		"stadium.ticketing.title": {"fr":"Billetterie","en":"Ticketing","es":"Entradas","it":"Biglietteria","pt":"Bilhetes"},
		"stadium.ticketing.total": {"fr":"Total","en":"Total","es":"Total","it":"Totale","pt":"Total"},

					"stadium.ticketing.col.category": {"fr":"Catégorie","en":"Category","es":"Categoría","it":"Categoria","pt":"Categoria"},
					"stadium.ticketing.col.price": {"fr":"Prix","en":"Price","es":"Precio","it":"Prezzo","pt":"Preço"},
			"stadium.ticketing.col.seats": {"fr":"Places","en":"Seats","es":"Asientos","it":"Posti","pt":"Lugares"},
			"stadium.duration_unit": {"fr":"match(s)","en":"games","es":"partidos","it":"partite","pt":"jogos"},
			"stadium.ticketing.tooltip.category": {"fr":"Chaque catégorie a un nombre de places et de prix réservés.","en":"Each category has a reserved number of seats and prices.","es":"Cada categoría tiene un número reservado de asientos y precios.","it":"Ogni categoria ha un numero riservato di posti e prezzi.","pt":"Cada categoria tem um número reservado de lugares e preços."},
					"stadium.ticketing.tooltip.price": {"fr":"Le prix est défini par catégorie et limité par le niveau du stade.","en":"Price is set by category and limited by stadium level.","es":"El precio se define por categoría y está limitado por el nivel del estadio.","it":"Il prezzo è impostato per categoria ed è limitato dal livello dello stadio.","pt":"O preço é definido por categoria e limitado pelo nível do estádio."},
					"stadium.ticketing.tooltip.seats": {"fr":"Le nombre de places maximum dépend de la capacité du stade. Améliore le stade pour l'augmenter.","en":"Max seats depend on your stadium capacity. Upgrade stadium to increase it.","es":"Los asientos máximos dependen de la capacidad del estadio. Mejora el estadio para aumentarlos.","it":"I posti massimi dipendono dalla capacità dello stadio. Migliora lo stadio per aumentarli.","pt":"O número máximo de lugares depende da capacidade do estádio. Melhora o estádio para aumentá-lo."},
					"stadium.shop.col.price": {"fr":"Prix","en":"Price","es":"Precio","it":"Prezzo","pt":"Preço"},
					"stadium.shop.col.last_sales": {"fr":"Ventes dernier match","en":"Last game sales","es":"Ventas último partido","it":"Vendite ultima partita","pt":"Vendas último jogo"},
					"stadium.shop.col.estimated_revenue": {"fr":"Recettes estimées","en":"Estimated revenue","es":"Ingresos estimados","it":"Ricavi stimati","pt":"Receitas estimadas"},
					"stadium.shop.col.restock": {"fr":"Réassortiment","en":"Restock","es":"Reposición","it":"Riassortimento","pt":"Reposição"},
			"stadium.shop.tooltip.price_limit": {"fr":"Le prix maximum dépend du niveau du stade. Améliore le stade pour l’augmenter.","en":"Max price depends on your stadium level. Upgrade stadium to increase it.","es":"El precio máximo depende del nivel del estadio. Mejora el estadio para aumentarlo.","it":"Il prezzo massimo dipende dal livello dello stadio. Migliora lo stadio per aumentarlo.","pt":"O preço máximo depende do nível du stade. Melhore o estádio para aumentá-lo."},
			"stadium.shop.tooltip.stock_limit": {"fr":"Le stock disponible dépend du niveau du stade. Améliore le stade pour l’augmenter.","en":"Available stock depends on your stadium level. Upgrade stadium to increase it.","es":"El stock disponible depende del nivel del estadio. Mejora el estadio para aumentarlo.","it":"Lo stock disponibile dipende dal livello dello stadio. Migliora lo stadio per aumentarlo.","pt":"O stock disponível depende do nível do estádio. Melhore o estádio para aumentá-lo."},
			"stadium.shop.total_estimate": {"fr":"Estimation totale","en":"Total estimate","es":"Estimación total","it":"Stima totale","pt":"Estimativa total"},

			"stadium.ticketing.cat.a": {"fr":"Cat. A","en":"Cat. A","es":"Cat. A","it":"Cat. A","pt":"Cat. A"},
			"stadium.ticketing.cat.b": {"fr":"Cat. B","en":"Cat. B","es":"Cat. B","it":"Cat. B","pt":"Cat. B"},
		"stadium.ticketing.cat.c": {"fr":"Cat. C","en":"Cat. C","es":"Cat. C","it":"Cat. C","pt":"Cat. C"},
	}

	if fb.has(key):
		var by_lang: Dictionary = fb[key]
		if by_lang.has(lang):
			return str(by_lang[lang])
		if by_lang.has("en"):
			return str(by_lang["en"])
		if by_lang.has("fr"):
			return str(by_lang["fr"])

	return key



func _stadium_fmt(key: String, vars: Dictionary = {}) -> String:
	var s: String = _stadium_tr(key)
	for k in vars.keys():
		s = s.replace("{" + str(k) + "}", str(vars[k]))
	return s


func _stadium_apply_texts_auto(root: Node) -> void:
	# Remplace automatiquement les textes qui ressemblent à des clés i18n
	# (ex: "stadium.ticketing.cat.a", "btn.back", etc.)
	if root == null:
		return
	for c in root.get_children():
		if c is Label:
			var lb: Label = c as Label
			if lb.text.find(".") != -1:
				var k: String = lb.text.strip_edges()
				if k.begins_with("stadium.") or k.begins_with("btn.") or k.begins_with("finance."):
					lb.text = _stadium_tr(k)
		elif c is Button:
			var bt: Button = c as Button
			if bt.text.find(".") != -1:
				var k2: String = bt.text.strip_edges()
				if k2.begins_with("stadium.") or k2.begins_with("btn.") or k2.begins_with("finance."):
					bt.text = _stadium_tr(k2)
		_stadium_apply_texts_auto(c)


func _stadium_set_active_panel(pnl: Control) -> void:
	# Remet tout à taille normale, puis zoom le panel actif
	if PanelTicketing != null:
		PanelTicketing.scale = Vector2(1, 1)

	if pnl != null:
		var z: float = STADIUM_CONTENT_ZOOM

		# ✅ Boutique : +25% réel (visible), sans toucher aux autres écrans/panels
		# (PanelShop est créé dynamiquement sous Content/CenterShop/PanelShop)
		if pnl.name == "PanelShop" or pnl.get_node_or_null("ShopBG") != null:
			z *= 1.25

		pnl.scale = Vector2(z, z)
		# pivot au centre pour éviter un zoom "qui tire" à gauche
		pnl.pivot_offset = pnl.size * 0.5

func _stadium_make_panel_full_screen(panel: Control) -> void:
	if panel == null:
		return
	var vp_size := get_viewport_rect().size
	panel.set_as_top_level(true)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.global_position = Vector2.ZERO
	panel.offset_left = 0
	panel.offset_top = 40
	panel.offset_right = 0
	panel.offset_bottom = 40
	panel.custom_minimum_size = vp_size
	panel.size = vp_size
	panel.scale = Vector2(1, 1)
	panel.pivot_offset = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 3

@onready var BtnTabShop: Button = $Tabs/BtnTabShop
@onready var BtnTabTicketing: Button = $Tabs/BtnTabTicketing
@onready var BtnTabCafe: Button = $Tabs/BtnTabCafe
@onready var BtnTabUpgrade: Button = $Tabs/BtnTabUpgrade

@onready var PanelTicketing: Control = get_node_or_null("Content/CenterTicketing/PanelTicketing") as Control
@onready var LblTicketingTitle: Label = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/LblTicketingTitle") as Label
@onready var LblTicketingTotal: Label = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/LblTicketingTotal") as Label
@onready var PriceA: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceA") as LineEdit
@onready var PriceB: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceB") as LineEdit
@onready var PriceC: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceC") as LineEdit
@onready var SeatsA: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsA") as LineEdit
@onready var SeatsB: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsB") as LineEdit
@onready var SeatsC: LineEdit = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsC") as LineEdit
var BtnCloseTicketing: Button = null
var TicketingScreenBG: TextureRect = null
const TICKETING_BG_PATH: String = "res://assets/images/backgrounds/billetterie.png"
var _ticketing_inputs_bound: bool = false
var BtnCloseShop: Button = null

var _upgrade_confirm_dialog: ConfirmationDialog = null
var _upgrade_info_dialog: AcceptDialog = null
var _upgrade_target_ng: int = 0
var _upgrade_target_ns: int = 0
var _upgrade_accel_mode: bool = false
const UPGRADE_PANEL_ALPHA: float = 0.42
const UPGRADE_PANEL_RADIUS: int = 18
const UPGRADE_NEXT_IMAGE_SIZE: Vector2 = Vector2(640, 300)

func _apply_upgrade_readability_panel_style(frame: PanelContainer) -> void:
	if frame == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, UPGRADE_PANEL_ALPHA)
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = UPGRADE_PANEL_RADIUS
	sb.corner_radius_top_right = UPGRADE_PANEL_RADIUS
	sb.corner_radius_bottom_left = UPGRADE_PANEL_RADIUS
	sb.corner_radius_bottom_right = UPGRADE_PANEL_RADIUS
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	frame.add_theme_stylebox_override("panel", sb)

func _stadium_image_path_for_level(ng: int, ns: int) -> String:
	if ng == 1 and ns == 0:
		return "res://assets/images/stades/stade_11.png"
	if ng == 1 and ns == 1:
		return "res://assets/images/stades/stade_115.png"
	return "res://assets/images/stades/stade_" + str(ng) + str(ns) + ".png"

func _stadium_current_image_path() -> String:
	if save_node != null and save_node.has_method("stadium_level_str"):
		var parts := str(save_node.call("stadium_level_str")).split(".")
		if parts.size() >= 2:
			return _stadium_image_path_for_level(int(parts[0]), int(parts[1]))
	return UPGRADE_BG_PATH

func _apply_upgrade_confirm_button_style(btn: Button) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 26)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.12, 0.70, 0.25, 1.0)
	sb_n.corner_radius_top_left = 10
	sb_n.corner_radius_top_right = 10
	sb_n.corner_radius_bottom_left = 10
	sb_n.corner_radius_bottom_right = 10
	sb_n.content_margin_left = 18
	sb_n.content_margin_right = 18
	sb_n.content_margin_top = 10
	sb_n.content_margin_bottom = 10
	sb_n.border_width_left = 2
	sb_n.border_width_right = 2
	sb_n.border_width_top = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(0.08, 0.55, 0.18, 1.0)
	sb_n.shadow_size = 6
	sb_n.shadow_offset = Vector2(0, 4)
	sb_n.shadow_color = Color(0, 0, 0, 0.35)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.16, 0.80, 0.30, 1.0)
	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.10, 0.60, 0.20, 1.0)
	sb_p.shadow_size = 2
	sb_p.shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_color_override("font_hover_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_color_override("font_pressed_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_constant_override("outline_size", 2)

func _apply_upgrade_cancel_button_style(btn: Button) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(0, 54)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 26)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.82, 0.18, 0.18, 0.96)
	sb_n.corner_radius_top_left = 10
	sb_n.corner_radius_top_right = 10
	sb_n.corner_radius_bottom_left = 10
	sb_n.corner_radius_bottom_right = 10
	sb_n.content_margin_left = 18
	sb_n.content_margin_right = 18
	sb_n.content_margin_top = 10
	sb_n.content_margin_bottom = 10
	sb_n.border_width_left = 2
	sb_n.border_width_right = 2
	sb_n.border_width_top = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(0.55, 0.08, 0.08, 1.0)
	sb_n.shadow_size = 6
	sb_n.shadow_offset = Vector2(0, 4)
	sb_n.shadow_color = Color(0, 0, 0, 0.35)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.90, 0.24, 0.24, 1.0)
	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.68, 0.12, 0.12, 1.0)
	sb_p.shadow_size = 2
	sb_p.shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_color_override("font_hover_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_color_override("font_pressed_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_constant_override("outline_size", 2)

func _get_upgrade_confirm_button(panel: Node) -> Button:
	if panel == null:
		return null
	return panel.find_child("BtnConfirmUpgradePanel", true, false) as Button

func _get_upgrade_cancel_button(panel: Node) -> Button:
	if panel == null:
		return null
	return panel.find_child("BtnCancelUpgradePanel", true, false) as Button

func _format_int(n: int) -> String:
	# 1250000 -> "1 250 000"
	var t: String = str(n)
	var out: String = ""
	var cnt: int = 0
	for i: int in range(t.length() - 1, -1, -1):
		out = t[i] + out
		cnt += 1
		if cnt % 3 == 0 and i != 0:
			out = " " + out
	return out

func _format_capacity(n: int) -> String:
	# "5500" -> "5 500"
	return _format_int(n)

func _ensure_ticketing_screen_bg() -> void:
	if TicketingScreenBG != null and is_instance_valid(TicketingScreenBG):
		return

	TicketingScreenBG = TextureRect.new()
	TicketingScreenBG.name = "TicketingScreenBG"
	TicketingScreenBG.set_anchors_preset(Control.PRESET_FULL_RECT)
	TicketingScreenBG.offset_left = 0
	TicketingScreenBG.offset_top = 0
	TicketingScreenBG.offset_right = 0
	TicketingScreenBG.offset_bottom = 0
	TicketingScreenBG.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	TicketingScreenBG.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	TicketingScreenBG.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TicketingScreenBG.visible = false
	TicketingScreenBG.z_index = 5

	if ResourceLoader.exists(TICKETING_BG_PATH):
		TicketingScreenBG.texture = load(TICKETING_BG_PATH) as Texture2D

	add_child(TicketingScreenBG)
	# keep normal child order; z_index handles layering


func _ensure_ticketing_close_button() -> void:
	if PanelTicketing == null:
		return

	# Déjà créé
	if BtnCloseTicketing != null:
		_ticketing_place_close_button()
		return

	var b: Button = Button.new()
	b.name = "BtnCloseTicketing"
	b.text = "✕"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.z_index = (RenderingServer.CANVAS_ITEM_Z_MAX - 1)
	b.set_as_top_level(true) # ✅ hors layout des Containers
	b.custom_minimum_size = Vector2(48, 48)
	b.add_theme_font_size_override("font_size", 30)

	add_child(b) # ✅ overlay sur Stadium (pas dans PanelContainer)
	BtnCloseTicketing = b

	var cb := Callable(self, "_on_ticketing_close_pressed")
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

	# Reposition au resize du panel (si signal dispo)
	if not PanelTicketing.resized.is_connected(Callable(self, "_ticketing_place_close_button")):
		PanelTicketing.resized.connect(Callable(self, "_ticketing_place_close_button"))

	_ticketing_place_close_button()

func _ticketing_place_close_button() -> void:
	if BtnCloseTicketing == null or PanelTicketing == null:
		return
	if not PanelTicketing.visible:
		BtnCloseTicketing.visible = false
		return

	BtnCloseTicketing.visible = true

	# Coin haut-droite du fond obscur (PanelTicketing) en global
	# marge interne: 16px droite, 12px haut
	var gp: Vector2 = PanelTicketing.global_position
	var sz: Vector2 = PanelTicketing.size
	var btn_sz: Vector2 = BtnCloseTicketing.size
	if btn_sz.x <= 0.0: btn_sz.x = 48.0
	if btn_sz.y <= 0.0: btn_sz.y = 48.0

	BtnCloseTicketing.global_position = gp + Vector2(sz.x - btn_sz.x - 16.0, 16.0)



func _on_ticketing_close_pressed() -> void:
	if TicketingScreenBG != null:
		TicketingScreenBG.visible = false

	if PanelTicketing != null:
		PanelTicketing.visible = false
		if BtnCloseTicketing != null:
			BtnCloseTicketing.visible = false
		var btn_back_ticketing := find_child("BtnBackTicketing", true, false) as Button
		if btn_back_ticketing != null:
			btn_back_ticketing.visible = false
			btn_back_ticketing.disabled = true
			btn_back_ticketing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# remet l’échelle (tu zoomes le panel actif)
		PanelTicketing.scale = Vector2(1, 1)
		PanelTicketing.set_as_top_level(false)
	if BtnRetour != null:
		var cb_ticketing := Callable(self, "_on_ticketing_close_pressed")
		if BtnRetour.pressed.is_connected(cb_ticketing):
			BtnRetour.pressed.disconnect(cb_ticketing)
		var cb_back := Callable(self, "_on_btn_retour_pressed")
		if not BtnRetour.pressed.is_connected(cb_back):
			BtnRetour.pressed.connect(cb_back)
# --- SHOP close (X) ----------------------------------------------------------
func _ensure_shop_close_button() -> void:
	var panel := get_node_or_null("Content/CenterShop/PanelShop") as Control
	if panel == null:
		return

	if BtnCloseShop != null:
		_shop_place_close_button()
		return

	var b: Button = Button.new()
	b.name = "BtnCloseShop"
	b.text = "X" if _bm_stadium_is_mobile_layout() else "✕"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.z_index = (RenderingServer.CANVAS_ITEM_Z_MAX - 1)
	b.set_as_top_level(true)
	b.custom_minimum_size = Vector2(48, 48)
	b.add_theme_font_size_override("font_size", 30)

	add_child(b)
	BtnCloseShop = b

	var cb := Callable(self, "_on_shop_close_pressed")
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

	if not panel.resized.is_connected(Callable(self, "_shop_place_close_button")):
		panel.resized.connect(Callable(self, "_shop_place_close_button"))

	_shop_place_close_button()

func _shop_place_close_button() -> void:
	if BtnCloseShop == null:
		return
	var panel := get_node_or_null("Content/CenterShop/PanelShop") as Control
	if panel == null or not panel.visible:
		BtnCloseShop.visible = false
		return

	BtnCloseShop.visible = false
	return

	var gp: Vector2 = panel.global_position
	var sz: Vector2 = panel.size
	var btn_sz: Vector2 = BtnCloseShop.size
	if btn_sz.x <= 0.0: btn_sz.x = 48.0
	if btn_sz.y <= 0.0: btn_sz.y = 48.0

	BtnCloseShop.global_position = gp + Vector2(sz.x - btn_sz.x - 16.0, 42.0)

func _on_shop_close_pressed() -> void:
	var panel := get_node_or_null("Content/CenterShop/PanelShop") as Control
	if panel != null:
		panel.visible = false
		panel.scale = Vector2(1, 1)
		panel.set_as_top_level(false)
		if BtnCloseShop != null:
			BtnCloseShop.visible = false
		var btn_back_shop := find_child("BtnBackShop", true, false) as Button
		if btn_back_shop != null:
			btn_back_shop.visible = false
			btn_back_shop.disabled = true
			btn_back_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ---------------------------------------------------------------------------

func _place_capacity_label() -> void:
	if LblCapacity == null:
		return

	# ✅ overlay (hors layout des Containers)
	LblCapacity.set_as_top_level(true)
	LblCapacity.z_index = (RenderingServer.CANVAS_ITEM_Z_MAX - 1)
	LblCapacity.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Taille minimale (pour éviter un "grand panneau" vide)
	LblCapacity.custom_minimum_size = Vector2(0, 0)
	LblCapacity.size = LblCapacity.get_combined_minimum_size()

	var y: float = 20.0
	if has_node("Title"):
		var t := ($Title as Control)
		y = t.global_position.y

	var vpw: float = get_viewport_rect().size.x
	var w: float = LblCapacity.size.x
	if w <= 1.0:
		w = 220.0

	# marge droite 20px
	LblCapacity.global_position = Vector2((vpw - w) / 2.0, y)



func _stadium_current_capacity_value() -> int:
	if save_node != null and save_node.has_method("stadium_current_capacity"):
		return int(save_node.call("stadium_current_capacity"))
	return int(STADIUM_CAPACITY_DEFAULT)

func _stadium_current_level_text() -> String:
	if save_node != null and save_node.has_method("stadium_level_str"):
		return _stadium_tr("stadium.title") + " : " + _stadium_tr("stadium.level").to_lower() + " " + str(save_node.call("stadium_level_str"))
	return "Stade : niveau 1.1"


func _stadium_is_level_1_1() -> bool:
	if save_node != null and save_node.has_method("stadium_level_str"):
		var level := str(save_node.call("stadium_level_str"))
		return level == "1.0" or level == "1.1"
	return true


func _stadium_is_basic_improvements_target(ng: int, ns: int) -> bool:
	return ng == 1 and ns == 1


func _stadium_is_shop_or_ticketing_open() -> bool:
	var pshop := get_node_or_null("Content/CenterShop/PanelShop") as CanvasItem
	if pshop != null and pshop.visible:
		return true
	if PanelTicketing != null and PanelTicketing.visible:
		return true
	return false


func _stadium_level_1_1_main_text_black() -> bool:
	return _bm_stadium_is_mobile_layout() and _stadium_is_level_1_1() and not _stadium_is_shop_or_ticketing_open()


func _stadium_find_popularity_label(root: Node = self) -> Label:
	for c in root.get_children():
		if c is Label:
			var lbl := c as Label
			var nm := String(lbl.name).to_lower()
			var txt := String(lbl.text).to_lower()
			if nm.find("pop") != -1 or txt.find("popular") != -1:
				return lbl
		var found := _stadium_find_popularity_label(c)
		if found != null:
			return found
	return null

func _stadium_hide_title_and_fix_popularity() -> void:
	if has_node("Title"):
		var title_node := get_node("Title") as CanvasItem
		if title_node != null:
			title_node.visible = false

	var pop_lbl := _stadium_find_popularity_label()
	if pop_lbl != null:
		var current := String(pop_lbl.text)
		var suffix := ""
		var sep := current.find(":")
		if sep != -1 and sep + 1 < current.length():
			suffix = current.substr(sep + 1, current.length() - sep - 1).strip_edges()

		var pop_key := _stadium_tr("club.popularity")
		if pop_key == "club.popularity":
			pop_key = "Popularity"

		pop_lbl.text = pop_key + (" : " + suffix if suffix != "" else " :")
		var pop_color := Color(0, 0, 0, 1) if _stadium_level_1_1_main_text_black() else Color(1, 1, 1, 1)
		pop_lbl.modulate = pop_color
		pop_lbl.self_modulate = pop_color
		pop_lbl.add_theme_color_override("font_color", pop_color)
		pop_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		pop_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
		pop_lbl.add_theme_constant_override("outline_size", 0)
		pop_lbl.set_as_top_level(true)
		pop_lbl.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 2
		pop_lbl.visible = true

func _stadium_refresh_tabs_visibility() -> void:
	var tabs: Array = ["Stade", "Billetterie", "Boutique"]
	if save_node != null and save_node.has_method("stadium_tabs_unlocked"):
		var tabs_any: Variant = save_node.call("stadium_tabs_unlocked")
		if typeof(tabs_any) == TYPE_ARRAY:
			tabs = tabs_any as Array

	if has_node("Tabs/BtnTabShop"):
		$Tabs/BtnTabShop.visible = tabs.has("Boutique")
	if has_node("Tabs/BtnTabTicketing"):
		$Tabs/BtnTabTicketing.visible = tabs.has("Billetterie")
	if has_node("Tabs/BtnTabCafe"):
		$Tabs/BtnTabCafe.visible = tabs.has("Cafétéria")
	if has_node("Tabs/BtnTabUpgrade"):
		$Tabs/BtnTabUpgrade.visible = true



func _ensure_capacity_label() -> void:
	# ✅ Overlay hors layout (CanvasLayer) => impossible d'être repositionné sous les onglets
	var layer := get_node_or_null("CapacityOverlayLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CapacityOverlayLayer"
		add_child(layer)

	if LblCapacity == null:
		LblCapacity = layer.get_node_or_null("LblCapacity") as Label
	if LblCapacity == null:
		LblCapacity = Label.new()
		LblCapacity.name = "LblCapacity"
		LblCapacity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LblCapacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		LblCapacity.add_theme_font_size_override("font_size", 28)
		layer.add_child(LblCapacity)

	if LblStadiumLevel == null:
		LblStadiumLevel = layer.get_node_or_null("LblStadiumLevel") as Label
	if LblStadiumLevel == null:
		LblStadiumLevel = Label.new()
		LblStadiumLevel.name = "LblStadiumLevel"
		LblStadiumLevel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		LblStadiumLevel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		LblStadiumLevel.add_theme_font_size_override("font_size", 26)
		layer.add_child(LblStadiumLevel)

	# Texte compact (réduit l'écart "Capacité" / "5500")
	LblCapacity.text = _stadium_tr("stadium.capacity") + " : " + _format_capacity(_stadium_current_capacity_value())
	LblStadiumLevel.text = _stadium_current_level_text()

	var info_color := Color(0, 0, 0, 1)
	LblCapacity.modulate = info_color
	LblCapacity.add_theme_color_override("font_color", info_color)
	LblCapacity.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
	LblStadiumLevel.modulate = info_color
	LblStadiumLevel.add_theme_color_override("font_color", info_color)
	LblStadiumLevel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))

	# Position exacte : même Y que Title, X à droite
	var y: float = 20.0
	if has_node("Title"):
		var t := ($Title as Control)
		y = t.global_position.y

	var w: float = LblCapacity.get_combined_minimum_size().x
	if w <= 1.0:
		w = 220.0

	var vpw: float = get_viewport_rect().size.x
	var cap_w: float = LblCapacity.get_combined_minimum_size().x
	LblCapacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	LblCapacity.position = Vector2((vpw - cap_w) / 2.0, y)

	if LblStadiumLevel != null:
		LblStadiumLevel.text = _stadium_current_level_text()
		var lvl_w: float = LblStadiumLevel.get_combined_minimum_size().x
		LblStadiumLevel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		LblStadiumLevel.size = LblStadiumLevel.get_combined_minimum_size()
		LblStadiumLevel.position = Vector2((vpw - lvl_w) / 2.0, y + 30.0)

	# --- AUDIT (1 run) ---
func _stadium_apply_i18n() -> void:
	_stadium_apply_texts_auto(self)
	# Ne touche pas au boot / navigation. Juste textes.
	if has_node("Title"):
		($Title as Label).visible = false
	if has_node("BtnRetour"):
		var back_txt: String = _stadium_tr("season.back_to_management")
		# blindage: si pas traduit, on force un libellé correct
		if back_txt == "season.back_to_management":
			var loc: String = TranslationServer.get_locale()
			var lang: String = loc.split("_")[0] if loc.find("_") != -1 else loc
			match lang:
				"fr": back_txt = "Retour au Management"
				"en": back_txt = "Back to Management"
				"es": back_txt = "Volver a Gestión"
				"it": back_txt = "Torna alla Gestione"
				"pt": back_txt = "Voltar à Gestão"
				_: back_txt = "Back to Management"
		($BtnRetour as Button).text = back_txt
		_bm_apply_back_button_style($BtnRetour as Button)
	if LblCapacity != null:
		LblCapacity.text = _stadium_tr("stadium.capacity") + " : " + _format_capacity(_stadium_current_capacity_value())
	if LblStadiumLevel != null:
		LblStadiumLevel.text = _stadium_current_level_text()
	BtnTabShop.text = _stadium_tr("stadium.tab.shop")
	BtnTabTicketing.text = _stadium_tr("stadium.tab.ticketing")
	BtnTabCafe.text = _stadium_tr("stadium.tab.cafe")
	BtnTabUpgrade.text = _stadium_tr("stadium.tab.upgrade")
	print("[STADIUM][I18N] shop=", BtnTabShop.text, " | ticketing=", BtnTabTicketing.text, " | upgrade=", BtnTabUpgrade.text)
	_stadium_refresh_tabs_visibility()

	LblTicketingTitle.text = _stadium_tr("stadium.ticketing.title")
	_update_ticketing_total()
	call_deferred("_place_capacity_label")

func _stadium_bind_tabs() -> void:
	# Par défaut : aucun panel (Billetterie apparaît seulement au clic)
	if PanelTicketing != null:
		PanelTicketing.visible = false
	# Boutique
	_ensure_shop_panel()
	var pshop := get_node_or_null("Content/CenterShop/PanelShop")
	var bg_root := get_node_or_null("Bg") as TextureRect
	if bg_root != null:
		bg_root.texture = load(_stadium_current_image_path())
	var shop_screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
	if shop_screen_bg != null:
		shop_screen_bg.visible = false

	if pshop != null and pshop is CanvasItem:
		(pshop as CanvasItem).visible = false
	if not BtnTabShop.pressed.is_connected(_on_tab_shop):
		BtnTabShop.pressed.connect(_on_tab_shop)


	if not BtnTabTicketing.pressed.is_connected(_on_tab_ticketing):
		BtnTabTicketing.pressed.connect(_on_tab_ticketing)

	if not BtnTabUpgrade.pressed.is_connected(_on_tab_upgrade):
		BtnTabUpgrade.pressed.connect(_on_tab_upgrade)


func _stadium_current_matchs_saison() -> int:
	if save_node != null and save_node.has_method("read_dict"):
		var d_any: Variant = save_node.call("read_dict")
		if typeof(d_any) == TYPE_DICTIONARY:
			var d: Dictionary = d_any as Dictionary
			if d.has("progress") and typeof(d["progress"]) == TYPE_DICTIONARY:
				var progress: Dictionary = d["progress"] as Dictionary
				var journee: int = int(progress.get("journee", 1))
				return maxi(0, journee - 1)
	return 0

func _ensure_upgrade_dialogs() -> void:
	if _upgrade_confirm_dialog == null:
		var cd := ConfirmationDialog.new()
		cd.name = "UpgradeConfirmDialog"
		add_child(cd)
		_upgrade_confirm_dialog = cd
		var _ok_btn := cd.get_ok_button()
		if _ok_btn != null:
			_ok_btn.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
		var cb := Callable(self, "_on_upgrade_confirmed")
		if not cd.confirmed.is_connected(cb):
			cd.confirmed.connect(cb)

	if _upgrade_info_dialog == null:
		var ad := AcceptDialog.new()
		ad.get_label().add_theme_font_size_override("font_size", 26)
		ad.add_theme_font_size_override("font_size", 26)
		ad.name = "UpgradeInfoDialog"
		ad.min_size = Vector2i(760, 0)
		ad.add_theme_font_size_override("title_font_size", 28)
		ad.add_theme_font_size_override("font_size", 26)
		add_child(ad)
		_upgrade_info_dialog = ad

func _show_upgrade_info(message: String, alert_red: bool = false) -> void:
	_ensure_upgrade_dialogs()
	if alert_red:
		_show_upgrade_insufficient_funds_popup(message)
		return
	if _upgrade_info_dialog != null:
		_upgrade_info_dialog.remove_theme_stylebox_override("panel")
		_upgrade_info_dialog.remove_theme_stylebox_override("embedded_border")
		_upgrade_info_dialog.remove_theme_stylebox_override("embedded_unfocused_border")
		var dialog_message := message.replace("[/color] €", " €[/color]").replace("[color=#F21F1F]", "").replace("[/color]", "")
		var _dialog_label := _upgrade_info_dialog.get_label()
		if _dialog_label != null:
			_dialog_label.visible = true
			_dialog_label.remove_theme_color_override("font_color")
			_dialog_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var _rich_label := _upgrade_info_dialog.find_child("UpgradeInfoRichLabel", true, false) as RichTextLabel
		if _rich_label != null:
			_rich_label.visible = false
		_upgrade_info_dialog.dialog_text = dialog_message
		var _ok_btn := _upgrade_info_dialog.get_ok_button()
		if _ok_btn != null:
			_ok_btn.add_theme_font_size_override("font_size", 26)
		_upgrade_info_dialog.popup_centered()


func _show_upgrade_insufficient_funds_popup(message: String) -> void:
	var old_popup := get_node_or_null("UpgradeInsufficientFundsPopup")
	if old_popup != null:
		old_popup.queue_free()

	var popup := Control.new()
	popup.name = "UpgradeInsufficientFundsPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	add_child(popup)
	popup.set_as_top_level(true)
	popup.global_position = Vector2.ZERO
	popup.size = get_viewport_rect().size

	var card := Control.new()
	card.name = "UpgradeInsufficientFundsCard"
	card.size = Vector2(760, 300)
	card.position = (get_viewport_rect().size - card.size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = true
	popup.add_child(card)
	card.z_index = RenderingServer.CANVAS_ITEM_Z_MAX

	var bg := TextureRect.new()
	bg.name = "UpgradeInsufficientFundsBG"
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

	var title := Label.new()
	title.name = "LblUpgradeInsufficientFundsTitle"
	title.text = _stadium_tr("stadium.upgrade.insufficient_funds_title")
	if title.text == "stadium.upgrade.insufficient_funds_title":
		title.text = "Insufficient funds"
	title.position = Vector2(28, 22)
	title.size = Vector2(704, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var body := Label.new()
	body.name = "LblUpgradeInsufficientFundsBody"
	body.text = message.replace("[/color] €", " €[/color]").replace("[color=#F21F1F]", "").replace("[/color]", "")
	body.position = Vector2(44, 96)
	body.size = Vector2(672, 92)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(body)

	var ok_btn := Button.new()
	ok_btn.name = "BtnUpgradeInsufficientFundsOK"
	ok_btn.text = "OK"
	ok_btn.position = Vector2(300, 220)
	ok_btn.size = Vector2(160, 54)
	ok_btn.add_theme_font_size_override("font_size", 26)
	_shop_apply_confirm_style(ok_btn)
	ok_btn.pressed.connect(func() -> void:
		popup.queue_free()
	)
	card.add_child(ok_btn)



func _stadium_refresh_token_labels() -> void:
	var d: Dictionary = PlayerLife.load_savegame()
	var tokens_ui: int = PlayerLife.get_tokens(d)
	var root: Node = get_tree().current_scene
	if root == null:
		root = self
	for n in root.find_children("LblHudTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = "Tokens " + str(tokens_ui)
	for n in root.find_children("LblTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = str(tokens_ui)



func _bm_refresh_price_adjust_mission_counter() -> void:
	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		d = {}

	if not d.has("missions_state") or typeof(d["missions_state"]) != TYPE_DICTIONARY:
		d["missions_state"] = {}
	var ms: Dictionary = d["missions_state"] as Dictionary

	if not ms.has("counters") or typeof(ms["counters"]) != TYPE_DICTIONARY:
		ms["counters"] = {}
	var counters: Dictionary = ms["counters"] as Dictionary

	var count := 0

	# Billetterie = 1 si au moins un prix a été renseigné
	var has_ticketing := false
	if PriceA != null and PriceB != null and PriceC != null:
		has_ticketing = _safe_int(PriceA.text) > 0 or _safe_int(PriceB.text) > 0 or _safe_int(PriceC.text) > 0
	if not has_ticketing and d.has("ticketing") and typeof(d["ticketing"]) == TYPE_DICTIONARY:
		var tt_root: Dictionary = d["ticketing"] as Dictionary
		has_ticketing = int(tt_root.get("price_a", 0)) > 0 or int(tt_root.get("price_b", 0)) > 0 or int(tt_root.get("price_c", 0)) > 0
	if not has_ticketing and d.has("stadium") and typeof(d["stadium"]) == TYPE_DICTIONARY:
		var st: Dictionary = d["stadium"] as Dictionary
		if st.has("ticketing") and typeof(st["ticketing"]) == TYPE_DICTIONARY:
			var tt: Dictionary = st["ticketing"] as Dictionary
			has_ticketing = int(tt.get("price_a", 0)) > 0 or int(tt.get("price_b", 0)) > 0 or int(tt.get("price_c", 0)) > 0
	if has_ticketing:
		count += 1

	# Boutique = 1 si au moins un prix produit existe
	var has_shop := false
	if _shop_price_by_id.size() > 0:
		for pid in _shop_price_by_id.keys():
			if int(_shop_price_by_id.get(pid, 0)) > 0:
				has_shop = true
				break
	if not has_shop and d.has("shop") and typeof(d["shop"]) == TYPE_DICTIONARY:
		var shop: Dictionary = d["shop"] as Dictionary
		var items_any: Variant = shop.get("items", {})
		if typeof(items_any) == TYPE_DICTIONARY:
			var items: Dictionary = items_any as Dictionary
			for pid2 in items.keys():
				var row_any: Variant = items[pid2]
				if typeof(row_any) == TYPE_DICTIONARY and int((row_any as Dictionary).get("price", 0)) > 0:
					has_shop = true
					break
	if has_shop:
		count += 1

	counters["price_adjust_done"] = count
	ms["counters"] = counters
	d["missions_state"] = ms
	PlayerLife.write_savegame(d)
	print("[MISSIONS][PRICE] price_adjust_done=", count)


func _refresh_upgrade_works_ui(ng_cur: int, ns_cur: int, rem: int, total: int) -> void:
	_ensure_upgrade_panel()
	var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as Control
	if panel == null:
		return
	panel.visible = true
	_stadium_set_active_panel(panel)
	_stadium_make_panel_full_screen(panel)
	var upgrade_vp_size_refresh := get_viewport_rect().size
	var upgrade_panel_size_refresh := upgrade_vp_size_refresh * 0.8
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = upgrade_vp_size_refresh.x * 0.1
	panel.offset_top = upgrade_vp_size_refresh.y * 0.1
	panel.offset_right = -upgrade_vp_size_refresh.x * 0.1
	panel.offset_bottom = -upgrade_vp_size_refresh.y * 0.1
	panel.custom_minimum_size = upgrade_panel_size_refresh
	panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	if LblCapacity != null:
		LblCapacity.visible = false
	if LblStadiumLevel != null:
		LblStadiumLevel.visible = false

	var btn_confirm := _get_upgrade_confirm_button(panel)
	var target_title := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/LblUpgradeTargetTitle") as Label
	var lbl_title := panel.get_node_or_null("VBoxUpgrade/LblUpgradeInProgressTitle") as Label
	var pb := panel.get_node_or_null("VBoxUpgrade/ProgressBarUpgradeWorks") as ProgressBar
	var lbl_remaining := panel.get_node_or_null("VBoxUpgrade/LblUpgradeRemaining") as Label
	var btn_accel := panel.get_node_or_null("VBoxUpgrade/BtnUpgradeAccelerate") as Button
	var info := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/LblUpgradeInfo") as RichTextLabel
	var frame := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame") as Control
	var root := panel.get_node_or_null("VBoxUpgrade") as Control
	var upgrade_box := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox") as VBoxContainer
	var bg_up := panel.get_node_or_null("UpgradeBG") as TextureRect
	if bg_up != null:
		bg_up.visible = true
		bg_up.modulate = Color(1, 1, 1, 1)
		bg_up.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_up.offset_left = 0
		bg_up.offset_top = 0
		bg_up.offset_right = 0
		bg_up.offset_bottom = 0
		bg_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_up.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var next_bg_path := "res://assets/images/stades/stade_115.png" if _stadium_is_basic_improvements_target(ng_cur, ns_cur) else "res://assets/images/stades/stade_" + str(ng_cur) + str(ns_cur) + ".png"
		if ResourceLoader.exists(next_bg_path):
			bg_up.texture = load(next_bg_path) as Texture2D
			panel.move_child(bg_up, 0)
			bg_up.z_index = 0
		var old_outer_frame := panel.get_node_or_null("ShopOverlayFrame") as CanvasItem
		if old_outer_frame != null:
			old_outer_frame.visible = false
	if frame != null:
		if frame is PanelContainer:
			_apply_upgrade_readability_panel_style(frame as PanelContainer)
		frame.custom_minimum_size = Vector2(0, 0)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if root != null:
		root.scale = Vector2(1, 1)
		root.offset_left = 80
		root.offset_top = 70
		root.offset_right = -80
		root.offset_bottom = -70
	if upgrade_box != null:
		upgrade_box.alignment = BoxContainer.ALIGNMENT_CENTER
		upgrade_box.add_theme_constant_override("separation", 58)

	var accel_tokens: int = int(StadiumDataRef.ACCELERATION_TOKENS.get(StadiumDataRef.level_key(ng_cur, ns_cur), 0))
	var tokens_now: int = 0
	var save_cur_any: Variant = PlayerLife.load_savegame()
	if typeof(save_cur_any) == TYPE_DICTIONARY:
		tokens_now = PlayerLife.get_tokens(save_cur_any as Dictionary)

	_upgrade_accel_mode = true
	_upgrade_target_ng = ng_cur
	_upgrade_target_ns = ns_cur

	if lbl_title != null:
		lbl_title.visible = false
	if target_title != null:
		target_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		target_title.visible = false
	if info != null:
		info.add_theme_color_override("default_color", Color(0, 0, 0, 1))
		info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		info.add_theme_constant_override("outline_size", 0)

	if pb != null:
		pb.visible = false
		pb.queue_free()

	if lbl_remaining != null:
		lbl_remaining.visible = false
		lbl_remaining.queue_free()

	if btn_accel != null:
		btn_accel.visible = false
		btn_accel.queue_free()

	var loc := TranslationServer.get_locale().to_lower()
	if btn_confirm != null:
		btn_confirm.visible = true
		btn_confirm.disabled = false
		btn_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
		if not btn_confirm.pressed.is_connected(_on_upgrade_confirmed):
			btn_confirm.pressed.connect(_on_upgrade_confirmed)
		var accel_text := "Accelerate"
		if loc.begins_with("fr"):
			accel_text = "Accélérer"
		elif loc.begins_with("es"):
			accel_text = "Acelerar"
		elif loc.begins_with("it"):
			accel_text = "Accelera"
		elif loc.begins_with("pt"):
			accel_text = "Acelerar"
		btn_confirm.text = accel_text
		btn_confirm.disabled = tokens_now < accel_tokens

	if info != null:
		info.fit_content = false
		info.custom_minimum_size = Vector2(740, 130)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.scroll_active = false
		info.bbcode_enabled = true
		info.text = "[center]" \
			+ _stadium_tr("stadium.upgrade.works_in_progress_title") \
			+ "\n\n" + _stadium_tr("stadium.target_level") + " : " + str(ng_cur) + "." + str(ns_cur) \
			+ "\n" + "Durée des travaux : " + str(total) + " match(s)" \
			+ "\n" + _stadium_fmt("stadium.upgrade.remaining_matches", {"remaining": rem}) \
			+ "\nTokens : " + str(tokens_now) + " / " + str(accel_tokens) \
			+ "[/center]"

func _prompt_upgrade_acceleration(rem: int, ng_cur: int, ns_cur: int) -> void:
	var key_cur: String = StadiumDataRef.level_key(ng_cur, ns_cur)
	var accel_cost: int = int(StadiumDataRef.ACCELERATION_TOKENS.get(key_cur, 0))
	var tokens_now: int = 0
	var save_cur_any: Variant = PlayerLife.load_savegame()
	if typeof(save_cur_any) == TYPE_DICTIONARY:
		tokens_now = PlayerLife.get_tokens(save_cur_any as Dictionary)
	_upgrade_accel_mode = true
	_upgrade_target_ng = ng_cur
	_upgrade_target_ns = ns_cur
	_ensure_upgrade_dialogs()
	if _upgrade_confirm_dialog != null:
		_upgrade_confirm_dialog.dialog_text = _stadium_fmt("stadium.upgrade.accel_confirm", {
			"level": str(ng_cur) + "." + str(ns_cur),
			"remaining": rem,
			"after": 0,
			"tokens": accel_cost,
			"available": tokens_now
		})
		var accel_text := "Accelerate"
		var k := _stadium_tr("stadium.upgrade.accelerate_now")
		if k != "stadium.upgrade.accelerate_now":
			accel_text = k
		else:
			var loc := TranslationServer.get_locale().to_lower()
			if loc.begins_with("fr"):
				accel_text = "Accélérer"
			elif loc.begins_with("es"):
				accel_text = "Acelerar"
			elif loc.begins_with("it"):
				accel_text = "Accelera"
			elif loc.begins_with("pt"):
				accel_text = "Acelerar"
		_upgrade_confirm_dialog.get_ok_button().text = accel_text
		var _tok_icon := load("res://assets/images/token.png") as Texture2D
		_upgrade_confirm_dialog.get_ok_button().icon = _tok_icon
		print("[POPUP_ACCEL] btn=", _upgrade_confirm_dialog.get_ok_button(), " icon=", _tok_icon, " btn_icon=", _upgrade_confirm_dialog.get_ok_button().icon)

		_upgrade_confirm_dialog.get_ok_button().icon = load("res://assets/images/token.png") as Texture2D
		_upgrade_confirm_dialog.popup_centered()


func _on_upgrade_accelerate_pressed() -> void:
	if save_node_check != null and save_node_check.has_method("read_dict"):
		var d_any: Variant = save_node_check.call("read_dict")
		if typeof(d_any) == TYPE_DICTIONARY:
			var d: Dictionary = d_any as Dictionary
			if d.has("stadium") and typeof(d["stadium"]) == TYPE_DICTIONARY:
				var st: Dictionary = d["stadium"] as Dictionary
				if bool(st.get("travaux_en_cours", false)):
					_prompt_upgrade_acceleration(
						int(st.get("travaux_matches_restants", 0)),
						int(st.get("travaux_cible_ng", 0)),
						int(st.get("travaux_cible_ns", 0))
				)


func _upgrade_force_btn_retour_front() -> void:
	if BtnRetour == null:
		return
	var _gp_retour := BtnRetour.global_position
	var _sz_retour := BtnRetour.size
	BtnRetour.visible = true
	BtnRetour.disabled = false
	BtnRetour.set_as_top_level(true)
	BtnRetour.global_position = _gp_retour
	BtnRetour.size = _sz_retour
	BtnRetour.z_index = 20000
	BtnRetour.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_tab_upgrade() -> void:
	if save_node_check != null and save_node_check.has_method("read_dict"):
		var d_any: Variant = save_node_check.call("read_dict")
		if typeof(d_any) == TYPE_DICTIONARY:
			var d: Dictionary = d_any as Dictionary
			if d.has("stadium") and typeof(d["stadium"]) == TYPE_DICTIONARY:
				var st: Dictionary = d["stadium"] as Dictionary
				if bool(st.get("travaux_en_cours", false)) and int(st.get("travaux_matches_restants", 0)) > 0 and int(st.get("travaux_cible_ng", 0)) > 0 and int(st.get("travaux_cible_ns", 0)) > 0:
					var rem: int = int(st.get("travaux_matches_restants", 0))
					var ng_cur: int = int(st.get("travaux_cible_ng", 0))
					var ns_cur: int = int(st.get("travaux_cible_ns", 0))
					var total_cur: int = int(st.get("travaux_duree_totale", rem))
					_upgrade_target_ng = ng_cur
					_upgrade_target_ns = ns_cur

					var _cs := get_node_or_null("Content/CenterShop") as Control
					if _cs != null:
						_cs.visible = false
						_cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var shop_screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
					if shop_screen_bg != null:
						shop_screen_bg.visible = false

					var _pshop := get_node_or_null("Content/CenterShop/PanelShop")
					if _pshop != null and _pshop is CanvasItem:
						(_pshop as CanvasItem).visible = false

					if PanelTicketing != null:
						PanelTicketing.visible = false
						PanelTicketing.scale = Vector2(1, 1)

					if BtnCloseTicketing != null:
						BtnCloseTicketing.visible = false
					if BtnCloseShop != null:
						BtnCloseShop.visible = false

					_ensure_upgrade_panel()
					var center_up := get_node_or_null("Content/CenterUpgrade") as Control
					if center_up != null:
						center_up.visible = true
						center_up.mouse_filter = Control.MOUSE_FILTER_PASS

						var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as Control
						if panel != null:
							panel.visible = true
							panel.mouse_filter = Control.MOUSE_FILTER_PASS
							_stadium_make_panel_full_screen(panel)
							var upgrade_vp_size_works := get_viewport_rect().size
							var upgrade_panel_size_works := upgrade_vp_size_works * 0.8
							panel.set_anchors_preset(Control.PRESET_FULL_RECT)
							panel.offset_left = upgrade_vp_size_works.x * 0.1
							panel.offset_top = upgrade_vp_size_works.y * 0.1
							panel.offset_right = -upgrade_vp_size_works.x * 0.1
							panel.offset_bottom = -upgrade_vp_size_works.y * 0.1
							panel.custom_minimum_size = upgrade_panel_size_works
							panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
						call_deferred("_upgrade_force_btn_retour_front")
						_refresh_upgrade_works_ui(ng_cur, ns_cur, rem, total_cur)
						return

	var _cs := get_node_or_null("Content/CenterShop") as Control
	if _cs != null:
		_cs.visible = false
		_cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shop_screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
	if shop_screen_bg != null:
		shop_screen_bg.visible = false

	var _pshop := get_node_or_null("Content/CenterShop/PanelShop")
	if _pshop != null and _pshop is CanvasItem:
		(_pshop as CanvasItem).visible = false

	var _shop_overlay_frame := get_node_or_null("Content/CenterShop/PanelShop/ShopOverlayFrame") as CanvasItem
	if _shop_overlay_frame != null:
		_shop_overlay_frame.modulate = Color(1, 1, 1, 0)

	if PanelTicketing != null:
		PanelTicketing.visible = false
		PanelTicketing.scale = Vector2(1, 1)

	if BtnCloseTicketing != null:
		BtnCloseTicketing.visible = false
	if BtnCloseShop != null:
		BtnCloseShop.visible = false

	if save_node == null:
		_show_upgrade_info(_stadium_tr("stadium.upgrade.save_missing"))
		return

	if not save_node.has_method("stadium_next_level"):
		_show_upgrade_info(_stadium_tr("stadium.upgrade.next_level_missing"))
		return

	var next_any: Variant = save_node.call("stadium_next_level")
	if typeof(next_any) != TYPE_VECTOR2I:
		_show_upgrade_info(_stadium_tr("stadium.upgrade.none_available"))
		return

	var next_level: Vector2i = next_any
	var ng: int = next_level.x
	var ns: int = next_level.y

	var current_level: String = ""
	if save_node.has_method("stadium_level_str"):
		current_level = str(save_node.call("stadium_level_str"))

	var cost: int = 0
	if save_node.has_method("stadium_cost_for"):
		cost = int(save_node.call("stadium_cost_for", ng, ns))

	var duration: int = 0
	if save_node.has_method("stadium_duration_for"):
		duration = int(save_node.call("stadium_duration_for", ng, ns))

	var accel_tokens: int = int(StadiumDataRef.ACCELERATION_TOKENS.get(StadiumDataRef.level_key(ng, ns), 0))
	var target_capacity: int = int(StadiumDataRef.get_capacity(ng, ns))
	var current_capacity_for_upgrade: int = maxi(1, _stadium_current_capacity_value())
	var capacity_gain_percent: int = int(round((float(target_capacity - current_capacity_for_upgrade) / float(current_capacity_for_upgrade)) * 100.0))

	_upgrade_target_ng = ng
	_upgrade_target_ns = ns
	_upgrade_accel_mode = false

	_ensure_upgrade_panel()

	var center_up := get_node_or_null("Content/CenterUpgrade") as Control
	if center_up != null:
		center_up.visible = true
		center_up.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as Control
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_stadium_make_panel_full_screen(panel)
		var upgrade_vp_size_open := get_viewport_rect().size
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.custom_minimum_size = upgrade_vp_size_open
		panel.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
		panel.visible = true
		if LblCapacity != null:
			LblCapacity.visible = false
		if LblStadiumLevel != null:
			LblStadiumLevel.visible = false

		# BM_EVOL_STADE_PANEL_TRANSPARENT_V1
		var empty_panel_style := StyleBoxEmpty.new()
		if panel is Panel:
			(panel as Panel).add_theme_stylebox_override("panel", empty_panel_style)
		elif panel is PanelContainer:
			(panel as PanelContainer).add_theme_stylebox_override("panel", empty_panel_style)

		var is_basic_improvements := _stadium_is_basic_improvements_target(ng, ns)
		var bg_up := panel.get_node_or_null("UpgradeBG") as TextureRect
		if bg_up != null:
			# BM_EVOL_STADE_BG_VISIBLE_FIX_V2
			bg_up.visible = true
			bg_up.modulate = Color(1, 1, 1, 1)
			bg_up.set_as_top_level(false)
			bg_up.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_up.offset_left = 0
			bg_up.offset_top = 0
			bg_up.offset_right = 0
			bg_up.offset_bottom = 0
			bg_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_up.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			var current_bg_path_direct := _stadium_current_image_path()
			if ResourceLoader.exists(current_bg_path_direct):
				bg_up.texture = load(current_bg_path_direct) as Texture2D
			panel.move_child(bg_up, 0)
			bg_up.offset_bottom = 0
			bg_up.size = get_viewport_rect().size
			bg_up.z_index = 0
			bg_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		call_deferred("_upgrade_force_btn_retour_front")

		if BtnRetour != null:
			var _gp_retour := BtnRetour.global_position
			BtnRetour.set_as_top_level(true)
			BtnRetour.global_position = _gp_retour
			BtnRetour.z_index = 10000
			BtnRetour.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		if BtnRetour != null:
			BtnRetour.mouse_filter = Control.MOUSE_FILTER_STOP
			BtnRetour.z_index = 5000

		var vbox_up := panel.get_node_or_null("VBoxUpgrade") as Control
		if vbox_up != null:
			if vbox_up is BoxContainer:
				(vbox_up as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
			vbox_up.mouse_filter = Control.MOUSE_FILTER_PASS
			vbox_up.scale = Vector2(1, 1)
			vbox_up.offset_left = 80
			vbox_up.offset_top = 70
			vbox_up.offset_right = -80
			vbox_up.offset_bottom = -70
			var spacer := vbox_up.get_node_or_null("UpgradeTopSpacer") as Control
			if spacer == null:
				spacer = Control.new()
				spacer.name = "UpgradeTopSpacer"
				spacer.custom_minimum_size = Vector2(0, 10)
				vbox_up.add_child(spacer)
				vbox_up.move_child(spacer, 0)
			else:
				spacer.custom_minimum_size = Vector2(0, 10)
			var upgrade_frame := vbox_up.get_node_or_null("UpgradeInfoFrame") as PanelContainer
			if upgrade_frame != null:
				_apply_upgrade_readability_panel_style(upgrade_frame)
				upgrade_frame.custom_minimum_size = Vector2(960, 680)
				upgrade_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				upgrade_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var upgrade_box := upgrade_frame.get_node_or_null("UpgradeInfoBox") as VBoxContainer
				if upgrade_box == null:
					upgrade_box = VBoxContainer.new()
					upgrade_box.name = "UpgradeInfoBox"
					upgrade_frame.add_child(upgrade_box)
				upgrade_box.alignment = BoxContainer.ALIGNMENT_CENTER
				upgrade_box.add_theme_constant_override("separation", 18)
				var old_info := upgrade_frame.get_node_or_null("LblUpgradeInfo") as RichTextLabel
				if old_info != null:
					upgrade_frame.remove_child(old_info)
					upgrade_box.add_child(old_info)
				var old_confirm := vbox_up.get_node_or_null("BtnConfirmUpgradePanel") as Button
				if old_confirm != null:
					vbox_up.remove_child(old_confirm)
					upgrade_box.add_child(old_confirm)
			var old_target_title := vbox_up.get_node_or_null("LblUpgradeTargetTitle") as Label
			if old_target_title != null:
				vbox_up.remove_child(old_target_title)
				old_target_title.queue_free()
		var old_outer_frame := panel.get_node_or_null("ShopOverlayFrame") as CanvasItem
		if old_outer_frame != null:
			old_outer_frame.visible = false

		_stadium_set_active_panel(panel)

		if LblCapacity != null:
			LblCapacity.visible = false

		if LblStadiumLevel != null:
			LblStadiumLevel.visible = false

		# BM_EVOL_STADE_CURRENT_BG_V1: image du stade actuel en fond de l'écran Evol Stade
		var upgrade_bg := panel.get_node_or_null("UpgradeBG") as TextureRect
		if upgrade_bg != null:
			var current_bg_path := _stadium_current_image_path()
			if ResourceLoader.exists(current_bg_path):
				upgrade_bg.texture = load(current_bg_path) as Texture2D

		var info := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/LblUpgradeInfo") as RichTextLabel
		var upgrade_target_title := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/LblUpgradeTargetTitle") as Label
		var upgrade_info_box := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox") as VBoxContainer
		var next_image := panel.get_node_or_null("VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/UpgradeNextImage") as TextureRect
		if next_image == null and upgrade_info_box != null:
			next_image = TextureRect.new()
			next_image.name = "UpgradeNextImage"
			upgrade_info_box.add_child(next_image)
		if next_image != null and upgrade_info_box != null:
			upgrade_info_box.move_child(next_image, mini(1, upgrade_info_box.get_child_count() - 1))
		if next_image != null:
			var next_image_path := _stadium_image_path_for_level(ng, ns)
			if ResourceLoader.exists(next_image_path):
				next_image.texture = load(next_image_path) as Texture2D
			next_image.custom_minimum_size = UPGRADE_NEXT_IMAGE_SIZE
			next_image.size = UPGRADE_NEXT_IMAGE_SIZE
			next_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			next_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			next_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			next_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			next_image.visible = true
		if upgrade_target_title != null:
			var target_label := _stadium_tr("stadium.basic_improvements") if is_basic_improvements else str(ng) + "." + str(ns)
			upgrade_target_title.text = _stadium_tr("stadium.target_level") + " : " + target_label
			upgrade_target_title.add_theme_font_size_override("font_size", 36)
			upgrade_target_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			upgrade_target_title.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.18, 0.85))
			upgrade_target_title.add_theme_constant_override("outline_size", 2)
			var upgrade_title_sb := StyleBoxFlat.new()
			upgrade_title_sb.bg_color = Color(0.03, 0.16, 0.38, 0.96)
			upgrade_title_sb.border_width_left = 2
			upgrade_title_sb.border_width_top = 2
			upgrade_title_sb.border_width_right = 2
			upgrade_title_sb.border_width_bottom = 2
			upgrade_title_sb.border_color = Color(1.0, 0.05, 0.06, 0.92)
			upgrade_title_sb.corner_radius_top_left = 14
			upgrade_title_sb.corner_radius_top_right = 14
			upgrade_title_sb.corner_radius_bottom_left = 14
			upgrade_title_sb.corner_radius_bottom_right = 14
			upgrade_title_sb.content_margin_left = 22
			upgrade_title_sb.content_margin_right = 22
			upgrade_title_sb.content_margin_top = 6
			upgrade_title_sb.content_margin_bottom = 6
			upgrade_target_title.add_theme_stylebox_override("normal", upgrade_title_sb)
			upgrade_target_title.set_as_top_level(true)
			var upgrade_title_rect := panel.get_global_rect()
			upgrade_target_title.global_position = upgrade_title_rect.position + Vector2(upgrade_title_rect.size.x * 0.29, 76)
			upgrade_target_title.size = Vector2(upgrade_title_rect.size.x * 0.42, 52)
			upgrade_target_title.z_as_relative = false
			upgrade_target_title.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
			upgrade_target_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			upgrade_target_title.visible = true

		if info != null:
			info.add_theme_font_size_override("normal_font_size", 31)
			info.add_theme_color_override("default_color", Color(0, 0, 0, 1))
			info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			info.add_theme_constant_override("outline_size", 0)
			info.bbcode_enabled = false
			info.clear()
			info.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
			info.add_text(_stadium_tr("stadium.capacity") + " : " + _format_int(target_capacity))
			info.newline()
			info.add_text(_stadium_tr("stadium.cost") + " : " + _format_int(cost) + " €")
			info.newline()
			if is_basic_improvements:
				info.add_text(_stadium_tr("stadium.work_duration") + " : " + _stadium_tr("stadium.duration_one_game"))
			else:
				info.add_text(_stadium_tr("stadium.duration") + " : " + str(duration) + " " + _stadium_tr("stadium.duration_unit"))
			info.pop()
			var accel_cost_text := str(accel_tokens) + " tokens"
			# BM_HIDE_ACCELERATION_AVAILABLE_TEXT_V1
			# info.add_text(_stadium_fmt("stadium.upgrade.acceleration_available", {"tokens": accel_tokens}).replace(accel_cost_text, "").strip_edges() + " ")
			var old_token_pill := (info.get_parent() as Node).get_node_or_null("UpgradeTokenPill")
			if old_token_pill != null:
				old_token_pill.queue_free()
			var old_vbox_token_pill_parent := panel.get_node_or_null("VBoxUpgrade") as Node
			if old_vbox_token_pill_parent != null:
				var old_vbox_token_pill := old_vbox_token_pill_parent.get_node_or_null("UpgradeTokenPill")
				if old_vbox_token_pill != null:
					old_vbox_token_pill.queue_free()
			var token_pill_parent := info as Control
			if token_pill_parent != null:
				var token_pill := token_pill_parent.get_node_or_null("UpgradeTokenPill") as PanelContainer
				if token_pill == null:
					token_pill = PanelContainer.new()
					token_pill.name = "UpgradeTokenPill"
					token_pill_parent.add_child(token_pill)
					var token_pill_label := Label.new()
					token_pill_label.name = "LblUpgradeTokenPill"
					token_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					token_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					token_pill.add_child(token_pill_label)
				var token_pill_style := StyleBoxFlat.new()
				token_pill_style.bg_color = Color(0.95, 0.52, 0.12, 1)
				token_pill_style.corner_radius_top_left = 18
				token_pill_style.corner_radius_top_right = 18
				token_pill_style.corner_radius_bottom_left = 18
				token_pill_style.corner_radius_bottom_right = 18
				token_pill.add_theme_stylebox_override("panel", token_pill_style)
				token_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				token_pill.position = Vector2(790, 118)
				token_pill.size = Vector2(150, 34)
				token_pill.visible = false
				var token_pill_label := token_pill.get_node_or_null("LblUpgradeTokenPill") as Label
				if token_pill_label != null:
					token_pill_label.text = accel_cost_text
					token_pill_label.add_theme_font_size_override("font_size", 24)
					token_pill_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
					token_pill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
					token_pill_label.add_theme_constant_override("outline_size", 2)

		var btn_confirm := _get_upgrade_confirm_button(panel)

		var lbl_title := panel.get_node_or_null("VBoxUpgrade/LblUpgradeInProgressTitle") as Label
		var pb := panel.get_node_or_null("VBoxUpgrade/ProgressBarUpgradeWorks") as ProgressBar
		var lbl_remaining := panel.get_node_or_null("VBoxUpgrade/LblUpgradeRemaining") as Label
		var btn_accel := panel.get_node_or_null("VBoxUpgrade/BtnUpgradeAccelerate") as Button
		if btn_confirm != null:
			btn_confirm.text = "Confirm Upgrade"
			btn_confirm.visible = true
			btn_confirm.disabled = false
			btn_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
			if not btn_confirm.pressed.is_connected(_on_upgrade_confirmed):
				btn_confirm.pressed.connect(_on_upgrade_confirmed)
		if lbl_title != null:
			lbl_title.visible = false
		if upgrade_target_title != null:
			upgrade_target_title.visible = true
		if pb != null:
			pb.visible = false
		if lbl_remaining != null:
			lbl_remaining.visible = false
		if btn_accel != null:
			btn_accel.visible = false

func _on_upgrade_confirmed() -> void:
	print("[STADIUM][CONFIRM] entered | accel_mode=", _upgrade_accel_mode, " | target=", _upgrade_target_ng, ".", _upgrade_target_ns)
	if _upgrade_accel_mode:
		_upgrade_accel_mode = false
		var save_cur: Dictionary = {}
		if save_node_check != null and save_node_check.has_method("read_dict"):
			var d_any: Variant = save_node_check.call("read_dict")
			if typeof(d_any) == TYPE_DICTIONARY:
				save_cur = d_any as Dictionary
		if save_cur.is_empty():
			save_cur = PlayerLife.load_savegame()
		if save_cur.is_empty():
			_show_upgrade_info(_stadium_tr("stadium.upgrade.save_missing"))
			return
		var key: String = StadiumDataRef.level_key(_upgrade_target_ng, _upgrade_target_ns)
		var accel_cost: int = int(StadiumDataRef.ACCELERATION_TOKENS.get(key, 0))
		if accel_cost <= 0:
			_show_upgrade_info(_stadium_tr("stadium.upgrade.accel_unavailable"))
			return
		var tokens_now: int = PlayerLife.get_tokens(save_cur)
		if not PlayerLife.spend_tokens(save_cur, accel_cost, "stadium_upgrade_accelerate_" + key):
			_show_upgrade_info(_stadium_fmt("stadium.upgrade.tokens_insufficient", {"available": tokens_now, "required": accel_cost}))
			return
		if not save_cur.has("stadium") or typeof(save_cur["stadium"]) != TYPE_DICTIONARY:
			_show_upgrade_info(_stadium_tr("stadium.upgrade.impossible"))
			return
		var stadium: Dictionary = save_cur["stadium"] as Dictionary
		stadium["niveau_global_jeu"] = _upgrade_target_ng
		stadium["niveau_stade"] = _upgrade_target_ns
		stadium["travaux_en_cours"] = false
		stadium["travaux_cible_ng"] = 0
		stadium["travaux_cible_ns"] = 0
		stadium["travaux_matches_restants"] = 0
		stadium["travaux_duree_totale"] = 0
		stadium["travaux_baseline_matchs_saison"] = 0
		if save_node_check != null and save_node_check.has_method("write_dict"):
			save_node_check.call("write_dict", save_cur)
		else:
			PlayerLife.write_savegame(save_cur)
		_stadium_refresh_tabs_visibility()
		call_deferred("_ensure_capacity_label")
		call_deferred("_stadium_apply_i18n")
		call_deferred("_stadium_refresh_token_labels")
		_show_upgrade_info(_stadium_tr("stadium.upgrade.completed_now"))
		return

	if save_node == null:
		_show_upgrade_info(_stadium_tr("stadium.upgrade.save_missing"))
		return

	if not save_node.has_method("stadium_launch_upgrade"):
		_show_upgrade_info(_stadium_tr("stadium.upgrade.launch_missing"))
		return

	print("[STADIUM][CONFIRM] calling stadium_launch_upgrade")
	var result_any: Variant = save_node.call(
		"stadium_launch_upgrade",
		_upgrade_target_ng,
		_upgrade_target_ns,
		_stadium_current_matchs_saison(),
		false
	)

	print("[STADIUM][CONFIRM] result_any=", result_any)
	if typeof(result_any) != TYPE_DICTIONARY:
		_show_upgrade_info(_stadium_tr("stadium.upgrade.invalid_response"))
		return

	var result: Dictionary = result_any as Dictionary
	if not bool(result.get("ok", false)):
		var reason: String = str(result.get("reason", "unknown"))
		if reason == "insufficient_funds":
			var solde_finances: int = 0
			var save_cur: Variant = PlayerLife.load_savegame()
			if typeof(save_cur) == TYPE_DICTIONARY:
				var dcur: Dictionary = save_cur as Dictionary
				var recettes_finances: int = int(dcur.get("total_billetterie", 0)) + int(dcur.get("total_boutique", 0)) + int(dcur.get("total_sponsors", 0)) + int(dcur.get("total_tournois", 0))
				var depenses_finances: int = int(dcur.get("total_depenses", 0))
				var salaires_finances: int = int(dcur.get("total_salaires", dcur.get("salary_total_per_match", 0)))
				var tournois_fees_finances: int = int(dcur.get("tournois_fees_total", 0))
				if tournois_fees_finances > 0 and depenses_finances < salaires_finances + tournois_fees_finances:
					depenses_finances = salaires_finances + tournois_fees_finances
				solde_finances = recettes_finances - depenses_finances
			_show_upgrade_info(_stadium_fmt("stadium.upgrade.insufficient_funds", {
				"wallet": "[color=#F21F1F]" + _format_int(solde_finances) + "[/color]"
			}), true)
		elif reason == "invalid_target":
			_show_upgrade_info(_stadium_tr("stadium.upgrade.invalid_step"))
		else:
			_show_upgrade_info(_stadium_tr("stadium.upgrade.impossible"))
		return

	_stadium_refresh_tabs_visibility()
	call_deferred("_ensure_capacity_label")
	call_deferred("_stadium_apply_i18n")

	var applied_now: bool = bool(result.get("applied_now", false))
	var duration: int = int(result.get("duration", 0))

	if applied_now:
		_show_upgrade_info(_stadium_tr("stadium.upgrade.applied"))
	else:
		_ensure_upgrade_panel()
		var center_up := get_node_or_null("Content/CenterUpgrade") as Control
		if center_up != null:
			center_up.mouse_filter = Control.MOUSE_FILTER_PASS

		var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as Control
		if panel != null:
			panel.visible = true
			panel.mouse_filter = Control.MOUSE_FILTER_PASS

		call_deferred("_upgrade_force_btn_retour_front")
		_refresh_upgrade_works_ui(_upgrade_target_ng, _upgrade_target_ns, duration, duration)

# --- TICKETING INPUT FIX (front + restore) -----------------------------------
var _ticketing_prev_top_level: bool = false
var _ticketing_prev_z: int = 0
var _ticketing_prev_gp: Vector2 = Vector2.ZERO

func _ticketing_boost_front() -> void:
	# Force Billetterie au-dessus de tout (sans toucher Boutique ni le reste)
	if PanelTicketing == null:
		return
	_ticketing_prev_top_level = PanelTicketing.is_set_as_top_level()
	_ticketing_prev_z = PanelTicketing.z_index
	_ticketing_prev_gp = PanelTicketing.global_position

	PanelTicketing.mouse_filter = Control.MOUSE_FILTER_PASS
	PanelTicketing.z_index = (RenderingServer.CANVAS_ITEM_Z_MAX - 2)

	# Top-level pour éviter les overlays / CanvasLayers qui capturent l'input
	PanelTicketing.set_as_top_level(true)
	PanelTicketing.global_position = _ticketing_prev_gp

func _ticketing_restore_front() -> void:
	if PanelTicketing == null:
		return
	# Restore (Billetterie only)
	PanelTicketing.set_as_top_level(_ticketing_prev_top_level)
	PanelTicketing.z_index = _ticketing_prev_z
	if _ticketing_prev_gp != Vector2.ZERO:
		PanelTicketing.global_position = _ticketing_prev_gp

func _ticketing_debug_hover() -> void:
	# Debug minimal: quel Control est sous la souris quand tu cliques ?
	var h := get_viewport().gui_get_hovered_control()
	if h != null:
		print("[TICKETING][HOVER] ", h.name, " path=", h.get_path(), " mouse_filter=", (h as Control).mouse_filter if h is Control else "n/a")
	else:
		print("[TICKETING][HOVER] none")
# ---------------------------------------------------------------------------

func _on_tab_ticketing() -> void:
	_ensure_ticketing_screen_bg()
	if TicketingScreenBG != null:
		TicketingScreenBG.visible = true

	# ✅ FIX Billetterie: CenterShop (plein écran) peut capter l'input même si PanelShop est caché
	var _cs := get_node_or_null("Content/CenterShop") as Control
	if _cs != null:
		_cs.visible = false
		_cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shop_screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
	if shop_screen_bg != null:
		shop_screen_bg.visible = false

	# ✅ Billetterie only: masquer la Boutique si elle est ouverte (sinon PanelShop capte les clics)
	var _pshop := get_node_or_null("Content/CenterShop/PanelShop")
	if _pshop != null and _pshop is CanvasItem:
		(_pshop as CanvasItem).visible = false

	var _pup := get_node_or_null("Content/CenterUpgrade/PanelUpgrade")
	if _pup != null and _pup is CanvasItem:
		(_pup as CanvasItem).visible = false
	if PanelTicketing != null:
		PanelTicketing.visible = true

		# BM_LIMITS_TOOLTIP_INLINE_TICKETING_V2
		var hdr_cat := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrCat") as Label
		if hdr_cat != null:
			hdr_cat.mouse_filter = Control.MOUSE_FILTER_STOP
			if not hdr_cat.mouse_entered.is_connected(func(): pass):
				hdr_cat.mouse_entered.connect(func():
					_bm_show_limits_tooltip(_stadium_tr("stadium.ticketing.tooltip.category"))
					if _bm_limits_tip != null and is_instance_valid(_bm_limits_tip):
						var cat_tip_pos := _bm_limits_tip.global_position
						cat_tip_pos.x = max(24.0, cat_tip_pos.x + 320.0)
						_bm_limits_tip.global_position = cat_tip_pos
				)
				hdr_cat.mouse_exited.connect(_bm_hide_limits_tooltip)
		var hdr_price := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrPrice") as Label
		if hdr_price != null:
			hdr_price.mouse_filter = Control.MOUSE_FILTER_STOP
			if not hdr_price.mouse_entered.is_connected(func(): pass):
				hdr_price.mouse_entered.connect(func(): _bm_show_limits_tooltip(_stadium_tr("stadium.ticketing.tooltip.price")))
				hdr_price.mouse_exited.connect(_bm_hide_limits_tooltip)
		var hdr_seats := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrSeats") as Label
		if hdr_seats != null:
			hdr_seats.text = _stadium_tr("stadium.ticketing.col.seats")
			hdr_seats.mouse_filter = Control.MOUSE_FILTER_STOP

			# Tooltip propre
			if not hdr_seats.mouse_entered.is_connected(func(): pass):
				hdr_seats.mouse_entered.connect(func(): _bm_show_limits_tooltip(_stadium_tr("stadium.ticketing.tooltip.seats")))
				hdr_seats.mouse_exited.connect(_bm_hide_limits_tooltip)
		PanelTicketing.z_index = 20
		# Rebind + force clickable (Billetterie only)
		_stadium_bind_ticketing_inputs()
		_ticketing_force_controls_clickable()
		if BtnCloseShop != null:
			BtnCloseShop.visible = false
		# ✅ Billetterie only: le bouton Confirmer Boutique est top_level/z_index=(CANVAS_ITEM_Z_MAX - 1) -> il peut capter les clics.
		var _btn_shop := find_child("BtnConfirmShop", true, false) as Button
		if _btn_shop != null:
			_btn_shop.visible = false
			_btn_shop.disabled = true
			_btn_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ensure_ticketing_close_button()
		_ensure_capacity_label()
		_stadium_fix_popularity_badges_visual()
		_stadium_apply_ticketing_limits(_stadium_current_capacity_value())
		_stadium_set_active_panel(PanelTicketing)
		_stadium_make_panel_full_screen(PanelTicketing)
		_ensure_ticketing_confirm_button()
		_ticketing_place_back_button()
		call_deferred("_ticketing_place_close_button")
		call_deferred("_ticketing_place_confirm_button")
		_update_ticketing_total()


func _ensure_upgrade_panel() -> void:
	var content := get_node_or_null("Content")
	if content == null:
		return

	var center := get_node_or_null("Content/CenterUpgrade")
	if center == null:
		center = CenterContainer.new()
		center.name = "CenterUpgrade"
		content.add_child(center)
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.offset_left = 0
		center.offset_top = 0
		center.offset_right = 0
		center.offset_bottom = 0

	var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade")
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "PanelUpgrade"
		center.add_child(panel)
		
		var sb_panel := StyleBoxFlat.new()
		sb_panel.bg_color = Color(0, 0, 0, 0)
		sb_panel.border_width_left = 0
		sb_panel.border_width_right = 0
		sb_panel.border_width_top = 0
		sb_panel.border_width_bottom = 0
		panel.add_theme_stylebox_override("panel", sb_panel)

	if panel is Control:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(panel as Control).offset_left = 0
		(panel as Control).offset_top = 0
		(panel as Control).offset_right = 0
		(panel as Control).offset_bottom = 0

	var has_bg := panel.get_node_or_null("UpgradeBG") != null
	if not has_bg:
		for c in panel.get_children():
			(c as Node).queue_free()

		var bg := TextureRect.new()
		bg.name = "UpgradeBG"
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0
		bg.offset_top = 0
		bg.offset_right = 0
		bg.offset_bottom = 0
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := load(UPGRADE_BG_PATH)
		if tex != null:
			bg.texture = tex
		panel.add_child(bg)

		var shop_frame := PanelContainer.new()
		shop_frame.name = "ShopOverlayFrame"
		shop_frame.visible = false
		shop_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		shop_frame.offset_left = 40
		shop_frame.offset_top = 20
		shop_frame.offset_right = -40
		shop_frame.offset_bottom = -20
		shop_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var sb_shop := StyleBoxFlat.new()
		sb_shop.bg_color = Color(1,1,1,0.25)
		sb_shop.border_width_left = 2
		sb_shop.border_width_right = 2
		sb_shop.border_width_top = 2
		sb_shop.border_width_bottom = 2
		sb_shop.border_color = Color(0.1,0.1,0.1,0.35)
		sb_shop.corner_radius_top_left = 10
		sb_shop.corner_radius_top_right = 10
		sb_shop.corner_radius_bottom_left = 10
		sb_shop.corner_radius_bottom_right = 10
		shop_frame.add_theme_stylebox_override("panel", sb_shop)

		panel.add_child(shop_frame)

		var upgrade_overlay := Control.new()
		upgrade_overlay.name = "UpgradeOverlay"
		panel.add_child(upgrade_overlay)
		upgrade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		upgrade_overlay.offset_left = 0
		upgrade_overlay.offset_top = 0
		upgrade_overlay.offset_right = 0
		upgrade_overlay.offset_bottom = 0
		upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var btn_close := Button.new()
		btn_close.name = "BtnCloseUpgrade"
		btn_close.text = "✕"
		btn_close.custom_minimum_size = Vector2(46, 46)
		btn_close.size = Vector2(46, 46)
		btn_close.anchor_left = 1.0
		btn_close.anchor_top = 0.0
		btn_close.anchor_right = 1.0
		btn_close.anchor_bottom = 0.0
		btn_close.offset_left = -66
		btn_close.offset_top = 18
		btn_close.offset_right = -20
		btn_close.offset_bottom = 64
		btn_close.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_close.z_index = 50

		var sb_close := StyleBoxFlat.new()
		sb_close.bg_color = Color(0.82, 0.18, 0.18, 0.96)
		sb_close.corner_radius_top_left = 10
		sb_close.corner_radius_top_right = 10
		sb_close.corner_radius_bottom_left = 10
		sb_close.corner_radius_bottom_right = 10
		sb_close.border_width_left = 2
		sb_close.border_width_right = 2
		sb_close.border_width_top = 2
		sb_close.border_width_bottom = 2
		sb_close.border_color = Color(0.55, 0.08, 0.08, 1.0)

		var sb_close_hover := sb_close.duplicate() as StyleBoxFlat
		sb_close_hover.bg_color = Color(0.90, 0.24, 0.24, 1.0)

		var sb_close_pressed := sb_close.duplicate() as StyleBoxFlat
		sb_close_pressed.bg_color = Color(0.68, 0.12, 0.12, 1.0)

		btn_close.add_theme_stylebox_override("normal", sb_close)
		btn_close.add_theme_stylebox_override("hover", sb_close_hover)
		btn_close.add_theme_stylebox_override("pressed", sb_close_pressed)
		btn_close.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_close.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn_close.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn_close.add_theme_font_size_override("font_size", 22)
		upgrade_overlay.add_child(btn_close)

		if not btn_close.pressed.is_connected(_on_close_upgrade_pressed):
			btn_close.pressed.connect(_on_close_upgrade_pressed)

		var root := VBoxContainer.new()
		root.name = "VBoxUpgrade"
		root.scale = Vector2(1, 1)
		root.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(root)
		root.set_anchors_preset(Control.PRESET_FULL_RECT)

		# IMPORTANT: l'overlay de fermeture doit rester devant le contenu interactif
		panel.move_child(upgrade_overlay, panel.get_child_count() - 1)
		root.offset_left = 80
		root.offset_top = 70
		root.offset_right = -80
		root.offset_bottom = -70
		root.add_theme_constant_override("separation", 16)

		var frame := PanelContainer.new()
		frame.name = "UpgradeInfoFrame"
		frame.custom_minimum_size = Vector2(960, 680)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var target_title_label := Label.new()
		target_title_label.name = "LblUpgradeTargetTitle"
		target_title_label.custom_minimum_size = Vector2(0, 0)
		target_title_label.visible = false
		target_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		target_title_label.add_theme_font_size_override("font_size", 48)
		target_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		target_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.18, 0.85))
		target_title_label.add_theme_constant_override("outline_size", 2)
		var frame_box := VBoxContainer.new()
		frame_box.name = "UpgradeInfoBox"
		frame_box.alignment = BoxContainer.ALIGNMENT_CENTER
		frame_box.add_theme_constant_override("separation", 18)

		root.add_child(frame)
		frame.add_child(frame_box)
		frame_box.add_child(target_title_label)
		_apply_upgrade_readability_panel_style(frame)

		var next_image := TextureRect.new()
		next_image.name = "UpgradeNextImage"
		next_image.custom_minimum_size = UPGRADE_NEXT_IMAGE_SIZE
		next_image.size = UPGRADE_NEXT_IMAGE_SIZE
		next_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		next_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		next_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		next_image.visible = false
		frame_box.add_child(next_image)

		var info := RichTextLabel.new()
		info.name = "LblUpgradeInfo"
		info.fit_content = true
		info.scroll_active = false
		info.bbcode_enabled = false
		info.add_theme_font_size_override("normal_font_size", 31)
		info.add_theme_color_override("default_color", Color(0, 0, 0, 1))
		info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		info.add_theme_constant_override("outline_size", 0)
		info.modulate = Color(1,1,1,1)
		frame_box.add_child(info)

		var btn := Button.new()
		btn.name = "BtnConfirmUpgradePanel"
		btn.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 26)
		frame_box.add_child(btn)

		var sb_n := StyleBoxFlat.new()
		sb_n.bg_color = Color(0.12, 0.70, 0.25, 1.0)
		sb_n.corner_radius_top_left = 10
		sb_n.corner_radius_top_right = 10
		sb_n.corner_radius_bottom_left = 10
		sb_n.corner_radius_bottom_right = 10
		sb_n.content_margin_left = 18
		sb_n.content_margin_right = 18
		sb_n.content_margin_top = 10
		sb_n.content_margin_bottom = 10
		sb_n.border_width_left = 2
		sb_n.border_width_right = 2
		sb_n.border_width_top = 2
		sb_n.border_width_bottom = 2
		sb_n.border_color = Color(0.08, 0.55, 0.18, 1.0)
		sb_n.shadow_size = 6
		sb_n.shadow_offset = Vector2(0, 4)
		sb_n.shadow_color = Color(0, 0, 0, 0.35)

		var sb_h := sb_n.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(0.16, 0.80, 0.30, 1.0)

		var sb_p := sb_n.duplicate() as StyleBoxFlat
		sb_p.bg_color = Color(0.10, 0.60, 0.20, 1.0)
		sb_p.shadow_size = 2
		sb_p.shadow_offset = Vector2(0, 1)

		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.add_theme_color_override("font_color", Color(1,1,1,1))
		btn.add_theme_color_override("font_hover_color", Color(1,1,1,1))
		btn.add_theme_color_override("font_pressed_color", Color(1,1,1,1))
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		btn.add_theme_color_override("font_hover_outline_color", Color(0, 0, 0, 0.85))
		btn.add_theme_color_override("font_pressed_outline_color", Color(0, 0, 0, 0.85))
		btn.add_theme_constant_override("outline_size", 2)

		if not btn.pressed.is_connected(_on_upgrade_confirmed):
			btn.pressed.connect(_on_upgrade_confirmed)

	var btn_confirm_scene := _get_upgrade_confirm_button(panel)
	if btn_confirm_scene != null:
		_apply_upgrade_confirm_button_style(btn_confirm_scene)
		if not btn_confirm_scene.pressed.is_connected(_on_upgrade_confirmed):
			btn_confirm_scene.pressed.connect(_on_upgrade_confirmed)

	var btn_cancel_scene := _get_upgrade_cancel_button(panel)
	if btn_cancel_scene != null:
		btn_cancel_scene.text = "Cancel"
		_apply_upgrade_cancel_button_style(btn_cancel_scene)
		if not btn_cancel_scene.pressed.is_connected(_on_close_upgrade_pressed):
			btn_cancel_scene.pressed.connect(_on_close_upgrade_pressed)

	var btn_close_scene := panel.get_node_or_null("UpgradeOverlay/BtnCloseUpgrade") as Button
	if btn_close_scene != null:
		if not btn_close_scene.pressed.is_connected(_on_close_upgrade_pressed):
			btn_close_scene.pressed.connect(_on_close_upgrade_pressed)

	if panel is CanvasItem:
		(panel as CanvasItem).visible = false


func _on_close_upgrade_pressed() -> void:
	var panel := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as CanvasItem
	if panel != null:
		panel.visible = false

	var center_up := get_node_or_null("Content/CenterUpgrade") as Control
	if center_up != null:
		center_up.visible = false
		center_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var upgrade_target_title := get_node_or_null("Content/CenterUpgrade/PanelUpgrade/VBoxUpgrade/UpgradeInfoFrame/UpgradeInfoBox/LblUpgradeTargetTitle") as Label
	if upgrade_target_title != null:
		upgrade_target_title.visible = false
		upgrade_target_title.set_as_top_level(false)
	if LblCapacity != null:
		LblCapacity.visible = true
	if LblStadiumLevel != null:
		LblStadiumLevel.visible = true
	call_deferred("_ensure_capacity_label")

	if BtnRetour != null:
		BtnRetour.visible = true
		BtnRetour.disabled = false
		BtnRetour.set_as_top_level(true)
		BtnRetour.global_position = Vector2(34.0, get_viewport_rect().size.y - 92.0)
		BtnRetour.size = Vector2(206.0, 62.0)
		BtnRetour.z_index = 20000
		BtnRetour.mouse_filter = Control.MOUSE_FILTER_STOP



func _bm_stadium_mobile_apply_shop_visual_sizes_v1() -> void:
	if not _bm_stadium_is_mobile_layout():
		return

	if LblCapacity != null:
		LblCapacity.add_theme_font_size_override("font_size", 34)
	if LblStadiumLevel != null:
		LblStadiumLevel.add_theme_font_size_override("font_size", 32)

	var panel := get_node_or_null("Content/CenterShop/PanelShop") as Node
	if panel == null:
		return

	# Titre Shop
	var shop_title := panel.get_node_or_null("VBox/LblShopTitle") as Label
	if shop_title != null:
		shop_title.add_theme_font_size_override("font_size", 34)

	# Headers : cible récursive, pas dépendante d'un chemin fragile
	for hdr_name in ["HdrShopLeft", "HdrShopRight"]:
		var hdr := panel.find_child(hdr_name, true, false)
		if hdr != null:
			for child in hdr.get_children():
				if child is Label:
					(child as Label).add_theme_font_size_override("font_size", 34)

	# Contenu : cible par noms réels dans tout PanelShop
	var stack: Array = [panel]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)

			if c is TextureRect and String(c.name).begins_with("Icon_"):
				var icon := c as TextureRect
				if true:
					icon.set_meta("bm_mobile_shop_icon_plus20_done", true)
					icon.custom_minimum_size = Vector2(152, 132) if icon.name == "Icon_tshirt" else Vector2(152, 110)
					icon.size = icon.custom_minimum_size
					if icon.name == "Icon_tshirt":
						icon.pivot_offset = icon.size * 0.5
						icon.scale = Vector2(1.35, 1.35)

			elif c is Label:
				var lbl := c as Label
				if lbl.name == "LblStock":
					lbl.custom_minimum_size.x = 130
					lbl.add_theme_font_size_override("font_size", 41)
				elif lbl.name == "LblLastSales":
					lbl.custom_minimum_size.x = 230
					lbl.add_theme_font_size_override("font_size", 35)
				elif lbl.name == "LblEstimatedRevenue":
					lbl.custom_minimum_size.x = 230
					lbl.add_theme_font_size_override("font_size", 41)

			elif c is LineEdit and String(c.name).begins_with("Price_"):
				var le := c as LineEdit
				le.custom_minimum_size = Vector2(56, 56)
				le.size = Vector2(56, 56)
				le.min_size_changed()
				le.add_theme_font_size_override("font_size", 40)

			elif c is Button:
				var b := c as Button
				if b.text == "+" or b.text == "-":
					b.custom_minimum_size = Vector2(56, 56)
					b.size = b.custom_minimum_size
					b.add_theme_font_size_override("font_size", 48)


func _ensure_shop_panel() -> void:

	# Crée le panel Boutique si le .tscn ne l’a pas encore
	var content := get_node_or_null("Content")
	if content == null:
		return

	_shop_level_cached = _get_shop_level_from_save(save)

	var center := get_node_or_null("Content/CenterShop")
	if center == null:
		center = CenterContainer.new()
		center.name = "CenterShop"
		content.add_child(center)
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.offset_left = 0
		center.offset_top = 0
		center.offset_right = 0
		center.offset_bottom = 0

	var screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
	if screen_bg == null:
		screen_bg = TextureRect.new()
		screen_bg.name = "ShopScreenBG"
		screen_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		screen_bg.stretch_mode = TextureRect.STRETCH_SCALE
		screen_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen_bg.offset_left = 0
		screen_bg.offset_top = 0
		screen_bg.offset_right = 0
		screen_bg.offset_bottom = 0
		screen_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(screen_bg)
		move_child(screen_bg, 0)

	var center_tex := load(SHOP_BG_PATH)
	if center_tex != null:
		screen_bg.texture = center_tex

	var panel := get_node_or_null("Content/CenterShop/PanelShop")
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "PanelShop"
		center.add_child(panel)

	# ✅ UPGRADE: si le panel existe déjà mais contient l’ancien placeholder,
	# on reconstruit l’UI si ShopBG n’existe pas.
	var has_bg := panel.get_node_or_null("ShopBG") != null
	if not has_bg:
		# vider enfants (placeholder) avant rebuild
		for c in panel.get_children():
			(c as Node).queue_free()

		# Fond Boutique
		var bg := TextureRect.new()
		bg.name = "ShopBG"
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0
		bg.offset_top = 0
		bg.offset_right = 0
		bg.offset_bottom = 0
		var tex := load(SHOP_BG_PATH)
		if tex == null:
			print("[STADIUM][SHOP] ERROR: cannot load texture -> ", SHOP_BG_PATH)
		else:
			bg.texture = tex
		bg.visible = false
		panel.add_child(bg)

		# Contenu (au-dessus du fond)
		var root := VBoxContainer.new()
		root.name = "VBox"
		root.scale = Vector2(1.25, 1.25)
		panel.add_child(root)
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.offset_left = 60
		root.offset_top = 30
		root.offset_right = -60
		root.offset_bottom = -30

		var title := Label.new()
		title.name = "LblShopTitle"
		title.text = _stadium_tr("stadium.tab.shop")
		root.add_child(title)
		title.modulate = Color(0,0,0,1)
		title.add_theme_font_size_override("font_size", 30)
		title.custom_minimum_size.y = 116

		# Header

		# Header + tableau unique (visuel façon Selection)
		var grids_margin := MarginContainer.new()
		grids_margin.name = "ShopColumnsMargin"
		grids_margin.add_theme_constant_override("margin_left", 238)
		root.add_child(grids_margin)

		var grids_wrap := VBoxContainer.new()
		grids_wrap.name = "ShopColumns"
		grids_wrap.add_theme_constant_override("separation", 0)
		grids_margin.add_child(grids_wrap)

		var col_left := VBoxContainer.new()
		col_left.name = "ShopColLeft"
		col_left.add_theme_constant_override("separation", 10)
		grids_wrap.add_child(col_left)

		var col_right := VBoxContainer.new()
		col_right.name = "ShopColRight"
		col_right.add_theme_constant_override("separation", 10)
		grids_wrap.add_child(col_right)
		col_right.visible = false

		# Header (noir) bloc gauche
		var hdr_frame := PanelContainer.new()
		hdr_frame.name = "HdrShopFrame"
		var sb_shop_header := StyleBoxFlat.new()
		sb_shop_header.bg_color = Color(0.05, 0.07, 0.09, 0.78)
		sb_shop_header.border_width_bottom = 2
		sb_shop_header.border_color = Color(1, 1, 1, 0.22)
		sb_shop_header.corner_radius_top_left = 8
		sb_shop_header.corner_radius_top_right = 8
		sb_shop_header.corner_radius_bottom_left = 8
		sb_shop_header.corner_radius_bottom_right = 8
		sb_shop_header.content_margin_left = 12
		sb_shop_header.content_margin_right = 12
		sb_shop_header.content_margin_top = 8
		sb_shop_header.content_margin_bottom = 8
		hdr_frame.add_theme_stylebox_override("panel", sb_shop_header)
		col_left.add_child(hdr_frame)

		var hdr_left := HBoxContainer.new()
		hdr_left.name = "HdrShopLeft"
		hdr_left.add_theme_constant_override("separation", 14)
		hdr_frame.add_child(hdr_left)

		var h1l := Label.new(); h1l.text = "PRODUIT"; h1l.custom_minimum_size.x = 126; h1l.modulate = Color(1,1,1,1)
		h1l.add_theme_font_size_override("font_size", 22)
		var h2l := Label.new(); h2l.text = "STOCK";	  h2l.custom_minimum_size.x = 110; h2l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h2l.modulate = Color(1,1,1,1)
		h2l.add_theme_font_size_override("font_size", 22)
		# BM_SHOP_STOCK_TOOLTIP_SIMPLE_V1
		h2l.mouse_filter = Control.MOUSE_FILTER_STOP
		h2l.mouse_entered.connect(Callable(self, "_on_shop_stock_hover_entered"))
		h2l.mouse_exited.connect(_bm_hide_limits_tooltip)
		# BM_SHOP_STOCK_TOOLTIP_ON_LABEL_V1
		h2l.mouse_filter = Control.MOUSE_FILTER_STOP
		h2l.mouse_exited.connect(_bm_hide_limits_tooltip)
		var h3l := Label.new(); h3l.text = _stadium_tr("stadium.shop.col.price").to_upper();	  h3l.custom_minimum_size.x = 240; h3l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h3l.modulate = Color(1,1,1,1)
		h3l.add_theme_font_size_override("font_size", 22)
		# BM_SHOP_PRICE_TOOLTIP_SIMPLE_V1
		h3l.mouse_filter = Control.MOUSE_FILTER_STOP
		h3l.mouse_entered.connect(Callable(self, "_on_shop_price_hover_entered"))
		h3l.mouse_exited.connect(_bm_hide_limits_tooltip)
		# BM_SHOP_PRICE_TOOLTIP_ON_LABEL_V1
		h3l.mouse_filter = Control.MOUSE_FILTER_STOP
		h3l.mouse_exited.connect(_bm_hide_limits_tooltip)

		var h4l := Label.new(); h4l.text = _stadium_tr("stadium.shop.col.last_sales"); h4l.custom_minimum_size.x = 190; h4l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h4l.modulate = Color(1,1,1,1)
		h4l.add_theme_font_size_override("font_size", 22)
		var h5l := Label.new(); h5l.text = _stadium_tr("stadium.shop.col.estimated_revenue"); h5l.custom_minimum_size.x = 190; h5l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h5l.modulate = Color(1,1,1,1)
		h5l.add_theme_font_size_override("font_size", 22)
		var restock_unlocked_now := _shop_restock_unlocked_now()
		var h6l := Label.new(); h6l.name = "HdrShopRestock"; h6l.text = _stadium_tr("stadium.shop.col.restock"); h6l.custom_minimum_size.x = 180; h6l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h6l.modulate = Color(1,1,1,1)
		h6l.visible = restock_unlocked_now
		h6l.add_theme_font_size_override("font_size", 22)
		for h in [h1l, h2l, h3l, h4l, h5l, h6l]:
			h.add_theme_color_override("font_color", Color(1,1,1,1))
			h.add_theme_color_override("font_outline_color", Color(0,0,0,0.55))
			h.add_theme_constant_override("outline_size", 1)
		hdr_left.add_child(h1l)
		hdr_left.add_child(h2l)
		hdr_left.add_child(h4l)
		hdr_left.add_child(h3l)
		hdr_left.add_child(h5l)
		hdr_left.add_child(h6l)
		# Header (noir) bloc droit
		var hdr_right := HBoxContainer.new()
		hdr_right.name = "HdrShopRight"
		hdr_right.add_theme_constant_override("separation", 18)
		col_right.add_child(hdr_right)
		
		var h1r := Label.new(); h1r.text = "Produit
		────────"; h1r.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h1r.modulate = Color(0,0,0,1)
		h1r.add_theme_font_size_override("font_size", 22)
		var h2r := Label.new(); h2r.text = "Stock
		─────";	  h2r.custom_minimum_size.x = 90;			  h2r.modulate = Color(0,0,0,1)
		h2r.add_theme_font_size_override("font_size", 22)
		var h3r := Label.new(); h3r.text = _stadium_tr("stadium.shop.col.price") + "
		────";	  h3r.custom_minimum_size.x = 220;			  h3r.modulate = Color(0,0,0,1)
		h3r.add_theme_font_size_override("font_size", 22)
		hdr_right.add_child(h1r); hdr_right.add_child(h2r); hdr_right.add_child(h3r)
		
		# Grilles
		var grid_left := VBoxContainer.new()
		grid_left.name = "GridShopLeft"
		grid_left.add_theme_constant_override("separation", 0)
		col_left.add_child(grid_left)
		
		var grid_right := VBoxContainer.new()
		grid_right.name = "GridShopRight"
		grid_right.add_theme_constant_override("separation", 10)
		col_right.add_child(grid_right)
		
		_shop_price_by_id.clear()
		_shop_price_le_by_id.clear()
		_shop_row_by_id.clear()

		# init prix par défaut
		for row in SHOP_PRODUCTS:
			var pid := str(row["id"])
			_shop_price_by_id[pid] = int(SHOP_DEFAULT_PRICES.get(pid, 0))

		# appliquer prix sauvegardés si dispo
		if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
			_apply_shop_from_save(save["shop"])

		var active_rows := _get_shop_active_rows_for_level(_shop_level_cached) # 4

		# Construire les 7 lignes : 0..3 à gauche (actives), 4..6 à droite (grisées)
		for i in range(SHOP_PRODUCTS.size()):
			var row: Dictionary = SHOP_PRODUCTS[i] as Dictionary
			var pid2 := str(row["id"])
			var label_txt := str(row["label"])
			var stock := _get_shop_stock_for_level(_shop_level_cached, pid2)

			var line := HBoxContainer.new()
			line.name = "Row_" + pid2
			line.add_theme_constant_override("separation", 14)
			line.custom_minimum_size = Vector2(0, 100)

			# Choix actif/grisé conservé, affichage dans un seul tableau
			var is_left := i < active_rows
			grid_left.add_child(line)

			_shop_row_by_id[pid2] = line

			# Produit = icône
			var icon := TextureRect.new()
			icon.name = "Icon_" + pid2
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(126, 80)
			# Overrides tailles icônes
			if pid2 == "tshirt":
				icon.custom_minimum_size = Vector2(126, 121) # colonne produit fixe
				icon.pivot_offset = icon.custom_minimum_size * 0.5
				icon.scale = Vector2(1.35, 1.35)
			elif pid2 == "casquette" or pid2 == "drapeau":
				icon.custom_minimum_size = Vector2(126, 84)	 # colonne produit fixe
			elif pid2 == "ballon":
				icon.custom_minimum_size = Vector2(126, 72)	 # colonne produit fixe
			var itex := load("res://assets/images/boutique/" + pid2 + ".png")
			if itex != null:
				icon.texture = itex
			else:
				print("[STADIUM][SHOP] WARN: missing icon -> ", pid2)
			line.add_child(icon)
			var col_shift := Control.new()
			col_shift.name = "ColShift_" + pid2
			col_shift.custom_minimum_size = Vector2(0, 0)
			line.add_child(col_shift)
			# Stock
			var lbls := Label.new()
			lbls.name = "LblStock"
			lbls.text = str(stock)
			lbls.custom_minimum_size.x = 110
			lbls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbls.modulate = Color(0,0,0,1)
			lbls.add_theme_font_size_override("font_size", 25)
			line.add_child(lbls)

			# Prix +/- + champ
			var price_box := HBoxContainer.new()
			price_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			price_box.alignment = BoxContainer.ALIGNMENT_CENTER
			price_box.add_theme_constant_override("separation", 4)
			price_box.custom_minimum_size.x = 240

			var lbl_last_sales := Label.new()
			lbl_last_sales.name = "LblLastSales"
			var last_sales_coef := 0.0
			var last_sales := 0
			if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
				var shop_last_sales: Dictionary = save["shop"] as Dictionary
				last_sales_coef = float(shop_last_sales.get("last_game_sales_coef", 0.0))
				if int(save.get("season_round", 0)) >= 13 and shop_last_sales.has("stock_state") and typeof(shop_last_sales["stock_state"]) == TYPE_DICTIONARY:
					var stock_state_last_sales: Dictionary = shop_last_sales["stock_state"] as Dictionary
					if stock_state_last_sales.has(pid2) and typeof(stock_state_last_sales[pid2]) == TYPE_DICTIONARY:
						last_sales = maxi(0, int((stock_state_last_sales[pid2] as Dictionary).get("last_sold", 0)))
			if last_sales <= 0:
				last_sales = int(round(float(stock) * last_sales_coef))
			lbl_last_sales.text = str(last_sales)
			lbl_last_sales.custom_minimum_size.x = 190
			lbl_last_sales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_last_sales.modulate = Color(0.18, 0.95, 0.28, 1) if last_sales < stock else Color(1, 0.18, 0.18, 1)
			lbl_last_sales.add_theme_font_size_override("font_size", 23)
			line.add_child(lbl_last_sales)
			line.add_child(price_box)

			var lbl_estimated_revenue := Label.new()
			lbl_estimated_revenue.name = "LblEstimatedRevenue"
			var _pop := 50
			if save.has("popularite"):
				_pop = int(save.get("popularite", 50))
			var _coef := float(clampi(_pop, 30, 100)) / 100.0
			var _price := int(_shop_price_by_id.get(pid2, 0))
			lbl_estimated_revenue.text = _format_int(int(round(float(stock * _price) * _coef))) + " €"
			lbl_estimated_revenue.custom_minimum_size.x = 190
			lbl_estimated_revenue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_estimated_revenue.modulate = Color(0,0,0,1)
			lbl_estimated_revenue.add_theme_font_size_override("font_size", 25)
			line.add_child(lbl_estimated_revenue)

			# BM_SHOP_RESTOCK_COLUMN_V1
			var btn_restock := Button.new()
			btn_restock.name = "BtnRestock_" + pid2
			btn_restock.text = "+"
			btn_restock.custom_minimum_size = Vector2(96, 46)
			btn_restock.add_theme_font_size_override("font_size", 24)

			var sb_restock := StyleBoxFlat.new()
			sb_restock.bg_color = Color(0.95, 0.50, 0.12, 1.0)
			sb_restock.corner_radius_top_left = 23
			sb_restock.corner_radius_top_right = 23
			sb_restock.corner_radius_bottom_left = 23
			sb_restock.corner_radius_bottom_right = 23
			btn_restock.add_theme_stylebox_override("normal", sb_restock)
			btn_restock.add_theme_stylebox_override("hover", sb_restock)
			btn_restock.add_theme_stylebox_override("pressed", sb_restock)
			btn_restock.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn_restock.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
			btn_restock.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
			btn_restock.disabled = not restock_unlocked_now
			btn_restock.visible = restock_unlocked_now
			btn_restock.mouse_filter = Control.MOUSE_FILTER_STOP
			# BM_RESTOCK_DIRECT_POPUP_V1
			# Le + ouvre immédiatement le popup produit, sans passer par Confirm.
			btn_restock.button_up.connect(func():
				print("[RESTOCK] CLICK + pid=", pid2)
				_show_shop_restock_popup(pid2)
			)

			# BM_SHOP_RESTOCK_PLUS_CENTER_V1
			# Centre le bouton + dans la colonne Réassortiment, alignée sur le header h6l.
			var restock_cell := CenterContainer.new()
			restock_cell.name = "CellRestock_" + pid2
			restock_cell.custom_minimum_size.x = 180
			restock_cell.visible = restock_unlocked_now
			restock_cell.add_child(btn_restock)
			line.add_child(restock_cell)

			var bmin := Button.new()
			bmin.text = "-"

			bmin.add_theme_color_override("font_color", Color(0,0,0,1))
			bmin.add_theme_color_override("font_hover_color", Color(0,0,0,1))
			bmin.add_theme_color_override("font_pressed_color", Color(0,0,0,1))
			bmin.add_theme_color_override("font_disabled_color", Color(0,0,0,1))
			bmin.custom_minimum_size = Vector2(56, 56) if _bm_stadium_is_mobile_layout() else Vector2(44, 44)
			bmin.add_theme_font_size_override("font_size", 36 if _bm_stadium_is_mobile_layout() else 24)
			price_box.add_child(bmin)
			bmin.add_theme_color_override("font_color", Color(0,0,0,1))
			bmin.add_theme_color_override("font_outline_color", Color(0,0,0,0.90))
			bmin.add_theme_color_override("font_hover_color", Color(0,0,0,1))
			bmin.add_theme_color_override("font_pressed_color", Color(0,0,0,1))
			bmin.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			var le := LineEdit.new()
			le.name = "Price_" + pid2
			le.editable = false
			le.custom_minimum_size = Vector2(56, 56) if _bm_stadium_is_mobile_layout() else Vector2(44, 44)
			le.size = le.custom_minimum_size
			le.add_theme_font_size_override("font_size", 36 if _bm_stadium_is_mobile_layout() else 24)
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER

			le.add_theme_color_override("font_color", Color(0,0,0,1))
			le.add_theme_color_override("font_uneditable_color", Color(0,0,0,1))
			le.add_theme_color_override("font_readonly_color", Color(0,0,0,1))
			le.add_theme_color_override("font_readonly_color", Color(0,0,0,1))
			le.add_theme_color_override("font_placeholder_color", Color(0,0,0,1))
			le.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Fond du champ = même style que le bouton "-" (gris foncé du thème)
			var sb_any: StyleBox = bmin.get_theme_stylebox("normal")
			if sb_any != null:
				var sb_copy: StyleBox = sb_any.duplicate(true) as StyleBox
				le.add_theme_stylebox_override("normal", sb_copy)
				le.add_theme_stylebox_override("read_only", sb_copy)
			le.add_theme_color_override("font_color", Color(0, 0, 0, 1))

			le.text = str(int(_shop_price_by_id.get(pid2, 0)))
			price_box.add_child(le)
			le.add_theme_color_override("font_color", Color(0,0,0,1))
			le.add_theme_color_override("font_outline_color", Color(0,0,0,0.90))
			le.add_theme_color_override("font_readonly_color", Color(1,1,1,1))
			le.add_theme_color_override("caret_color", Color(1,1,1,1))
			le.add_theme_color_override("selection_color", Color(1,1,1,0.35))
			_shop_price_le_by_id[pid2] = le

			var bplus := Button.new()
			bplus.text = "+"

			bplus.add_theme_color_override("font_color", Color(0,0,0,1))
			bplus.add_theme_color_override("font_hover_color", Color(0,0,0,1))
			bplus.add_theme_color_override("font_pressed_color", Color(0,0,0,1))
			bplus.add_theme_color_override("font_disabled_color", Color(0,0,0,1))
			bplus.custom_minimum_size = Vector2(56, 56) if _bm_stadium_is_mobile_layout() else Vector2(44, 44)
			bplus.add_theme_font_size_override("font_size", 36 if _bm_stadium_is_mobile_layout() else 24)
			price_box.add_child(bplus)
			# --- PRICE MINI-BLOCK: white background + black content (ultra lisible) ---
			var sbw := StyleBoxFlat.new()
			sbw.bg_color = Color(1, 1, 1, 1)			# blanc opaque
			sbw.border_width_left = 2
			sbw.border_width_right = 2
			sbw.border_width_top = 2
			sbw.border_width_bottom = 2
			sbw.border_color = Color(0.15, 0.15, 0.15, 1)  # bordure gris foncé
			sbw.corner_radius_top_left = 6
			sbw.corner_radius_top_right = 6
			sbw.corner_radius_bottom_left = 6
			sbw.corner_radius_bottom_right = 6
			sbw.content_margin_left = 6
			sbw.content_margin_right = 6
			sbw.content_margin_top = 2
			sbw.content_margin_bottom = 2

			# Boutons - / +
			bmin.add_theme_stylebox_override("normal", sbw)
			bmin.add_theme_stylebox_override("hover", sbw)
			bmin.add_theme_stylebox_override("pressed", sbw)
			bmin.add_theme_color_override("font_color", Color(0,0,0,1))

			bplus.add_theme_stylebox_override("normal", sbw)
			bplus.add_theme_stylebox_override("hover", sbw)
			bplus.add_theme_stylebox_override("pressed", sbw)
			bplus.add_theme_color_override("font_color", Color(0,0,0,1))

			# Champ prix
			le.add_theme_stylebox_override("normal", sbw)
			le.add_theme_stylebox_override("read_only", sbw)
			le.add_theme_color_override("font_color", Color(0,0,0,1))

			bplus.add_theme_color_override("font_color", Color(0,0,0,1))
			bplus.add_theme_color_override("font_outline_color", Color(0,0,0,0.90))
			bplus.add_theme_color_override("font_hover_color", Color(0,0,0,1))
			bplus.add_theme_color_override("font_pressed_color", Color(0,0,0,1))
			bplus.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			# Connexions (même si grisé, boutons seront disabled)
			bmin.pressed.connect(func(): _shop_price_step(pid2, -1))
			bplus.pressed.connect(func(): _shop_price_step(pid2, +1))

			# Droite = toujours grisé/désactivé
			if not is_left:
				line.modulate = SHOP_LOCKED_MODULATE
				line.visible = false
				bmin.disabled = true
				bplus.disabled = true
				le.editable = false
		# Wrap Total to tweak vertical Y without breaking VBox layout
		var total_wrap := MarginContainer.new()
		total_wrap.name = "WrapShopTotal"
		# monte le Total (ajuste -6/-10 selon ton goût)
		total_wrap.add_theme_constant_override("margin_top", -1740)
		total_wrap.add_theme_constant_override("margin_left", 980)
		root.add_child(total_wrap)

		_shop_total_label = Label.new()
		_shop_total_label.name = "LblShopTotal"
		total_wrap.add_child(_shop_total_label)
		_shop_total_label.modulate = Color(0,0,0,1)
		_shop_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_total_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shop_total_label.custom_minimum_size.x = 0
		_shop_total_label.modulate = Color(0,0,0,1)
		_shop_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shop_total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shop_total_label.add_theme_font_size_override("font_size", 28) # +100% (base ~22)
		# Cadre autour du Total
		var sb_total := StyleBoxFlat.new()
		sb_total.bg_color = Color(1, 1, 1, 0.0)
		sb_total.border_width_left = 2
		sb_total.border_width_right = 2
		sb_total.border_width_top = 2
		sb_total.border_width_bottom = 2
		sb_total.border_color = Color(0, 0, 0, 1)
		sb_total.corner_radius_top_left = 8
		sb_total.corner_radius_top_right = 8
		sb_total.corner_radius_bottom_left = 8
		sb_total.corner_radius_bottom_right = 8
		sb_total.content_margin_left = 14
		sb_total.content_margin_right = 14
		sb_total.content_margin_top = 8
		sb_total.content_margin_bottom = 8
		_shop_total_label.add_theme_stylebox_override("normal", sb_total)

		# Total frame (shrink-wrap) : encadré à la largeur du texte
		var total_frame := PanelContainer.new()
		total_frame.name = "TotalFrame"
		total_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		total_wrap.add_child(total_frame)
		# style encadré léger
		var sb_tf := StyleBoxFlat.new()
		sb_tf.bg_color = Color(1, 1, 1, 0.0)
		sb_tf.border_width_left = 2
		sb_tf.border_width_right = 2
		sb_tf.border_width_top = 2
		sb_tf.border_width_bottom = 2
		sb_tf.border_color = Color(0,0,0,0.35)
		sb_tf.corner_radius_top_left = 10
		sb_tf.corner_radius_top_right = 10
		sb_tf.corner_radius_bottom_left = 10
		sb_tf.corner_radius_bottom_right = 10
		sb_tf.content_margin_left = 14
		sb_tf.content_margin_right = 14
		sb_tf.content_margin_top = 6
		sb_tf.content_margin_bottom = 6
		total_frame.add_theme_stylebox_override("panel", sb_tf)

		# déplacer le label Total dans l'encadré
		_shop_total_label.get_parent().remove_child(_shop_total_label)
		total_frame.add_child(_shop_total_label)
		_update_shop_total()

		var btn := Button.new()
		btn.name = "BtnConfirmShop"
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 22)
		btn.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
		btn.modulate = Color(1, 1, 1, 1)
		root.add_child(btn)
		# BM_SHOP_CONFIRM_CONNECT_RESTORE_V1
		if not btn.pressed.is_connected(_on_confirm_shop_pressed):
			btn.pressed.connect(_on_confirm_shop_pressed)

	var shop_scroll := VScrollBar.new()
	shop_scroll.name = "ShopVScroll"
	shop_scroll.visible = false
	panel.add_child(shop_scroll)


	var shop_frame_existing := panel.get_node_or_null("ShopOverlayFrame") as PanelContainer
	if shop_frame_existing == null:
		shop_frame_existing = PanelContainer.new()
		shop_frame_existing.name = "ShopOverlayFrame"
		shop_frame_existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		shop_frame_existing.offset_left = 40
		shop_frame_existing.offset_top = 20
		shop_frame_existing.offset_right = -40
		shop_frame_existing.offset_bottom = -20
		shop_frame_existing.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var shop_frame_tex := TextureRect.new()
		shop_frame_tex.name = "ShopOverlayImage"
		shop_frame_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shop_frame_tex.stretch_mode = TextureRect.STRETCH_SCALE
		shop_frame_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		shop_frame_tex.offset_left = 0
		shop_frame_tex.offset_top = 0
		shop_frame_tex.offset_right = 0
		shop_frame_tex.offset_bottom = 0
		shop_frame_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shop_frame_tex.modulate = Color(1, 1, 1, 1)
		var tex_shop_overlay := load(SHOP_BG_PATH)
		if tex_shop_overlay != null:
			shop_frame_tex.texture = tex_shop_overlay
		shop_frame_existing.add_child(shop_frame_tex)

		panel.add_child(shop_frame_existing)
		panel.move_child(shop_frame_existing, 1)

	# ✅ Apply scale + margins even if Shop UI already exists (no rebuild)
	var root_existing := panel.get_node_or_null("VBox") as Control
	if root_existing != null:
		root_existing.scale = Vector2(1.25, 1.25)
		root_existing.offset_left = 60
		root_existing.offset_right = -60
		var title_existing := root_existing.get_node_or_null("LblShopTitle") as Control
		if title_existing != null:
			title_existing.custom_minimum_size.y = 116
		var total_frame_existing := root_existing.find_child("TotalFrame", true, false) as Control
		if total_frame_existing != null:
			total_frame_existing.set_as_top_level(true)
			total_frame_existing.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 2
			var total_w := maxf(total_frame_existing.size.x, total_frame_existing.get_combined_minimum_size().x)
			if total_w <= 1.0:
				total_w = 300.0
			total_frame_existing.global_position = Vector2(get_viewport_rect().size.x - total_w - 34.0, 48.0)
		_shop_force_light_text(root_existing)
		_shop_apply_restock_visibility(root_existing)
		_bm_stadium_mobile_apply_shop_visual_sizes_v1()


	# --- SAFE: si l'UI Boutique existe déjà (has_bg==true), on s'assure que le bouton Confirmer existe ---
	var shop_root_existing := panel.get_node_or_null("VBox") as VBoxContainer
	if shop_root_existing != null:
		var btn_exist := shop_root_existing.get_node_or_null("BtnConfirmShop") as Button
		if btn_exist == null:
			btn_exist = Button.new()
			btn_exist.name = "BtnConfirmShop"
			btn_exist.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
			btn_exist.custom_minimum_size = Vector2(0, 46)
			# Style vert 3D (copie billetterie)
			var sb_n := StyleBoxFlat.new()
			sb_n.bg_color = Color(0.12, 0.70, 0.25, 1.0)
			sb_n.corner_radius_top_left = 10
			sb_n.corner_radius_top_right = 10
			sb_n.corner_radius_bottom_left = 10
			sb_n.corner_radius_bottom_right = 10
			sb_n.content_margin_left = 18
			sb_n.content_margin_right = 18
			sb_n.content_margin_top = 10
			sb_n.content_margin_bottom = 10
			sb_n.border_width_left = 2
			sb_n.border_width_right = 2
			sb_n.border_width_top = 2
			sb_n.border_width_bottom = 2
			sb_n.border_color = Color(0.08, 0.55, 0.18, 1.0)
			sb_n.shadow_size = 6
			sb_n.shadow_offset = Vector2(0, 4)
			sb_n.shadow_color = Color(0, 0, 0, 0.35)

			var sb_h := sb_n.duplicate() as StyleBoxFlat
			sb_h.bg_color = Color(0.16, 0.80, 0.30, 1.0)

			var sb_p := sb_n.duplicate() as StyleBoxFlat
			sb_p.bg_color = Color(0.10, 0.60, 0.20, 1.0)
			sb_p.shadow_size = 2
			sb_p.shadow_offset = Vector2(0, 1)

			btn_exist.add_theme_stylebox_override("normal", sb_n)
			btn_exist.add_theme_stylebox_override("hover", sb_h)
			btn_exist.add_theme_stylebox_override("pressed", sb_p)
			btn_exist.add_theme_color_override("font_color", Color(1,1,1,1))
			btn_exist.add_theme_color_override("font_hover_color", Color(1,1,1,1))
			btn_exist.add_theme_color_override("font_pressed_color", Color(1,1,1,1))
			btn_exist.add_theme_font_size_override("font_size", 22)

			shop_root_existing.add_child(btn_exist)
			if not btn_exist.pressed.is_connected(_on_confirm_shop_pressed):
				btn_exist.pressed.connect(_on_confirm_shop_pressed)
		call_deferred("_shop_place_confirm_button")
	# invisible par défaut (affiché au clic)
	if panel is CanvasItem:
		(panel as CanvasItem).visible = false

func _on_tab_shop() -> void:
	if TicketingScreenBG != null:
		TicketingScreenBG.visible = false

	# ✅ Boutique: réactive CenterShop (sinon il reste masqué après un passage en Billetterie)
	var _cs := get_node_or_null("Content/CenterShop") as Control
	if _cs != null:
		_cs.visible = true
		_cs.mouse_filter = Control.MOUSE_FILTER_STOP

	var shop_screen_bg := get_node_or_null("ShopScreenBG") as TextureRect
	if shop_screen_bg != null:
		shop_screen_bg.visible = true

	_ensure_shop_panel()
	var _shop_overlay_frame := get_node_or_null("Content/CenterShop/PanelShop/ShopOverlayFrame") as CanvasItem
	if _shop_overlay_frame != null:
		_shop_overlay_frame.modulate = Color(1, 1, 1, 1)
	# Masque Billetterie
	if PanelTicketing != null:
		PanelTicketing.visible = false

	var _pup := get_node_or_null("Content/CenterUpgrade/PanelUpgrade")
	if _pup != null and _pup is CanvasItem:
		(_pup as CanvasItem).visible = false
	# Affiche Boutique
	var pshop := get_node_or_null("Content/CenterShop/PanelShop")
	if pshop == null:
		print("[STADIUM][SHOP] PanelShop not found")
		return
	if pshop is CanvasItem:
		(pshop as CanvasItem).visible = true

	var _shop_bg := get_node_or_null("Content/CenterShop/PanelShop/ShopBG") as TextureRect
	if _shop_bg != null:
		_shop_bg.visible = false

	var _pshop_panel := pshop as PanelContainer
	if _pshop_panel != null:
		_pshop_panel.self_modulate = Color(1, 1, 1, 0)

	_stadium_set_active_panel(pshop)
	if pshop is Control:
		_stadium_make_panel_full_screen(pshop as Control)
		(pshop as Control).offset_top = 0
		(pshop as Control).offset_bottom = 0
		_shop_force_light_text(pshop)
		_shop_apply_restock_visibility(pshop)
		_ensure_capacity_label()
		_bm_stadium_mobile_apply_shop_visual_sizes_v1()
		call_deferred("_bm_stadium_mobile_apply_shop_visual_sizes_v1")
		_stadium_fix_popularity_badges_visual()
		var _shop_columns_margin := (pshop as Node).get_node_or_null("VBox/ShopColumnsMargin") as MarginContainer
		if _shop_columns_margin != null:
			_shop_columns_margin.add_theme_constant_override("margin_left", 262 if _bm_stadium_is_mobile_layout() else 238)
		var _shop_col_left := (pshop as Node).get_node_or_null("VBox/ShopColumns/ShopColLeft") as VBoxContainer
		if _shop_col_left != null:
			_shop_col_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var _shop_rows_scroll := _shop_col_left.get_node_or_null("ShopRowsScroll") as ScrollContainer
			if _bm_stadium_is_mobile_layout():
				var _shop_rows_mobile := _shop_col_left.get_node_or_null("GridShopLeft") as Control
				if _shop_rows_scroll == null and _shop_rows_mobile != null:
					var _shop_rows_index := _shop_rows_mobile.get_index()
					_shop_col_left.remove_child(_shop_rows_mobile)
					_shop_rows_scroll = ScrollContainer.new()
					_shop_rows_scroll.name = "ShopRowsScroll"
					_shop_rows_scroll.follow_focus = true
					_shop_rows_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
					_shop_rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					_shop_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
					_shop_rows_scroll.custom_minimum_size.y = max(260.0, get_viewport_rect().size.y / max(1.0, (pshop as Control).scale.y) - 330.0)
					_shop_col_left.add_child(_shop_rows_scroll)
					_shop_col_left.move_child(_shop_rows_scroll, _shop_rows_index)
					_shop_rows_scroll.add_child(_shop_rows_mobile)
				elif _shop_rows_scroll != null:
					_shop_rows_scroll.visible = true
					_shop_rows_scroll.follow_focus = true
					_shop_rows_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
					_shop_rows_scroll.custom_minimum_size.y = max(260.0, get_viewport_rect().size.y / max(1.0, (pshop as Control).scale.y) - 330.0)
			elif _shop_rows_scroll != null:
				var _shop_rows_desktop := _shop_rows_scroll.get_node_or_null("GridShopLeft") as Control
				if _shop_rows_desktop != null:
					var _shop_rows_index := _shop_rows_scroll.get_index()
					_shop_rows_scroll.remove_child(_shop_rows_desktop)
					_shop_col_left.add_child(_shop_rows_desktop)
					_shop_col_left.move_child(_shop_rows_desktop, _shop_rows_index)
				_shop_rows_scroll.queue_free()
		var _shop_scroll := (pshop as Node).get_node_or_null("ShopVScroll") as VScrollBar
		if _shop_scroll != null:
			_shop_scroll.visible = false
		var _screen_scroll_track := get_node_or_null("ShopScreenScrollTrack") as ColorRect
		if _screen_scroll_track != null:
			_screen_scroll_track.visible = false
			var _screen_scroll_thumb := get_node_or_null("ShopScreenScrollThumb") as ColorRect
			if _screen_scroll_thumb != null:
				_screen_scroll_thumb.visible = false
			var _shop_total_frame := (pshop as Node).get_node_or_null("VBox/WrapShopTotal/TotalFrame") as Control
			if _shop_total_frame != null:
				_shop_total_frame.set_as_top_level(true)
				_shop_total_frame.global_position = Vector2(get_viewport_rect().size.x - maxf(_shop_total_frame.size.x, _shop_total_frame.get_combined_minimum_size().x) - 34.0, 48.0)
		call_deferred("_shop_place_confirm_button")
		_shop_place_back_button()
		print("[STADIUM][SHOP] opened")
		_ensure_shop_close_button()

	call_deferred("_shop_force_confirm_button")

func _shop_force_confirm_button() -> void:
	# Force le bouton Confirmer Boutique au-dessus + position symétrique du bouton Retour
	var panel := get_node_or_null("Content/CenterShop/PanelShop") as Control
	if panel == null:
		return

	var vbox := panel.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return

	var btn := vbox.get_node_or_null("BtnConfirmShop") as Button
	if btn == null:
		return

	btn.visible = true
	btn.disabled = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# BM_SHOP_CONFIRM_FORCE_CONNECT_V1
	if not btn.pressed.is_connected(_on_confirm_shop_pressed):
		btn.pressed.connect(_on_confirm_shop_pressed)

	# ✅ Overlay: évite d’être recouvert par ShopBG / Panel
	var gp := btn.global_position
	btn.set_as_top_level(true)
	btn.global_position = gp
	btn.z_index = (RenderingServer.CANVAS_ITEM_Z_MAX - 1)

	# --- Placement symétrique par rapport à BtnRetour ---
	var vp := get_viewport_rect().size
	var margin := 20.0
	var y := vp.y - 90.0

	if BtnRetour != null:
		margin = BtnRetour.global_position.x
		y = BtnRetour.global_position.y

	# largeur bouton
	var bw := btn.size.x
	if bw <= 1.0:
		bw = btn.get_combined_minimum_size().x
		if bw <= 1.0:
			bw = 240.0

	btn.global_position = Vector2(vp.x - margin - bw, y)

func _safe_int(txt: String) -> int:
	var t: String = txt.strip_edges()
	if t.is_empty():
		return 0
	var out: String = ""
	for i: int in range(t.length()):
		var code: int = t.unicode_at(i)
		if code >= 48 and code <= 57:
			out += String.chr(code)
	if out.is_empty():
		return 0
	return int(out)

func _shop_restock_unlocked_now() -> bool:
	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		d = save
	if d.has("shop") and typeof(d["shop"]) == TYPE_DICTIONARY:
		var shop_d: Dictionary = d["shop"] as Dictionary
		if bool(shop_d.get("restock_unlocked", false)):
			return true
	return int(d.get("season_round", 0)) >= 13


func _shop_apply_restock_visibility(root: Node) -> void:
	if root == null:
		return
	var unlocked := _shop_restock_unlocked_now()
	_shop_apply_restock_visibility_to_node(root, unlocked)


func _shop_apply_restock_visibility_to_node(node: Node, unlocked: bool) -> void:
	if node == null:
		return
	if node is Button and node.name.begins_with("BtnRestock_"):
		(node as Button).visible = unlocked
		(node as Button).disabled = not unlocked
		var parent_control := node.get_parent() as Control
		if parent_control != null:
			parent_control.visible = unlocked
	elif node is Control and node.name.begins_with("CellRestock_"):
		(node as Control).visible = unlocked
	elif node is Label:
		var lbl := node as Label
		var restock_text := _stadium_tr("stadium.shop.col.restock").strip_edges()
		if node.name == "HdrShopRestock" or lbl.text.strip_edges() == restock_text or lbl.text.strip_edges() == restock_text.to_upper():
			lbl.visible = unlocked
	for child in node.get_children():
		_shop_apply_restock_visibility_to_node(child, unlocked)


func _get_shop_stock_for_level(level: int, pid: String) -> int:
	# Utilise SHOP_STOCK_BY_LEVEL si présent, sinon fallback 0
	if not ("SHOP_STOCK_BY_LEVEL" in self):
		return 0
	var pack: Dictionary = SHOP_STOCK_BY_LEVEL.get(level, SHOP_STOCK_BY_LEVEL.get(1, {}))
	var base_stock: int = int(pack.get(pid, 0))
	if base_stock <= 0:
		return 0

	var ng: int = 1
	var ns: int = 1
	if typeof(save) == TYPE_DICTIONARY and save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		var st: Dictionary = save["stadium"] as Dictionary
		ng = int(st.get("niveau_global_jeu", 1))
		ns = int(st.get("niveau_stade", 1))

	var coef: float = 1.0
	if StadiumDataRef != null:
		coef = float(StadiumDataRef.get_shop_stock_mult(ng, ns))

	var computed_stock: int = maxi(base_stock, int(round(float(base_stock) * coef)))

	# BM_SHOP_CURRENT_STOCK_UI_V1
	# À partir du match 14, l'affichage Shop montre le stock réel restant.
	if typeof(save) == TYPE_DICTIONARY and int(save.get("season_round", 0)) >= 13:
		if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
			var shop_d: Dictionary = save["shop"] as Dictionary
			if shop_d.has("stock_state") and typeof(shop_d["stock_state"]) == TYPE_DICTIONARY:
				var stock_state: Dictionary = shop_d["stock_state"] as Dictionary
				if stock_state.has(pid) and typeof(stock_state[pid]) == TYPE_DICTIONARY:
					return maxi(0, int((stock_state[pid] as Dictionary).get("current", computed_stock)))

	return computed_stock

func _get_shop_active_rows_for_level(level: int) -> int:
	# pour l’instant : 4 fixes (comme demandé)
	return 4

func _get_shop_level_from_save(save: Dictionary) -> int:
	# fallback robuste (tu adapteras au vrai champ niveau quand tu veux)
	var lv := int(save.get("club_level", save.get("level", save.get("lv", 1))))
	if lv <= 0:
		lv = 1
	return lv



func _shop_price_cap(pid: String) -> int:
	var base_price: int = int(SHOP_DEFAULT_PRICES.get(pid, 0))
	if base_price <= 0:
		return 0

	var ng: int = 1
	var ns: int = 1
	if typeof(save) == TYPE_DICTIONARY and save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		var st: Dictionary = save["stadium"] as Dictionary
		ng = int(st.get("niveau_global_jeu", 1))
		ns = int(st.get("niveau_stade", 1))

	var coef: float = 1.0
	if StadiumDataRef != null:
		coef = float(StadiumDataRef.get_shop_price_cap_mult(ng, ns))

	return maxi(base_price, int(round(float(base_price) * coef)))


func _shop_price_step(pid: String, delta: int) -> void:
	var cur: int = int(_shop_price_by_id.get(pid, int(SHOP_DEFAULT_PRICES.get(pid, 0))))
	cur = max(0, cur + delta)

	var cap: int = _shop_price_cap(pid)
	if cap > 0:
		cur = mini(cur, cap)

	_shop_price_by_id[pid] = cur

	var le_any: Variant = _shop_price_le_by_id.get(pid)
	if typeof(le_any) == TYPE_OBJECT and le_any is LineEdit:
		(le_any as LineEdit).text = str(cur)
	var row_any: Variant = _shop_row_by_id.get(pid)
	if typeof(row_any) == TYPE_OBJECT and row_any is Node:
		var est_lbl := (row_any as Node).get_node_or_null("LblEstimatedRevenue") as Label
		if est_lbl != null:
			var stock := _get_shop_stock_for_level(_shop_level_cached, pid)
			est_lbl.text = _format_int(stock * cur) + " €"

	_update_shop_total()

func _update_shop_total() -> void:
	if _shop_total_label == null:
		return
	var total := 0
	var active_rows := _get_shop_active_rows_for_level(_shop_level_cached)
	var idx := 0
	for row in SHOP_PRODUCTS:
		var pid := str(row["id"])
		var stock := _get_shop_stock_for_level(_shop_level_cached, pid)
		var price := int(_shop_price_by_id.get(pid, int(SHOP_DEFAULT_PRICES.get(pid, 0))))
		if idx < active_rows:
			var _pop2 := 50
			if save.has("popularite"):
				_pop2 = int(save.get("popularite", 50))
			var _coef2 := float(clampi(_pop2, 30, 100)) / 100.0
			total += int(round(float(stock * price) * _coef2))
		idx += 1
	_shop_total_label.text = _stadium_tr("stadium.shop.total_estimate") + " : " + _format_int(total) + " €"

func _collect_shop_for_save() -> Dictionary:
	var items := {}
	var active_rows := _get_shop_active_rows_for_level(_shop_level_cached)
	var idx := 0
	for row in SHOP_PRODUCTS:
		var pid := str(row["id"])
		var stock := _get_shop_stock_for_level(_shop_level_cached, pid)
		var price := int(_shop_price_by_id.get(pid, int(SHOP_DEFAULT_PRICES.get(pid, 0))))
		var price_cap: int = _shop_price_cap(pid)
		if price_cap > 0:
			price = mini(price, price_cap)
		items[pid] = {"price": price, "qty": stock, "enabled": (idx < active_rows)}
		idx += 1

	var total := 0
	idx = 0
	for row in SHOP_PRODUCTS:
		var pid2 := str(row["id"])
		var stock2 := _get_shop_stock_for_level(_shop_level_cached, pid2)
		var price2 := int(_shop_price_by_id.get(pid2, int(SHOP_DEFAULT_PRICES.get(pid2, 0))))
		if idx < active_rows:
			total += stock2 * price2
		idx += 1

	# BM_SHOP_RESTOCK_SCHEMA_V1
	# Schéma préparé pour le futur réassortiment.
	# Pour l'instant, ne change PAS les ventes : on initialise juste un stock persistant par produit.
	var stock_state := {}
	var existing_stock_state := {}
	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		existing_stock_state = (save["shop"] as Dictionary).get("stock_state", {}) as Dictionary

	for row_stock in SHOP_PRODUCTS:
		var pid_stock := str(row_stock["id"])
		var stock_base := _get_shop_stock_for_level(_shop_level_cached, pid_stock)
		var previous := {}
		if existing_stock_state.has(pid_stock) and typeof(existing_stock_state[pid_stock]) == TYPE_DICTIONARY:
			previous = existing_stock_state[pid_stock] as Dictionary
		stock_state[pid_stock] = {
			"current": int(previous.get("current", stock_base)),
			"base": stock_base,
			"last_sold": int(previous.get("last_sold", 0)),
			"restock_total_spent": int(previous.get("restock_total_spent", 0))
		}

	return {
		"items": items,
		"level": _shop_level_cached,
		"total_forecast": total,
		"stock_state": stock_state,
		"restock_unlocked": _shop_restock_unlocked_now()
	}



func _apply_shop_from_save(shop: Dictionary) -> void:
	# Recharge uniquement les prix sauvegardés si présents (typage strict, no warnings)
	var items: Dictionary = {}
	if shop.has("items") and typeof(shop["items"]) == TYPE_DICTIONARY:
		items = shop["items"] as Dictionary

	for pid_v in items.keys():
		var pid: String = str(pid_v)
		var it_any: Variant = items[pid_v]
		if typeof(it_any) != TYPE_DICTIONARY:
			continue
		var it: Dictionary = it_any as Dictionary
		if it.has("price"):
			_shop_price_by_id[pid] = int(it["price"])

func _clamp_ticketing_seats() -> void:
	var cap: int = _stadium_current_capacity_value()
	if cap <= 0:
		return

	# max par catégorie via l’équation split existante (20/35/45)
	var pack: Dictionary = _compute_ticketing_limits(cap)
	var max_map: Dictionary = pack.get("max", {}) as Dictionary

	var a_max: int = int(max_map.get(CAT_A, cap))
	var b_max: int = int(max_map.get(CAT_B, cap))
	var c_max: int = int(max_map.get(CAT_C, cap))

	var a: int = _safe_int(SeatsA.text)
	var b: int = _safe_int(SeatsB.text)
	var c: int = _safe_int(SeatsC.text)

	if a < 0: a = 0
	if b < 0: b = 0
	if c < 0: c = 0

	# clamp A puis B puis C pour garantir A+B+C <= cap
	a = mini(a, mini(a_max, cap))
	b = mini(b, mini(b_max, maxi(0, cap - a)))
	c = mini(c, mini(c_max, maxi(0, cap - a - b)))

	SeatsA.text = _format_int(a)
	SeatsB.text = _format_int(b)
	SeatsC.text = _format_int(c)

func _clamp_ticketing_prices() -> void:
	var cap: int = _stadium_current_capacity_value()
	if cap <= 0:
		return
	var pack: Dictionary = _compute_ticketing_limits(cap)
	var price_map: Dictionary = pack.get("price", {}) as Dictionary

	var ng: int = 1
	var ns: int = 1
	if typeof(save) == TYPE_DICTIONARY and save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		var st: Dictionary = save["stadium"] as Dictionary
		ng = int(st.get("niveau_global_jeu", 1))
		ns = int(st.get("niveau_stade", 1))

	var coef: float = 1.0
	if StadiumDataRef != null:
		coef = float(StadiumDataRef.get_ticketing_price_cap_mult(ng, ns))

	var pa_max: int = int(round(float(int(price_map.get(CAT_A, 0))) * coef))
	var pb_max: int = int(round(float(int(price_map.get(CAT_B, 0))) * coef))
	var pc_max: int = int(round(float(int(price_map.get(CAT_C, 0))) * coef))

	var pa: int = _safe_int(PriceA.text)
	var pb: int = _safe_int(PriceB.text)
	var pc: int = _safe_int(PriceC.text)

	if pa < 0: pa = 0
	if pb < 0: pb = 0
	if pc < 0: pc = 0

	pa = mini(pa, pa_max)
	pb = mini(pb, pb_max)
	pc = mini(pc, pc_max)

	PriceA.text = _format_int(pa)
	PriceB.text = _format_int(pb)
	PriceC.text = _format_int(pc)


func _update_ticketing_total() -> void:
	_clamp_ticketing_seats()
	_clamp_ticketing_prices()
	var pa := _safe_int(PriceA.text)
	var pb := _safe_int(PriceB.text)
	var pc := _safe_int(PriceC.text)
	var sa := _safe_int(SeatsA.text)
	var sb := _safe_int(SeatsB.text)
	var sc := _safe_int(SeatsC.text)
	var total := pa*sa + pb*sb + pc*sc
	LblTicketingTotal.text = _stadium_tr("stadium.shop.total_estimate") + " : " + _format_int(total) + " €"
	var est_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerA") as Label
	var est_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerB") as Label
	var est_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerC") as Label
	if est_a != null:
		est_a.text = _format_int(pa * sa) + " €"
	if est_b != null:
		est_b.text = _format_int(pb * sb) + " €"
	if est_c != null:
		est_c.text = _format_int(pc * sc) + " €"


# --- Ticketing hold-repeat helpers ---
const TICK_REPEAT_DELAY_S: float = 0.25
const TICK_REPEAT_STEP_S: float = 0.06

var _tick_rep_btn: Button = null
var _tick_rep_target: LineEdit = null
var _tick_rep_delta: int = 0
var _tick_rep_timer: Timer = null

func _tick_ensure_timer() -> void:
	if _tick_rep_timer != null:
		return
	_tick_rep_timer = Timer.new()
	_tick_rep_timer.one_shot = false
	_tick_rep_timer.wait_time = TICK_REPEAT_STEP_S
	add_child(_tick_rep_timer)
	_tick_rep_timer.timeout.connect(_tick_on_timer)

func _tick_on_timer() -> void:
	if _tick_rep_target == null:
		return
	_tick_apply_step(_tick_rep_target, _tick_rep_delta)
	_update_ticketing_total()

func _tick_apply_step(le: LineEdit, delta: int) -> void:
	var cur: int = _safe_int(le.text)
	cur += delta
	if cur < 0:
		cur = 0
	le.text = str(cur)

func _tick_start(btn: Button, target: LineEdit, delta: int) -> void:
	_tick_ensure_timer()
	_tick_rep_btn = btn
	_tick_rep_target = target
	_tick_rep_delta = delta

	_tick_apply_step(target, delta)
	_update_ticketing_total()

	var t: SceneTreeTimer = get_tree().create_timer(TICK_REPEAT_DELAY_S)
	t.timeout.connect(func() -> void:
		if _tick_rep_btn == btn and _tick_rep_target == target:
			if _tick_rep_timer != null:
				_tick_rep_timer.start()
	)

func _tick_stop(btn: Button) -> void:
	if _tick_rep_btn != btn:
		return
	_tick_rep_btn = null
	_tick_rep_target = null
	_tick_rep_delta = 0
	if _tick_rep_timer != null:
		_tick_rep_timer.stop()

func _tick_bind(btn: Button, target: LineEdit, delta: int) -> void:
	if btn == null or target == null:
		return
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.button_down.connect(func() -> void: _tick_start(btn, target, delta))
	btn.button_up.connect(func() -> void: _tick_stop(btn))
	btn.mouse_exited.connect(func() -> void: _tick_stop(btn))


func _ticketing_force_controls_clickable() -> void:
	var paths: Array[String] = [
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCDown"
	]
	for pp in paths:
		var n := get_node_or_null(pp)
		if n != null and n is Button:
			var bt := n as Button
			bt.disabled = false
			bt.visible = true
			bt.mouse_filter = Control.MOUSE_FILTER_STOP
			bt.focus_mode = Control.FOCUS_NONE

func _stadium_bind_ticketing_inputs() -> void:
	# ✅ Billetterie: bind des signaux UNE seule fois (évite +2 sur les prix)
	if _ticketing_inputs_bound:
		return
	_ticketing_inputs_bound = true
	var edits: Array[LineEdit] = [PriceA, PriceB, PriceC, SeatsA, SeatsB, SeatsC]
	for e: LineEdit in edits:
		if e != null and not e.text_changed.is_connected(_on_ticketing_changed):
			e.text_changed.connect(_on_ticketing_changed)

	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceAUp") as Button,	 PriceA,  +1)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceADown") as Button,	 PriceA,  -1)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBUp") as Button,	 PriceB,  +1)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBDown") as Button,	 PriceB,  -1)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCUp") as Button,	 PriceC,  +1)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCDown") as Button,	 PriceC,  -1)

	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsAUp") as Button,	 SeatsA,  +10)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsADown") as Button,	 SeatsA,  -10)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBUp") as Button,	 SeatsB,  +10)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBDown") as Button,	 SeatsB,  -10)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCUp") as Button,	 SeatsC,  +10)
	_tick_bind(get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCDown") as Button,	 SeatsC,  -10)

	_update_ticketing_total()



func _stadium_fix_ticketing_mouse() -> void:
	# Fix "freeze" Billetterie : un background peut capturer les clics (mouse_filter STOP).
	# On force les backgrounds en IGNORE et les vrais contrôles en STOP.
	if PanelTicketing == null:
		return

	PanelTicketing.mouse_filter = Control.MOUSE_FILTER_PASS

	# Parcours récursif : backgrounds -> IGNORE
	var stack: Array = [PanelTicketing]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
			if ch is TextureRect:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			elif ch is ColorRect:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Reforce les boutons +/- (et évite un disable résiduel)
	var btn_paths := [
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCDown",
	]
	for pp in btn_paths:
		var b := get_node_or_null(pp) as Button
		if b != null:
			b.disabled = false
			b.visible = true
			b.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_ticketing_step(btn: Button) -> void:
	var target: LineEdit = null
	var delta := 0

	match btn.name:
		"PriceAUp": target = PriceA; delta = +1
		"PriceADown": target = PriceA; delta = -1
		"PriceBUp": target = PriceB; delta = +1
		"PriceBDown": target = PriceB; delta = -1
		"PriceCUp": target = PriceC; delta = +1
		"PriceCDown": target = PriceC; delta = -1

		"SeatsAUp": target = SeatsA; delta = +10
		"SeatsADown": target = SeatsA; delta = -10
		"SeatsBUp": target = SeatsB; delta = +10
		"SeatsBDown": target = SeatsB; delta = -10
		"SeatsCUp": target = SeatsC; delta = +10
		"SeatsCDown": target = SeatsC; delta = -10

	if target == null:
		return

	var v := _safe_int(target.text) + delta
	if v < 0: v = 0
	target.text = str(v)
	_update_ticketing_total()

func _on_ticketing_changed(_t: String) -> void:
	_update_ticketing_total()

func _ensure_ticket_cat_icon(label_name: String, wrap_name: String, img_name: String, img_path: String) -> void:
	var lbl := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/%s" % label_name) as Label
	if lbl == null:
		return
	if lbl.get_parent() == null:
		return
	if get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/%s" % wrap_name) != null:
		return

	var parent := lbl.get_parent()
	var idx := lbl.get_index()

	var wrap := HBoxContainer.new()
	wrap.name = wrap_name
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 0)

	parent.remove_child(lbl)
	wrap.add_child(lbl)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 44)

	var img := TextureRect.new()
	img.name = img_name
	img.custom_minimum_size = Vector2(160, 100)
	img.size = Vector2(160, 100)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(img_path):
		img.texture = load(img_path) as Texture2D

	wrap.add_child(img)
	parent.add_child(wrap)
	parent.move_child(wrap, idx)


func _ensure_ticket_cat_a_icon() -> void:
	_ensure_ticket_cat_icon("LblCatA", "CatAIconWrap", "ImgBilletCatA", "res://assets/images/billetterie/billet_catA.png")


func _ensure_ticket_cat_b_icon() -> void:
	_ensure_ticket_cat_icon("LblCatB", "CatBIconWrap", "ImgBilletCatB", "res://assets/images/billetterie/billet_catB.png")


func _ensure_ticket_cat_c_icon() -> void:
	_ensure_ticket_cat_icon("LblCatC", "CatCIconWrap", "ImgBilletCatC", "res://assets/images/billetterie/billet_catC.png")


func _ensure_ticket_cat_a_icon_legacy_unused() -> void:
	var lbl := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/LblCatA") as Label
	if lbl == null:
		return
	if lbl.get_parent() == null:
		return
	if get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/CatAIconWrap") != null:
		return

	var parent := lbl.get_parent()
	var idx := lbl.get_index()

	var wrap := HBoxContainer.new()
	wrap.name = "CatAIconWrap"
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 0)

	parent.remove_child(lbl)
	wrap.add_child(lbl)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 44)

	var img := TextureRect.new()
	img.name = "ImgBilletCatA"
	img.custom_minimum_size = Vector2(145, 91)
	img.size = Vector2(145, 91)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/images/billetterie/billet_catA.png"):
		img.texture = load("res://assets/images/billetterie/billet_catA.png") as Texture2D

	wrap.add_child(img)
	parent.add_child(wrap)
	parent.move_child(wrap, idx)


func _stadium_boost_ticketing_fonts() -> void:
	# ⚠️ Ne change PAS la taille du panel / fond. Seulement les polices (+50%).
	var nodes: Array[Control] = []

	# Titres / totaux
	if LblTicketingTitle != null: nodes.append(LblTicketingTitle)
	if LblTicketingTotal != null: nodes.append(LblTicketingTotal)

	# Headers + catégories (dans la scène .tscn, ils existent : HdrCat/HdrPrice/HdrSeats + LblCatA/B/C)
	var hdr_cat := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrCat") as Control
	var hdr_price := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrPrice") as Control
	var hdr_seats := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrSeats") as Control
	var hdr_estimated := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/HdrSpacer") as Control
	if hdr_cat != null: nodes.append(hdr_cat)
	if hdr_price != null:
		if hdr_price is Label:
			(hdr_price as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nodes.append(hdr_price)
	if hdr_seats != null:
		if hdr_seats is Label:
			(hdr_seats as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nodes.append(hdr_seats)
	if hdr_estimated != null:
		if hdr_estimated is Label:
			(hdr_estimated as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nodes.append(hdr_estimated)

	var sb_ticketing_header := StyleBoxFlat.new()
	sb_ticketing_header.bg_color = Color(0.05, 0.07, 0.09, 0.78)
	sb_ticketing_header.border_width_bottom = 2
	sb_ticketing_header.border_color = Color(1, 1, 1, 0.22)
	sb_ticketing_header.corner_radius_top_left = 8
	sb_ticketing_header.corner_radius_top_right = 8
	sb_ticketing_header.corner_radius_bottom_left = 8
	sb_ticketing_header.corner_radius_bottom_right = 8
	sb_ticketing_header.content_margin_left = 10
	sb_ticketing_header.content_margin_right = 10
	sb_ticketing_header.content_margin_top = 6
	sb_ticketing_header.content_margin_bottom = 6
	for h_ticketing in [hdr_cat, hdr_price, hdr_seats, hdr_estimated]:
		if h_ticketing != null and h_ticketing is Label:
			(h_ticketing as Label).add_theme_stylebox_override("normal", sb_ticketing_header)
			(h_ticketing as Label).add_theme_color_override("font_color", Color(1,1,1,1))
			(h_ticketing as Label).add_theme_color_override("font_outline_color", Color(0,0,0,0.55))
			(h_ticketing as Label).add_theme_constant_override("outline_size", 1)

	var cat_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/LblCatA") as Control
	var cat_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/LblCatB") as Control
	var cat_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/LblCatC") as Control
	if cat_a != null: nodes.append(cat_a)
	if cat_b != null: nodes.append(cat_b)
	if cat_c != null: nodes.append(cat_c)
	var ticket_est_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerA") as Control
	var ticket_est_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerB") as Control
	var ticket_est_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerC") as Control
	if ticket_est_a != null: nodes.append(ticket_est_a)
	if ticket_est_b != null: nodes.append(ticket_est_b)
	if ticket_est_c != null: nodes.append(ticket_est_c)
	
	if cat_a != null and cat_a is Label: (cat_a as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cat_b != null and cat_b is Label: (cat_b as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if cat_c != null and cat_c is Label: (cat_c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ticket_est_a != null and ticket_est_a is Label: (ticket_est_a as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ticket_est_b != null and ticket_est_b is Label: (ticket_est_b as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ticket_est_c != null and ticket_est_c is Label: (ticket_est_c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Inputs
	if PriceA != null: nodes.append(PriceA)
	if PriceB != null: nodes.append(PriceB)
	if PriceC != null: nodes.append(PriceC)
	if SeatsA != null: nodes.append(SeatsA)
	if SeatsB != null: nodes.append(SeatsB)
	if SeatsC != null: nodes.append(SeatsC)

	# Boutons +/- (mêmes paths que dans _stadium_bind_ticketing_inputs)
	var btn_paths: Array[String] = [
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceCDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsAUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsADown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsBDown",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCUp",
		"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsCDown"
	]
	# NOTE: si tes boutons sont désormais sous CenterTicketing, on tente aussi la variante
	var btn_paths_alt: Array[String] = []
	for pp: String in btn_paths:
		btn_paths_alt.append(pp.replace("Content/CenterTicketing/PanelTicketing", "Content/CenterTicketing/PanelTicketing"))

	for pp: String in btn_paths:
		var b := get_node_or_null(pp) as Control
		if b != null: nodes.append(b)
	for pp: String in btn_paths_alt:
		var b2 := get_node_or_null(pp) as Control
		if b2 != null: nodes.append(b2)

	# Application du boost
	for c: Control in nodes:
		if c == null:
			continue
		var cur: int = c.get_theme_font_size("font_size")
		if cur <= 0:
			# fallback raisonnable si le thème ne renvoie rien
			cur = 22
		var boosted: int = max(1, int(round(float(cur) * STADIUM_FONT_BOOST_FACTOR)) - 2)
		c.add_theme_font_size_override("font_size", boosted)

	if _bm_stadium_is_mobile_layout():
		for pp: String in btn_paths:
			var btn_mobile := get_node_or_null(pp) as Button
			if btn_mobile != null:
				btn_mobile.custom_minimum_size = Vector2(52, 44)
		for pp_value: String in [
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceA",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceB",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceC",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsA",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsB",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsC",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerA",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerB",
			"Content/CenterTicketing/PanelTicketing/VBox/Grid/SpacerC"
		]:
			var value_ctrl := get_node_or_null(pp_value) as Control
			if value_ctrl != null:
				value_ctrl.add_theme_font_size_override("font_size", value_ctrl.get_theme_font_size("font_size") + 2)



func _ticketing_place_back_button() -> void:
	var vbox := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox") as VBoxContainer
	if vbox == null:
		return

	var btn := vbox.get_node_or_null("BtnBackTicketing") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "BtnBackTicketing"
		btn.text = _stadium_tr("btn.back")
		btn.custom_minimum_size = Vector2(206, 62)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_bm_apply_back_button_style(btn)
		vbox.add_child(btn)

	if btn.text == "btn.back" or btn.text.strip_edges() == "":
		btn.text = "Back"
	btn.visible = true
	btn.disabled = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_as_top_level(true)
	btn.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	var cb_ticketing := Callable(self, "_on_ticketing_close_pressed")
	if not btn.pressed.is_connected(cb_ticketing):
		btn.pressed.connect(cb_ticketing)

	var bh := btn.size.y
	if bh <= 1.0:
		bh = max(btn.custom_minimum_size.y, 62.0)
	var vp_size := get_viewport_rect().size
	btn.global_position = Vector2(34.0, vp_size.y - bh - 34.0)


func _shop_place_back_button() -> void:
	var vbox := get_node_or_null("Content/CenterShop/PanelShop/VBox") as VBoxContainer
	if vbox == null:
		return

	var btn := vbox.get_node_or_null("BtnBackShop") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "BtnBackShop"
		btn.text = _stadium_tr("btn.back")
		btn.custom_minimum_size = Vector2(206, 62)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_bm_apply_back_button_style(btn)
		vbox.add_child(btn)

	if btn.text == "btn.back" or btn.text.strip_edges() == "":
		btn.text = "Back"
	btn.visible = true
	btn.disabled = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_as_top_level(true)
	btn.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	var cb_shop := Callable(self, "_on_shop_close_pressed")
	if not btn.pressed.is_connected(cb_shop):
		btn.pressed.connect(cb_shop)

	var bh := btn.size.y
	if bh <= 1.0:
		bh = max(btn.custom_minimum_size.y, 62.0)
	var vp_size := get_viewport_rect().size
	btn.global_position = Vector2(34.0, vp_size.y - bh - 34.0)


func _ticketing_place_confirm_button() -> void:
	var btn := find_child("BtnConfirmTicketing", true, false) as Button
	if btn == null:
		return

	btn.visible = true
	btn.disabled = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_as_top_level(true)
	btn.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1

	var bw := btn.size.x
	if bw <= 1.0:
		bw = max(btn.custom_minimum_size.x, 206.0)

	var bh := btn.size.y
	if bh <= 1.0:
		bh = max(btn.custom_minimum_size.y, 62.0)
	var vp_size := get_viewport_rect().size
	btn.global_position = Vector2(vp_size.x - bw - 34.0, vp_size.y - bh - 34.0)


# BM_TICKETING_CONFIRM_V1 -----------------------------------------------------
func _ensure_ticketing_confirm_button() -> void:
	# On cherche UNIQUEMENT le container de billetterie exact
	var vbox := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox")
	if vbox == null:
		return

	# Eviter doublon
	var btn := vbox.get_node_or_null("BtnConfirmTicketing")
	if btn == null:
		btn = Button.new()
		btn.name = "BtnConfirmTicketing"
		btn.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
		btn.custom_minimum_size = Vector2(206, 62)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shop_apply_confirm_style(btn)
		vbox.add_child(btn)

	if not btn.pressed.is_connected(_on_confirm_ticketing_pressed):
		btn.pressed.connect(_on_confirm_ticketing_pressed)

func _to_int(le: Node) -> int:
	if le == null:
		return 0
	if le.has_method("get_text"):
		var t := str(le.call("get_text")).strip_edges()
		return int(t) if t.is_valid_int() else 0
	if le.has_method("get"):
		var t2 := str(le.get("text")).strip_edges()
		return int(t2) if t2.is_valid_int() else 0
	return 0

func _on_confirm_ticketing_pressed() -> void:
	if PanelTicketing == null or not PanelTicketing.visible:
		return

	_clamp_ticketing_prices()
	PlayerLife.ensure_finance_schema(save)

	# On récupère les LineEdit si ils existent (paths “probables” + fallback par name)
	var price_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/PriceA")
	var price_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/PriceB")
	var price_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/PriceC")
	var seats_a := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/SeatsA")
	var seats_b := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/SeatsB")
	var seats_c := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/SeatsC")

	# fallback par name (si l’arbo change)
	if price_a == null: price_a = find_child("PriceA", true, false)
	if price_b == null: price_b = find_child("PriceB", true, false)
	if price_c == null: price_c = find_child("PriceC", true, false)
	if seats_a == null: seats_a = find_child("SeatsA", true, false)
	if seats_b == null: seats_b = find_child("SeatsB", true, false)
	if seats_c == null: seats_c = find_child("SeatsC", true, false)

	var t := {}
	t["price_a"] = max(0, _to_int(price_a))
	t["price_b"] = max(0, _to_int(price_b))
	t["price_c"] = max(0, _to_int(price_c))
	t["seats_a"] = max(0, _safe_int(seats_a.text if seats_a != null else "0"))
	t["seats_b"] = max(0, _safe_int(seats_b.text if seats_b != null else "0"))
	t["seats_c"] = max(0, _safe_int(seats_c.text if seats_c != null else "0"))

	save["ticketing"] = t
	if not save.has("stadium") or typeof(save["stadium"]) != TYPE_DICTIONARY:
		save["stadium"] = {}
	(save["stadium"] as Dictionary)["ticketing"] = t
	PlayerLife.write_savegame(save)
	_bm_refresh_price_adjust_mission_counter()
	print("[STADIUM][TICKETING] confirmed -> ", t)
	_on_ticketing_close_pressed()
# ---------------------------------------------------------------------------



# BM_TICKETING_CONFIRM_V2 -----------------------------------------------------
func _le_int(n: Node) -> int:
	if n == null:
		return 0
	var t := ""
	if n.has_method("get_text"):
		t = str(n.call("get_text"))
	else:
		t = str(n.get("text"))
	t = t.strip_edges()
	return int(t) if t.is_valid_int() else 0

# BM_TICKETING_LOAD_V1 ---------------------------------------------------------
func _load_ticketing_from_save() -> void:
	if typeof(save) != TYPE_DICTIONARY:
		return

	var t: Dictionary = {}

	# Schéma 1: ticketing à la racine
	if save.has("ticketing") and typeof(save["ticketing"]) == TYPE_DICTIONARY and not (save["ticketing"] as Dictionary).is_empty():
		t = save["ticketing"]

	# Schéma 2: stadium.ticketing (compat)
	elif save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
		var st := save["stadium"] as Dictionary
		if st.has("ticketing") and typeof(st["ticketing"]) == TYPE_DICTIONARY:
			t = st["ticketing"]

	if t.is_empty():
		return

	_ticketing_set_le_by_name("PriceA", t.get("price_a", 0))
	_ticketing_set_le_by_name("PriceB", t.get("price_b", 0))
	_ticketing_set_le_by_name("PriceC", t.get("price_c", 0))
	_ticketing_set_le_by_name("SeatsA", t.get("seats_a", 0))
	_ticketing_set_le_by_name("SeatsB", t.get("seats_b", 0))
	_ticketing_set_le_by_name("SeatsC", t.get("seats_c", 0))

	print("[STADIUM][TICKETING] loaded from save -> ", t)
# -----------------------------------------------------------------------------

# --- SHOP / BOUTIQUE ---------------------------------------------------------

func _ensure_shop_confirm_button() -> void:
	return # disabled: BtnConfirmShop is created/styled in _ensure_shop_panel()

	# On essaie de trouver un container raisonnable côté boutique.
	# (robuste: d'abord par chemins probables, sinon find_child)
	var parent: Control = null

	# Chemins probables (si tu as un panel boutique similaire au ticketing)
	var try_paths := [
		"Content/CenterShop/PanelShop/VBox",
		"Content/CenterShop/PanelBoutique/VBox",
		"Content/PanelShop/VBox",
		"Content/PanelBoutique/VBox",
	]
	for p in try_paths:
		var n := get_node_or_null(p)
		if n != null and n is Control:
			parent = n
			break

	if parent == null:
		# Fallback: cherche un node "PanelShop" ou "PanelBoutique"
		var ps := find_child("PanelShop", true, false)
		if ps == null:
			ps = find_child("PanelBoutique", true, false)
		if ps != null:
			var v := (ps as Node).find_child("VBox", true, false)
			if v != null and v is Control:
				parent = v

	if parent == null:
		return

	if parent.get_node_or_null("BtnConfirmShop") != null:
		return

	var btn := Button.new()
	btn.name = "BtnConfirmShop"
	btn.text = tr("btn.confirm") if tr("btn.confirm") != "btn.confirm" else "Confirmer"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Style "vert" minimal sans casser ton thème 3D existant
	btn.modulate = Color(1, 1, 1, 1)

	parent.add_child(btn)

	if not btn.pressed.is_connected(_on_confirm_shop_pressed):
		btn.pressed.connect(_on_confirm_shop_pressed)

func _savegame_write(save: Dictionary) -> void:
	# On passe par un singleton/service (instance) -> OK avec has_method()
	var svc := get_node_or_null("/root/SaveSvc")
	if svc != null:
		if svc.has_method("save_savegame"):
			svc.call("save_savegame", save)
			return
		if svc.has_method("write_savegame"):
			svc.call("write_savegame", save)
			return
		if svc.has_method("save"):
			svc.call("save", save)
			return
		if svc.has_method("save_game"):
			svc.call("save_game", save)
			return

	# Fallback: autre nom de singleton possible
	var svc2 := get_node_or_null("/root/SaveSingleton")
	if svc2 != null:
		if svc2.has_method("save_savegame"):
			svc2.call("save_savegame", save)
			return
		if svc2.has_method("write_savegame"):
			svc2.call("write_savegame", save)
			return
		if svc2.has_method("save"):
			svc2.call("save", save)
			return
		if svc2.has_method("save_game"):
			svc2.call("save_game", save)
			return

	push_error("[STADIUM][SHOP] No save service found (expected /root/SaveSvc or /root/Save).")

# BM_SHOP_RESTOCK_PURCHASE_V1
func _apply_shop_restock_purchase(pid: String, units: int, total_cost: int) -> void:
	if pid.strip_edges() == "" or units <= 0 or total_cost <= 0:
		return

	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		return
	PlayerLife.ensure_finance_schema(d)

	if not d.has("shop") or typeof(d["shop"]) != TYPE_DICTIONARY:
		d["shop"] = {}
	var shop_d: Dictionary = d["shop"] as Dictionary

	var stock_state: Dictionary = {}
	if shop_d.has("stock_state") and typeof(shop_d["stock_state"]) == TYPE_DICTIONARY:
		stock_state = shop_d["stock_state"] as Dictionary

	var base_stock: int = _get_shop_stock_for_level(_shop_level_cached, pid)
	var st: Dictionary = {}
	if stock_state.has(pid) and typeof(stock_state[pid]) == TYPE_DICTIONARY:
		st = stock_state[pid] as Dictionary

	st["current"] = maxi(0, int(st.get("current", base_stock))) + units
	st["base"] = maxi(base_stock, int(st.get("base", base_stock)))
	st["last_sold"] = int(st.get("last_sold", 0))
	st["restock_total_spent"] = int(st.get("restock_total_spent", 0)) + total_cost
	stock_state[pid] = st

	shop_d["stock_state"] = stock_state
	shop_d["restock_unlocked"] = true
	d["shop"] = shop_d
	d["total_shop_restock_cost"] = int(d.get("total_shop_restock_cost", 0)) + total_cost
	d["total_depenses"] = int(d.get("total_depenses", 0)) + total_cost

	if d.has("finance") and typeof(d["finance"]) == TYPE_DICTIONARY:
		(d["finance"] as Dictionary)["euros"] = maxi(0, int(d.get("total_recettes", 0)) - int(d.get("total_depenses", 0)))
	if d.has("wallet") and typeof(d["wallet"]) == TYPE_DICTIONARY:
		(d["wallet"] as Dictionary)["euros"] = maxi(0, int(d.get("total_recettes", 0)) - int(d.get("total_depenses", 0)))

	PlayerLife.write_savegame(d)
	save = d
	print("[SHOP][RESTOCK] purchased pid=", pid, " units=", units, " cost=", total_cost)

	var row_any: Variant = _shop_row_by_id.get(pid)
	if typeof(row_any) == TYPE_OBJECT and row_any is Node:
		var row_node := row_any as Node
		var stock_lbl := row_node.get_node_or_null("LblStock") as Label
		if stock_lbl != null:
			stock_lbl.text = str(int(st.get("current", base_stock)))
		var est_lbl := row_node.get_node_or_null("LblEstimatedRevenue") as Label
		if est_lbl != null:
			var pop := int(save.get("popularite", 50))
			var coef := float(clampi(pop, 30, 100)) / 100.0
			var price := int(_shop_price_by_id.get(pid, int(SHOP_DEFAULT_PRICES.get(pid, 0))))
			est_lbl.text = _format_int(int(round(float(int(st.get("current", base_stock)) * price) * coef))) + " €"
	_update_shop_total()


# BM_SHOP_RESTOCK_POPUP_V4_DESIGN
func _show_shop_restock_popup(pid: String) -> void:
	var base_price: int = maxi(1, int(SHOP_DEFAULT_PRICES.get(pid, 10)))
	var base_stock_for_restock := _get_shop_stock_for_level(_shop_level_cached, pid)
	var small_units := int(round(float(base_stock_for_restock) * 0.80))
	var large_units := int(round(float(base_stock_for_restock) * 1.50))
	var small_cost := small_units * maxi(1, int(round(float(base_price) * 0.60)))
	var large_cost := large_units * maxi(1, int(round(float(base_price) * 0.52)))

	var already := get_node_or_null("ShopRestockPopup")
	if already != null and is_instance_valid(already):
		already.queue_free()

	var popup := Control.new()
	popup.name = "ShopRestockPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_as_relative = false
	popup.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	popup.set_as_top_level(true)
	popup.global_position = Vector2.ZERO
	popup.size = get_viewport_rect().size
	add_child(popup)
	popup.move_to_front()

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.50)
	popup.add_child(dark)

	var card := Panel.new()
	card.size = Vector2(960, 340)
	card.position = (get_viewport_rect().size - card.size) * 0.5
	card.z_as_relative = false
	card.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	card.set_as_top_level(true)
	card.global_position = (get_viewport_rect().size - card.size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)
	card.move_to_front()

	var title := Label.new()
	title.text = "Restock"
	title.position = Vector2(28, 20)
	title.size = Vector2(320, 42)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(900, 18)
	close_btn.size = Vector2(42, 42)
	close_btn.pressed.connect(func(): popup.queue_free())
	card.add_child(close_btn)

	var product_img := TextureRect.new()
	product_img.position = Vector2(820, 24)
	product_img.size = Vector2(58, 58)
	product_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	for row in SHOP_PRODUCTS:
		if str(row.get("id", "")) == pid:
			var img_path := str(row.get("image", row.get("image_path", row.get("icon", ""))))
			if img_path != "" and ResourceLoader.exists(img_path):
				product_img.texture = load(img_path)
			break
	card.add_child(product_img)

	# BM_RESTOCK_POPUP_MINI_TABLE_V1
	var current_stock := _get_shop_stock_for_level(_shop_level_cached, pid)
	var save_popup: Dictionary = PlayerLife.load_savegame()
	if typeof(save_popup) == TYPE_DICTIONARY and save_popup.has("shop") and typeof(save_popup["shop"]) == TYPE_DICTIONARY:
		var shop_popup: Dictionary = save_popup["shop"] as Dictionary
		if shop_popup.has("stock_state") and typeof(shop_popup["stock_state"]) == TYPE_DICTIONARY:
			var stock_state_popup: Dictionary = shop_popup["stock_state"] as Dictionary
			if stock_state_popup.has(pid) and typeof(stock_state_popup[pid]) == TYPE_DICTIONARY:
				current_stock = int((stock_state_popup[pid] as Dictionary).get("current", current_stock))

	var headers := [
		{"text": "Order", "x": 42.0, "w": 170.0},
		{"text": "Units", "x": 225.0, "w": 90.0},
		{"text": "Cost/unit", "x": 330.0, "w": 120.0},
		{"text": "Total cost", "x": 465.0, "w": 130.0},
		{"text": "New stock", "x": 610.0, "w": 140.0}
	]
	for h in headers:
		var lbl_h := Label.new()
		lbl_h.text = str(h["text"])
		lbl_h.position = Vector2(float(h["x"]), 86)
		lbl_h.size = Vector2(float(h["w"]), 28)
		lbl_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_h.add_theme_font_size_override("font_size", 20)
		lbl_h.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 1))
		card.add_child(lbl_h)

	var small_lbl := Label.new()
	small_lbl.text = "Small order"
	small_lbl.position = Vector2(42, 122)
	small_lbl.size = Vector2(170, 38)
	small_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(small_lbl)

	var small_units_lbl := Label.new()
	small_units_lbl.text = str(small_units)
	small_units_lbl.position = Vector2(225, 122)
	small_units_lbl.size = Vector2(90, 38)
	small_units_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_units_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(small_units_lbl)

	var small_unit_cost_lbl := Label.new()
	small_unit_cost_lbl.text = _format_int(int(round(float(small_cost) / float(maxi(1, small_units))))) + " €"
	small_unit_cost_lbl.position = Vector2(330, 122)
	small_unit_cost_lbl.size = Vector2(120, 38)
	small_unit_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_unit_cost_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(small_unit_cost_lbl)

	var small_cost_lbl := Label.new()
	small_cost_lbl.text = _format_int(small_cost) + " €"
	small_cost_lbl.position = Vector2(465, 122)
	small_cost_lbl.size = Vector2(130, 38)
	small_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_cost_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(small_cost_lbl)

	var small_stock_lbl := Label.new()
	small_stock_lbl.text = str(current_stock + small_units)
	small_stock_lbl.position = Vector2(610, 122)
	small_stock_lbl.size = Vector2(120, 38)
	small_stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_stock_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(small_stock_lbl)

	var large_lbl := Label.new()
	large_lbl.text = "Large order"
	large_lbl.position = Vector2(42, 182)
	large_lbl.size = Vector2(170, 38)
	large_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(large_lbl)

	var large_units_lbl := Label.new()
	large_units_lbl.text = str(large_units)
	large_units_lbl.position = Vector2(225, 182)
	large_units_lbl.size = Vector2(90, 38)
	large_units_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	large_units_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(large_units_lbl)

	var large_unit_cost_lbl := Label.new()
	large_unit_cost_lbl.text = _format_int(int(round(float(large_cost) / float(maxi(1, large_units))))) + " €"
	large_unit_cost_lbl.position = Vector2(330, 182)
	large_unit_cost_lbl.size = Vector2(120, 38)
	large_unit_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	large_unit_cost_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(large_unit_cost_lbl)

	var large_cost_lbl := Label.new()
	large_cost_lbl.text = _format_int(large_cost) + " €"
	large_cost_lbl.position = Vector2(465, 182)
	large_cost_lbl.size = Vector2(130, 38)
	large_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	large_cost_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(large_cost_lbl)

	var large_stock_lbl := Label.new()
	large_stock_lbl.text = str(current_stock + large_units)
	large_stock_lbl.position = Vector2(610, 182)
	large_stock_lbl.size = Vector2(120, 38)
	large_stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	large_stock_lbl.add_theme_font_size_override("font_size", 23)
	card.add_child(large_stock_lbl)

	var small_btn := Button.new()
	small_btn.text = "Small order"
	small_btn.position = Vector2(770, 105)
	small_btn.size = Vector2(160, 48)
	small_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	small_btn.pressed.connect(func():
		_apply_shop_restock_purchase(pid, small_units, small_cost)
		popup.queue_free()
	)
	card.add_child(small_btn)

	var large_btn := Button.new()
	large_btn.text = "Large order"
	large_btn.position = Vector2(770, 175)
	large_btn.size = Vector2(160, 48)
	large_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	large_btn.pressed.connect(func():
		_apply_shop_restock_purchase(pid, large_units, large_cost)
		popup.queue_free()
	)
	card.add_child(large_btn)

	# BM_RESTOCK_POPUP_GREEN_BUTTONS_V1
	var green := StyleBoxFlat.new()
	green.bg_color = Color(0.18, 0.68, 0.32, 1)
	green.corner_radius_top_left = 12
	green.corner_radius_top_right = 12
	green.corner_radius_bottom_left = 12
	green.corner_radius_bottom_right = 12
	small_btn.add_theme_stylebox_override("normal", green)
	large_btn.add_theme_stylebox_override("normal", green.duplicate())

func _on_confirm_shop_pressed() -> void:
	PlayerLife.ensure_finance_schema(save)

	var shop := _collect_shop_for_save()
	save["shop"] = shop

	save["shop_total_forecast"] = int(shop.get("total_forecast", 0))
	PlayerLife.write_savegame(save)
	_bm_refresh_price_adjust_mission_counter()
	print("[STADIUM][SHOP] confirmed -> ", shop)
	_on_shop_close_pressed()

func _load_shop_from_save() -> void:
	var shop: Dictionary = {}

	# Schéma 1: shop à la racine
	if save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
		shop = save["shop"]

	# Schéma 2: stadium.shop (compat future)
	if shop.is_empty():
		if save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
			var st: Dictionary = save["stadium"]
			if st.has("shop") and typeof(st["shop"]) == TYPE_DICTIONARY:
				shop = st["shop"]

	_apply_shop_to_ui(shop)


func _collect_shop_from_ui() -> Dictionary:
	# IMPORTANT:
	# - on n’impose pas tes noms exacts ici.
	# - on collecte via noms "PriceX" / "QtyX" si tu les as, sinon tu pourras les adapter.
	#
	# Stratégie:
	# - repérer des paires Price/Qty par “suffix” (Cap, Scarf, Shirt, Flag)
	# - si tu n’as pas ces noms, adapte juste la liste suffixes + les noms des LineEdit

	var shop: Dictionary = {"items": {}}

	var suffixes := ["Cap", "Scarf", "Shirt", "Flag"] # adapte à tes articles réels
	for suf in suffixes:
		var le_p := _find_le_any(["Price" + suf, "price_" + suf.to_lower(), "price" + suf])
		var le_q := _find_le_any(["Qty" + suf, "qty_" + suf.to_lower(), "qty" + suf, "Count" + suf])

		if le_p == null and le_q == null:
			continue

		var price := 0
		var qty := 0
		if le_p != null: price = max(0, _to_int(le_p))
		if le_q != null: qty = max(0, _to_int(le_q))

		shop["items"][suf.to_lower()] = {"price": price, "qty": qty}

	return shop


func _apply_shop_to_ui(shop: Dictionary) -> void:
	if shop.is_empty():
		return
	var items: Dictionary = shop.get("items", {})
	if typeof(items) != TYPE_DICTIONARY:
		return

	for k in items.keys():
		var it: Dictionary = items[k]
		if typeof(it) != TYPE_DICTIONARY:
			continue

		var suf := str(k).capitalize() # cap -> Cap
		var price := int(it.get("price", 0))
		var qty := int(it.get("qty", 0))

		_set_le_any(["Price" + suf, "price_" + str(k), "price" + suf], price)
		_set_le_any(["Qty" + suf, "qty_" + str(k), "qty" + suf, "Count" + suf], qty)


func _find_le_any(names: Array) -> LineEdit:
	for nm in names:
		var n := find_child(str(nm), true, false)
		if n != null and n is LineEdit:
			return n
	return null


func _set_le_any(names: Array, v: int) -> void:
	for nm in names:
		var n := find_child(str(nm), true, false)
		if n != null and n is LineEdit:
			(n as LineEdit).text = str(v)
			return

# BM_TICKETING_LOAD_V1 ---------------------------------------------------------
func _ticketing_set_le_by_name(name: String, v: Variant) -> void:
	var n := get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceA/%s" % name)
	if n == null:
		n = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceB/%s" % name)
	if n == null:
		n = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxPriceC/%s" % name)
	if n == null:
		n = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsA/%s" % name)
	if n == null:
		n = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsB/%s" % name)
	if n == null:
		n = get_node_or_null("Content/CenterTicketing/PanelTicketing/VBox/Grid/BoxSeatsC/%s" % name)
	if n == null:
		n = find_child(name, true, false)
	if n == null:
		return

	var iv := 0
	if typeof(v) == TYPE_FLOAT:
		iv = int(round(float(v)))
	elif typeof(v) == TYPE_INT:
		iv = int(v)
	else:
		var txt := str(v).strip_edges()
		if txt.is_valid_float():
			iv = int(round(float(txt)))
		elif txt.is_valid_int():
			iv = int(txt)

	if n.has_method("set_text"):
		n.call("set_text", str(max(0, iv)))
	else:
		n.set("text", str(max(0, iv)))


func _input(event: InputEvent) -> void:
	return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var up := get_node_or_null("Content/CenterUpgrade/PanelUpgrade") as CanvasItem
		if up != null and up.visible:
			var h := get_viewport().gui_get_hovered_control()
			if h != null:
				print("[UPGRADE][HOVER] ", h.name, " path=", h.get_path(), " mouse_filter=", (h as Control).mouse_filter if h is Control else "n/a")
			else:
				print("[UPGRADE][HOVER] none")
	if PanelTicketing != null and PanelTicketing.visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_ticketing_debug_hover()


func _stadium_fix_popularity_badges_visual() -> void:
	for nm in ["PopularityBadge", "PopularityBadge2"]:
		var lbl := get_node_or_null(nm) as Label
		if lbl != null:
			var pop_color := Color(0, 0, 0, 1) if _stadium_level_1_1_main_text_black() else Color(1, 1, 1, 1)
			lbl.modulate = pop_color
			lbl.self_modulate = pop_color
			lbl.add_theme_color_override("font_color", pop_color)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
			lbl.add_theme_constant_override("outline_size", 0)
			lbl.set_as_top_level(true)
			lbl.z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 2
			lbl.visible = true


func _on_close_stadium_intro_pressed() -> void:
	print("[POPUP] OK CLICK DETECTED")

	if popup_stadium_intro != null:
		popup_stadium_intro.visible = false
		popup_stadium_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var popup_data = PlayerLife.load_savegame()
	popup_data["stadium_intro_seen"] = true
	PlayerLife.write_savegame(popup_data)


func _bm_compute_last_game_sales(stock: int, popularite: float, victoire: bool, grosse_affiche: bool, defaite_lourde: bool) -> int:
	var coef: float = popularite

	var ng := 1
	var ns := 1
	if save_node != null and save_node.has_method("stadium_level_str"):
		var lvl := str(save_node.call("stadium_level_str")).split(".")
		if lvl.size() == 2:
			ng = int(lvl[0])
			ns = int(lvl[1])

	if ng > 1 or (ng == 1 and ns >= 3):
		if victoire:
			coef += 0.10
		if grosse_affiche:
			coef += 0.10
		if defaite_lourde:
			coef -= 0.15

	coef = clampf(coef, 0.30, 1.20)

	var coef_final := coef * randf_range(0.85, 1.15)
	var sales := int(round(float(stock) * coef_final))
	return maxi(0, mini(stock, sales))
