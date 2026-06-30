extends Control

# BM_FINANCE_TEXT_PLUS2_RUNTIME_V1
func _bm_finance_apply_text_plus2_runtime(root: Node = null) -> void:
	if not _bm_finances_is_mobile_landscape():
		return
	for node_path in [
		"IncomePanel/IncomeTicketsLabel",
		"IncomePanel/IncomeTicketsValue",
		"IncomePanel/IncomeShopLabel",
		"IncomePanel/IncomeShopValue",
		"IncomePanel/IncomeSponsorsLabel",
		"IncomePanel/IncomeSponsorsValue",
		"IncomePanel/IncomeTournamentsLabel",
		"IncomePanel/IncomeTournamentsValue",
		"ExpensesPanel/ExpensesSalariesLabel",
		"ExpensesPanel/ExpensesSalariesValue",
		"ExpensesPanel/ExpensesStaffLabel",
		"ExpensesPanel/ExpensesStaffValue",
		"ExpensesPanel/ExpensesMaintenanceLabel",
		"ExpensesPanel/ExpensesMaintenanceValue",
		"ExpensesPanel/ExpensesStadiumWorksLabel",
		"ExpensesPanel/ExpensesStadiumWorksValue"
	]:
		var row_label := get_node_or_null(node_path) as Label
		if row_label != null:
			row_label.add_theme_font_size_override("font_size", 24)

const PL = preload("res://scripts/PlayerLife.gd")


func _i18n_lang2() -> String:
	var loc := TranslationServer.get_locale()
	if loc == null:
		return "en"
	var t := String(loc)
	if t.length() >= 2:
		return t.substr(0, 2).to_lower()
	return t.to_lower()

func _i18n_fallback(key: String) -> String:
	var lang := _i18n_lang2()
	var map := {
		"btn.back": {
			"fr": "Retour",
			"en": "Back",
			"es": "Volver",
			"it": "Indietro",
			"pt": "Voltar"
		},
		"finance.title": {
			"fr": "Finances",
			"en": "Finance",
			"es": "Finanzas",
			"it": "Finanze",
			"pt": "Finanças"
		},
		"finance.income.title": {
			"fr": "Recettes",
			"en": "Income",
			"es": "Ingresos",
			"it": "Entrate",
			"pt": "Receitas"
		},
		"finance.income.tickets": {
			"fr": "Billetterie",
			"en": "Tickets",
			"es": "Entradas",
			"it": "Biglietti",
			"pt": "Bilhetes"
		},
		"finance.income.shop": {
			"fr": "Boutique",
			"en": "Shop",
			"es": "Tienda",
			"it": "Negozio",
			"pt": "Loja"
		},
		"finance.income.sponsors": {
			"fr": "Sponsors",
			"en": "Sponsors",
			"es": "Patrocinadores",
			"it": "Sponsor",
			"pt": "Patrocinadores"
		},
		"finance.expenses.title": {
			"fr": "Dépenses",
			"en": "Expenses",
			"es": "Gastos",
			"it": "Spese",
			"pt": "Despesas"
		},
		"finance.expenses.salaries": {
			"fr": "Salaires",
			"en": "Salaries",
			"es": "Salarios",
			"it": "Stipendi",
			"pt": "Salários"
		},
		"finance.expenses.staff": {
			"fr": "Staff",
			"en": "Staff",
			"es": "Personal",
			"it": "Staff",
			"pt": "Equipe"
		},
		"finance.expenses.maintenance": {
			"fr": "Achat boutique",
			"en": "Shop purchases",
			"es": "Compras tienda",
			"it": "Acquisti negozio",
			"pt": "Compras loja"
		},
		"finance.expenses.stadium_works": {
			"fr": "Travaux Stade",
			"en": "Stadium works",
			"es": "Obras del estadio",
			"it": "Lavori stadio",
			"pt": "Obras do estádio"
		},
		"finance.balance.title": {
			"fr": "Solde",
			"en": "Balance",
			"es": "Saldo",
			"it": "Saldo",
			"pt": "Saldo"
			},
			"finance.graph.title": {
				"fr": "Tendance du solde",
				"en": "Balance trend",
				"es": "Tendencia del saldo",
				"it": "Andamento del saldo",
				"pt": "Tendência do saldo"
			},
			"finance.trend.shop_price_volume": {
				"fr": "Des prix boutique élevés peuvent réduire le volume des ventes",
				"en": "High shop prices may reduce sales volume",
				"es": "Los precios altos de la tienda pueden reducir el volumen de ventas",
				"it": "Prezzi alti nel negozio possono ridurre il volume delle vendite",
				"pt": "Preços altos na loja podem reduzir o volume de vendas"
			}
		}
	if map.has(key):
		var dict: Dictionary = map[key]
		if dict.has(lang):
			return dict[lang]
		if dict.has("en"):
			return dict["en"]
	return key

func _tr_or_fallback(key: String) -> String:
	var v := tr(key)
	if v == key:
		return _i18n_fallback(key)
	return v

const GRAPH_WIDTH_RATIO := 0.28
const GRAPH_HEIGHT_RATIO := 0.33
const GRAPH_RIGHT_MARGIN := 24.0
const GRAPH_CENTER_Y_OFFSET := 0.0
const GRAPH_PADDING := 12.0
const GRAPH_LINE_WIDTH := 2.0

class RevenueDonutChart:
	extends Control

	var title: String = ""
	var percent: float = 0.0
	var accent: Color = Color(0.20, 0.85, 0.35, 1)

	func set_data(new_title: String, value: int, total: int, new_accent: Color) -> void:
		title = new_title
		accent = new_accent
		percent = 0.0 if total <= 0 else clampf(float(value) / float(total), 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.44)
		var radius: float = minf(size.x, size.y) * 0.28
		var width := 12.0
		draw_arc(center, radius, -PI * 0.5, PI * 1.5, 96, Color(1, 1, 1, 0.16), width, true)
		if percent > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * percent, 96, accent, width, true)
		var font := get_theme_default_font()
		var percent_text := str(int(round(percent * 100.0))) + "%"
		var percent_size := font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string(font, center - Vector2(percent_size.x * 0.5, -7.0), percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 1))
		var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, Vector2((size.x - title_size.x) * 0.5, size.y - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))

@onready var lbl_title: Label = $LblTitle
@onready var btn_retour: Button = $BtnRetour
@onready var lbl_balance_title: Label = $BalancePanel/BalanceTitle
@onready var finance_graph_panel: ColorRect = $FinanceGraphPanel
@onready var finance_graph_title: Label = $FinanceGraphPanel/FinanceGraphTitle
@onready var finance_graph: Control = $FinanceGraphPanel/FinanceGraph

@onready var lbl_expenses_title: Label = $ExpensesPanel/ExpensesTitle

@onready var lbl_income_title: Label = $IncomePanel/IncomeTitle

@onready var income_total: Label = $IncomePanel/IncomeTotal
@onready var income_tickets_value: Label = $IncomePanel/IncomeTicketsValue
@onready var income_shop_value: Label = $IncomePanel/IncomeShopValue
@onready var income_sponsors_value: Label = $IncomePanel/IncomeSponsorsValue
@onready var expenses_total: Label = $ExpensesPanel/ExpensesTotal
@onready var expenses_salaries_value: Label = $ExpensesPanel/ExpensesSalariesValue
@onready var expenses_staff_value: Label = $ExpensesPanel/ExpensesStaffValue
@onready var expenses_maintenance_value: Label = $ExpensesPanel/ExpensesMaintenanceValue
@onready var expenses_stadium_works_value: Label = $ExpensesPanel/ExpensesStadiumWorksValue
@onready var balance_value: Label = $BalancePanel/BalanceValue
@onready var income_tournaments_label: Label = $IncomePanel/IncomeTournamentsLabel
@onready var income_tournaments_value: Label = $IncomePanel/IncomeTournamentsValue
@onready var lbl_hud_level: Label = get_node_or_null("HudProgressPanel/HudVBox/LblHudLevel") as Label
@onready var lbl_hud_xp: Label = get_node_or_null("HudProgressPanel/HudVBox/LblHudXp") as Label
@onready var lbl_hud_tokens: Label = get_node_or_null("HudProgressPanel/HudVBox/TokensRow/LblHudTokens") as Label
var _donut_tickets: RevenueDonutChart = null
var _donut_shop: RevenueDonutChart = null
var _donut_sponsors: RevenueDonutChart = null
var _donut_tournaments: RevenueDonutChart = null
var _expense_donut_salaries: RevenueDonutChart = null
var _expense_donut_staff: RevenueDonutChart = null
var _expense_donut_maintenance: RevenueDonutChart = null
var _expense_donut_stadium_works: RevenueDonutChart = null
func _apply_tr_to_named_node(node_name: String, key: String) -> void:
	var n: Node = find_child(node_name, true, false)
	if n == null:
		return
	var v: String = _tr_or_fallback(key)
	if n is Label:
		(n as Label).text = v
	elif n is Button:
		(n as Button).text = v
	else:
		n.set("text", v)
# --- end i18n helpers ---



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


func _bm_finances_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _bm_finances_is_mobile_landscape() -> bool:
	var vp := get_viewport_rect().size
	return _bm_finances_is_mobile_layout() and vp.x > vp.y


func _bm_finances_apply_mobile_landscape_hud_layout() -> void:
	if not _bm_finances_is_mobile_landscape():
		return
	await get_tree().process_frame
	var hud := get_node_or_null("HudProgressPanel") as Control
	if hud == null:
		return

	if not hud.has_meta("bm_finances_mobile_hud_scaled_done"):
		hud.set_meta("bm_finances_mobile_hud_scaled_done", true)
		hud.scale = Vector2(1.15, 1.15)
		hud.size = Vector2(220.0, 128.0)
		hud.custom_minimum_size = Vector2(maxf(1.0, 220.0 * 0.72), 128.0 * 1.15)

	if not hud.has_meta("bm_finances_mobile_hud_text_plus2_done"):
		hud.set_meta("bm_finances_mobile_hud_text_plus2_done", true)
		for lbl in [lbl_hud_level, lbl_hud_xp, lbl_hud_tokens]:
			if lbl != null:
				var fs: int = int(lbl.get_theme_font_size("font_size"))
				if fs > 0:
					lbl.add_theme_font_size_override("font_size", fs + 2)

	var vp := get_viewport_rect().size
	var margin_right := 40.0
	var hud_w: float = maxf(hud.size.x, hud.custom_minimum_size.x)
	hud.anchor_left = 1.0
	hud.anchor_right = 1.0
	hud.offset_left = -hud_w - margin_right
	hud.offset_right = -margin_right
	hud.position.x = vp.x - (hud_w * hud.scale.x) - margin_right


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
	btn.add_theme_font_size_override("font_size", 24 if _bm_finances_is_mobile_layout() else 22)

func _apply_i18n() -> void:
	if btn_retour != null:
		btn_retour.text = _tr_or_fallback("btn.back")
		_bm_apply_back_button_style(btn_retour)
	if lbl_title != null:
		lbl_title.text = _tr_or_fallback("finance.title")

	var n: Node

	n = get_node_or_null("IncomePanel/IncomeTitle")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.income.title")

	n = get_node_or_null("IncomePanel/IncomeTicketsLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.income.tickets")

	n = get_node_or_null("IncomePanel/IncomeShopLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.income.shop")

	n = get_node_or_null("IncomePanel/IncomeSponsorsLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.income.sponsors")

	n = get_node_or_null("ExpensesPanel/ExpensesTitle")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.expenses.title")

	n = get_node_or_null("ExpensesPanel/ExpensesSalariesLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.expenses.salaries")

	n = get_node_or_null("ExpensesPanel/ExpensesStaffLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.expenses.tournament_fees")

	n = get_node_or_null("ExpensesPanel/ExpensesMaintenanceLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.expenses.maintenance")

	n = get_node_or_null("ExpensesPanel/ExpensesStadiumWorksLabel")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.expenses.stadium_works")

	n = get_node_or_null("BalancePanel/BalanceTitle")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.balance.title")

	n = get_node_or_null("FinanceGraphPanel/FinanceGraphTitle")
	if n != null and n is Label:
		(n as Label).text = _tr_or_fallback("finance.graph.title")

func _bm_finance_force_popularity_white() -> void:
	for n in find_children("PopularityBadge", "Label", true, false):
		var lbl := n as Label
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))


func _ready() -> void:
	print("[FINANCES] ready")

	# Titres des blocs (traductions)
	if lbl_income_title != null:
		lbl_income_title.text = tr("finance.income.title")
	if lbl_expenses_title != null:
		lbl_expenses_title.text = tr("finance.expenses.title")
	if lbl_balance_title != null:
		lbl_balance_title.text = tr("finance.balance.title")
	if income_tournaments_label != null:
		income_tournaments_label.text = tr("finance.income.tournaments")

	if btn_retour != null and not btn_retour.pressed.is_connected(_on_retour_pressed):
		btn_retour.pressed.connect(_on_retour_pressed)

	_apply_i18n()
	_bm_finance_force_popularity_white()
	_bm_finance_apply_text_plus2_runtime(self)
	call_deferred("_bm_finance_apply_text_plus2_runtime")
	call_deferred("_bm_finance_force_popularity_white")
	_apply_graph_layout()

	print("[I18N TEST] btn.back=", _tr_or_fallback("btn.back"))
	print("[I18N TEST] finance.title=", _tr_or_fallback("finance.title"))

	# Titres Recettes / Dépenses / Solde (tr() + fallback local)
	_apply_tr_to_named_node("IncomeTitle", "finance.income.title")
	_apply_tr_to_named_node("ExpensesTitle", "finance.expenses.title")
	_apply_tr_to_named_node("BalanceTitle", "finance.balance.title")
	_apply_tr_to_named_node("IncomeTournamentsLabel", "finance.income.tournaments")
	call_deferred("_apply_finance_music")
	call_deferred("_refresh_amounts_from_save")
	call_deferred("_bm_finances_apply_mobile_landscape_hud_layout")
	call_deferred("_bm_finance_apply_text_plus2_guard")


func _apply_graph_layout() -> void:
	if finance_graph_panel == null:
		return

	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var graph_w := vp.x * GRAPH_WIDTH_RATIO
	var graph_h := vp.y * GRAPH_HEIGHT_RATIO
	var center_y := GRAPH_CENTER_Y_OFFSET

	finance_graph_panel.anchor_left = 1.0
	finance_graph_panel.anchor_right = 1.0
	finance_graph_panel.anchor_top = 0.5
	finance_graph_panel.anchor_bottom = 0.5

	finance_graph_panel.offset_left = -GRAPH_RIGHT_MARGIN - graph_w
	finance_graph_panel.offset_right = -GRAPH_RIGHT_MARGIN
	finance_graph_panel.offset_top = -graph_h / 2.0 + center_y
	finance_graph_panel.offset_bottom = graph_h / 2.0 + center_y

	var panel_right := vp.x * 0.5 - 40.0
	for pnl in [get_node_or_null("IncomePanel") as Control, get_node_or_null("ExpensesPanel") as Control]:
		if pnl != null:
			pnl.offset_right = panel_right - vp.x * 0.5 - 35.0

	_ensure_revenue_donut_charts()
	_place_revenue_donut_charts()
	_ensure_expense_donut_charts()
	_place_expense_donut_charts()


func _ensure_revenue_donut_charts() -> void:
	if _donut_tickets == null:
		_donut_tickets = RevenueDonutChart.new()
		_donut_tickets.name = "FinanceDonutTickets"
		add_child(_donut_tickets)
	if _donut_shop == null:
		_donut_shop = RevenueDonutChart.new()
		_donut_shop.name = "FinanceDonutShop"
		add_child(_donut_shop)
	if _donut_sponsors == null:
		_donut_sponsors = RevenueDonutChart.new()
		_donut_sponsors.name = "FinanceDonutSponsors"
		add_child(_donut_sponsors)
	if _donut_tournaments == null:
		_donut_tournaments = RevenueDonutChart.new()
		_donut_tournaments.name = "FinanceDonutTournaments"
		add_child(_donut_tournaments)


func _place_revenue_donut_charts() -> void:
	if _donut_tickets == null or _donut_shop == null or _donut_sponsors == null or _donut_tournaments == null:
		return
	var graph_left := finance_graph_panel.global_position.x if finance_graph_panel != null else get_viewport_rect().size.x * 0.70
	var chart_size := Vector2(118, 118)
	var x := graph_left - chart_size.x - 185.0
	var y := 96.0
	var spacing_x := 120.0
	var spacing_y := 122.0
	var charts := [_donut_tickets, _donut_shop, _donut_sponsors, _donut_tournaments]
	var positions := [
		Vector2(x, y),
		Vector2(x + spacing_x, y),
		Vector2(x, y + spacing_y),
		Vector2(x + spacing_x, y + spacing_y)
	]
	for i in range(charts.size()):
		var chart = charts[i]
		chart.set_anchors_preset(Control.PRESET_TOP_LEFT)
		chart.position = positions[i]
		chart.size = chart_size
		chart.z_index = 2


func _ensure_expense_donut_charts() -> void:
	if _expense_donut_salaries == null:
		_expense_donut_salaries = RevenueDonutChart.new()
		_expense_donut_salaries.name = "ExpenseDonutSalaries"
		add_child(_expense_donut_salaries)
	if _expense_donut_staff == null:
		_expense_donut_staff = RevenueDonutChart.new()
		_expense_donut_staff.name = "ExpenseDonutStaff"
		add_child(_expense_donut_staff)
	if _expense_donut_maintenance == null:
		_expense_donut_maintenance = RevenueDonutChart.new()
		_expense_donut_maintenance.name = "ExpenseDonutMaintenance"
		add_child(_expense_donut_maintenance)
	if _expense_donut_stadium_works == null:
		_expense_donut_stadium_works = RevenueDonutChart.new()
		_expense_donut_stadium_works.name = "ExpenseDonutStadiumWorks"
		add_child(_expense_donut_stadium_works)


func _place_expense_donut_charts() -> void:
	if _expense_donut_salaries == null or _expense_donut_staff == null or _expense_donut_maintenance == null or _expense_donut_stadium_works == null:
		return
	var graph_left := finance_graph_panel.global_position.x if finance_graph_panel != null else get_viewport_rect().size.x * 0.70
	var chart_size := Vector2(118, 118)
	var x := graph_left - chart_size.x - 185.0
	var y := 360.0
	var spacing_x := 120.0
	var spacing_y := 122.0
	var charts := [_expense_donut_salaries, _expense_donut_staff, _expense_donut_maintenance, _expense_donut_stadium_works]
	var positions := [
		Vector2(x, y),
		Vector2(x + spacing_x, y),
		Vector2(x, y + spacing_y),
		Vector2(x + spacing_x, y + spacing_y)
	]
	for i in range(charts.size()):
		var chart = charts[i]
		chart.set_anchors_preset(Control.PRESET_TOP_LEFT)
		chart.position = positions[i]
		chart.size = chart_size
		chart.z_index = 2


func _build_symbolic_series(value: int) -> Array:
	var v: float = float(value)
	if v < 0.0:
		v = 0.0
	if v <= 0.0:
		return [0.0, 0.0, 0.0, 0.0, 0.0]
	return [
		float(round(v * 0.22)),
		float(round(v * 0.46)),
		float(round(v * 0.63)),
		float(round(v * 0.84)),
		v
	]



func _get_finance_history_series_from_save(save: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"recettes": [],
		"depenses": [],
		"solde": [],
	}

	if typeof(save) != TYPE_DICTIONARY:
		return out

	if save.has("finance_history_recettes") and typeof(save["finance_history_recettes"]) == TYPE_ARRAY:
		for v in save["finance_history_recettes"]:
			(out["recettes"] as Array).append(float(v))

	if save.has("finance_history_depenses") and typeof(save["finance_history_depenses"]) == TYPE_ARRAY:
		for v in save["finance_history_depenses"]:
			(out["depenses"] as Array).append(float(v))

	if save.has("finance_history_solde") and typeof(save["finance_history_solde"]) == TYPE_ARRAY:
		for v in save["finance_history_solde"]:
			(out["solde"] as Array).append(float(v))

	return out


func _push_graph_data(recettes: int, depenses: int, solde: int) -> void:
	if finance_graph == null:
		return
	if not finance_graph.has_method("set_finance_series"):
		return

	var recettes_series := _build_symbolic_series(recettes)
	var depenses_series := _build_symbolic_series(depenses)
	var solde_series := _build_symbolic_series(abs(solde))

	if solde < 0 and solde_series.size() >= 5:
		solde_series = [
			-solde_series[0],
			-solde_series[1],
			-solde_series[2],
			-solde_series[3],
			-solde_series[4]
		]

	finance_graph.call("set_finance_series", recettes_series, depenses_series, solde_series)


func _stop_finance_music() -> void:
	# 1) Stop AudioManager (si présent)
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		am = get_node_or_null("/root/Audio")
	if am != null:
		if am.has_method("stop_music"):
			am.call("stop_music")
		elif am.has_method("stop"):
			am.call("stop")
		elif am.has_method("stop_all"):
			am.call("stop_all")

	# 2) Stop player local (si créé)
	var local := get_node_or_null("FinanceMusic") as AudioStreamPlayer
	if local != null:
		local.stop()
		local.queue_free()


func _on_retour_pressed() -> void:
	var d_unlock: Dictionary = PL.load_savegame()
	if typeof(d_unlock) == TYPE_DICTIONARY:
		d_unlock["early_flow_finances_unlocked"] = true
		PL.write_savegame(d_unlock)
		print("[FINANCES][EARLY_FLOW] Finances unlocked for Menu")
	print("[FINANCES] Retour -> go Management")
	_stop_finance_music()
	call_deferred("_go_management")

func _go_management() -> void:
	var tree := get_tree()
	if tree == null:
		print("[FINANCES][ERR] get_tree() is null")
		return
	var path := "res://scenes/Menu.tscn"
	print("[FINANCES] change_scene_to_file path=", path, " exists=", ResourceLoader.exists(path))
	var err := tree.change_scene_to_file(path)
	print("[FINANCES] change_scene_to_file err=", err)

# BM_FINANCE_MUSIC_V1
const FINANCE_MUSIC_PATH := "res://audio/music/finance.mp3"

func _apply_finance_music() -> void:
	var path := FINANCE_MUSIC_PATH

	# 1) Try AudioManager at /root/AudioManager
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		# Prefer child AudioStreamPlayer named Music
		var music_node := am.get_node_or_null("Music")
		if music_node != null and music_node is AudioStreamPlayer:
			var pl := music_node as AudioStreamPlayer
			pl.stop()
			var st := load(path)
			if st != null:
				pl.stream = st
				pl.play()
			return

		# Try common methods (stop then play)
		if am.has_method("stop_music"):
			am.call("stop_music")
		elif am.has_method("stop"):
			am.call("stop")
		elif am.has_method("stop_current_music"):
			am.call("stop_current_music")

		if am.has_method("play_music"):
			am.call("play_music", path)
			return
		elif am.has_method("play_music_path"):
			am.call("play_music_path", path)
			return
		elif am.has_method("set_music"):
			am.call("set_music", path)
			return
		elif am.has_method("music_play"):
			am.call("music_play", path)
			return

		# Last resort: find any AudioStreamPlayer inside AudioManager
		var found := am.find_child("", true, true)
		if found != null and found is AudioStreamPlayer:
			var pl2 := found as AudioStreamPlayer
			pl2.stop()
			var st2 := load(path)
			if st2 != null:
				pl2.stream = st2
				pl2.play()
			return

	# 2) Fallback local player
	var local := AudioStreamPlayer.new()
	local.name = "FinanceMusic"
	var st3 := load(path)
	if st3 != null:
		local.stream = st3
		add_child(local)
		local.play()


func _fmt_eur(v: int) -> String:
	var sign := ""
	var n := v

	if n < 0:
		sign = "-"
		n = -n

	var s := str(n)
	var result := ""
	var count := 0

	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count == 3 and i != 0:
			result = " " + result
			count = 0

	return sign + result + " €"


func _refresh_amounts_from_save() -> void:
	var save := PL.load_savegame()
	PL.ensure_finance_schema(save)

	var tickets := int(save.get("total_billetterie", 0))
	var shop := int(save.get("total_boutique", 0))
	var sponsors := int(save.get("total_sponsors", 0))
	var tournois := int(save.get("total_tournois", 0))

	var salaires := int(save.get("total_salaires", save.get("salary_total_per_match", 0)))
	var depenses_total := int(save.get("total_depenses", 0))
	var tournois_fees_total := int(save.get("tournois_fees_total", 0))
	var shop_restock_cost := int(save.get("total_shop_restock_cost", 0))

	var travaux_stade := 0
	if save.has("finance") and typeof(save["finance"]) == TYPE_DICTIONARY:
		travaux_stade = int((save["finance"] as Dictionary).get("total_cout_evolution_stade", 0))

	# Expenses affiché = somme des 4 lignes de détail visibles.
	var prematch := (int(save.get("season_round", 0)) <= 0)
	var depenses_aff := salaires + tournois_fees_total + shop_restock_cost + travaux_stade

	var recettes := tickets + shop + sponsors + tournois
	var solde := recettes - depenses_aff

	print("[FINANCES] tickets=", tickets, " shop=", shop, " sponsors=", sponsors, " tournois=", tournois, " tournois=", tournois, " salaires=", salaires, " travaux_stade=", travaux_stade, " depenses_total=", depenses_total, " depenses_aff=", depenses_aff, " recettes=", recettes, " solde=", solde)

	if income_total != null:
		income_total.text = _fmt_eur(recettes)
	
	call_deferred("_bm_finance_apply_text_plus2_runtime")
	if income_tickets_value != null:
		income_tickets_value.text = _fmt_eur(tickets)
	if income_shop_value != null:
		income_shop_value.text = _fmt_eur(shop)
	if income_sponsors_value != null:
		income_sponsors_value.text = _fmt_eur(sponsors)
	if income_tournaments_value != null:
		income_tournaments_value.text = _fmt_eur(tournois)

	_ensure_revenue_donut_charts()
	if _donut_tickets != null:
		_donut_tickets.set_data(_tr_or_fallback("finance.income.tickets"), tickets, recettes, Color(0.42, 0.92, 1.00, 1))
	if _donut_shop != null:
		_donut_shop.set_data(_tr_or_fallback("finance.income.shop"), shop, recettes, Color(1.00, 0.72, 0.20, 1))
	if _donut_sponsors != null:
		_donut_sponsors.set_data(_tr_or_fallback("finance.income.sponsors"), sponsors, recettes, Color(0.20, 0.95, 0.55, 1))
	if _donut_tournaments != null:
		_donut_tournaments.set_data(_tr_or_fallback("finance.income.tournaments"), tournois, recettes, Color(0.70, 0.48, 1.00, 1))

	if expenses_total != null:
		expenses_total.text = _fmt_eur(depenses_aff)
	# IMPORTANT: afficher ici le cumul des salaires payés match après match
	if expenses_salaries_value != null:
		expenses_salaries_value.text = _fmt_eur(salaires)
	if expenses_staff_value != null:
		expenses_staff_value.text = _fmt_eur(tournois_fees_total)
	if expenses_maintenance_value != null:
		expenses_maintenance_value.text = _fmt_eur(shop_restock_cost)
	if expenses_stadium_works_value != null:
		expenses_stadium_works_value.text = _fmt_eur(travaux_stade)

	_ensure_expense_donut_charts()
	if _expense_donut_salaries != null:
		_expense_donut_salaries.set_data(_tr_or_fallback("finance.expenses.salaries"), salaires, depenses_aff, Color(0.92, 0.28, 0.28, 1))
	if _expense_donut_staff != null:
		_expense_donut_staff.set_data(_tr_or_fallback("finance.expenses.tournament_fees"), tournois_fees_total, depenses_aff, Color(1.00, 0.55, 0.25, 1))
	if _expense_donut_maintenance != null:
		_expense_donut_maintenance.set_data(_tr_or_fallback("finance.expenses.maintenance"), shop_restock_cost, depenses_aff, Color(0.95, 0.85, 0.30, 1))
	if _expense_donut_stadium_works != null:
		_expense_donut_stadium_works.set_data(_tr_or_fallback("finance.expenses.stadium_works"), travaux_stade, depenses_aff, Color(0.75, 0.40, 1.00, 1))

	_bm_update_finance_trend_text(recettes, depenses_aff, tickets, shop, salaires, travaux_stade, solde)

	var club_level_ui: int = PL.get_club_level(save)
	var club_xp_ui: int = PL.get_club_xp(save)
	var tokens_ui: int = PL.get_tokens(save)
	if lbl_hud_level != null:
		lbl_hud_level.text = "Lv " + str(club_level_ui)
	if lbl_hud_xp != null:
		lbl_hud_xp.text = "XP " + str(club_xp_ui)
	if lbl_hud_tokens != null:
		lbl_hud_tokens.text = "Tokens " + str(tokens_ui)

	if balance_value != null:
		balance_value.text = _fmt_eur(solde)
		# Solde: rouge si negatif, vert si positif
		var c := Color(0.20, 0.80, 0.20, 1.0)
		if solde < 0:
			c = Color(0.90, 0.25, 0.25, 1.0)
		balance_value.add_theme_color_override("font_color", c)
		if solde < 0:
			balance_value.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
		else:
			balance_value.add_theme_color_override("font_color", Color(0.15, 0.65, 0.25))
		

	var finance_hist: Dictionary = _get_finance_history_series_from_save(save)
	var hist_recettes: Array = finance_hist.get("recettes", [])
	var hist_depenses: Array = finance_hist.get("depenses", [])
	var hist_solde: Array = finance_hist.get("solde", [])

	if finance_graph != null and finance_graph.has_method("set_finance_series") and hist_recettes.size() > 0 and hist_depenses.size() > 0 and hist_solde.size() > 0:
		finance_graph.call("set_finance_series", hist_recettes, hist_depenses, hist_solde)
	else:
		_push_graph_data(recettes, depenses_aff, solde)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		call_deferred("_apply_i18n")

	if what == NOTIFICATION_RESIZED:
		call_deferred("_apply_graph_layout")
		call_deferred("_bm_finances_apply_mobile_landscape_hud_layout")

	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("_apply_graph_layout")
		call_deferred("_refresh_amounts_from_save")
		call_deferred("_bm_finances_apply_mobile_landscape_hud_layout")

func _bm_finance_apply_text_plus2_guard() -> void:
	var frames := 6
	while frames > 0:
		await get_tree().process_frame
		
		frames -= 1


# BM_FINANCE_TREND_TEXT_V1
func _bm_get_finance_trend_prefix(income: int, expenses: int) -> String:
	var diff := income - expenses
	if diff < -500:
		return "finance.trend.negative."
	elif diff > 500:
		return "finance.trend.positive."
	return "finance.trend.stable."

func _bm_finance_trend_fallback_text(prefix: String, idx: int) -> String:
	var negative := [
		_tr_or_fallback("finance.trend.shop_price_volume"),
		"Expenses outpacing income (high salaries)",
		"Losing money each match (low ticket sales)",
		"Costs too high (player wages)",
		"Revenue too low (poor pricing)",
		"Finances declining (weak attendance)",
		"Negative balance growing (high expenses)",
		"Budget under pressure (low income)",
		"Losses increasing (shop underperforming)",
		"Spending too much (no sponsor income)",
		"Income dropping (fan interest falling)"
	]
	var stable := [
		"Finances stable (balanced income and costs)",
		"No major change (steady performance)",
		"Income matches expenses",
		"Stable revenue (consistent ticket sales)",
		"Balanced budget (no major shifts)",
		"Steady finances (no clear trend)",
		"Performance holding steady",
		"No growth, no loss (neutral phase)",
		"Finances unchanged (same strategy)",
		"Stable situation (predictable results)"
	]
	var positive := [
		"Revenue growing (ticket pricing working)",
		"Profits increasing (strong attendance)",
		"Income exceeds expenses",
		"Finances improving (good strategy)",
		"Positive balance rising",
		"Strong revenue (fans engaged)",
		"Good profit (optimized pricing)",
		"Growth accelerating (better results)",
		"Income boosted (shop performing well)",
		"Financial situation improving"
	]
	idx = clampi(idx, 1, 10) - 1
	if prefix == "finance.trend.negative.":
		return negative[idx]
	if prefix == "finance.trend.positive.":
		return positive[idx]
	return stable[idx]

func _bm_pick_finance_comment(keys: Array[String], seed: int) -> String:
	if keys.is_empty():
		return ""
	var key := keys[posmod(seed, keys.size())]
	return _tr_or_fallback(key)

func _bm_update_finance_trend_text(income: int, expenses: int, tickets: int = -1, shop: int = -1, salaries: int = -1, stadium_works: int = -1, balance_override: int = 2147483647) -> void:
	var panel := get_node_or_null("FinanceGraphPanel") as Control
	if panel == null:
		return

	var lbl := panel.get_node_or_null("FinanceTrendText") as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = "FinanceTrendText"
		panel.add_child(lbl)

	var balance := income - expenses
	if balance_override != 2147483647:
		balance = balance_override

	var seed := int(Time.get_ticks_msec() % 100000)
	var expense_base := maxi(expenses, 1)
	var income_base := maxi(income, 1)
	var value := ""
	if stadium_works > int(round(float(expense_base) * 0.25)):
		value = _bm_pick_finance_comment(["finance.comment.stadium_cost.1", "finance.comment.stadium_cost.2", "finance.comment.stadium_cost.3"], seed + 1)
	elif salaries > int(round(float(expense_base) * 0.50)):
		value = _bm_pick_finance_comment(["finance.comment.salaries_pressure.1", "finance.comment.salaries_pressure.2", "finance.comment.salaries_pressure.3"], seed + 2)
	elif tickets > int(round(float(income_base) * 0.50)):
		value = _bm_pick_finance_comment(["finance.comment.tickets_positive.1", "finance.comment.tickets_positive.2", "finance.comment.tickets_positive.3"], seed + 3)
	elif shop > int(round(float(income_base) * 0.25)):
		value = _bm_pick_finance_comment(["finance.comment.shop_positive.1", "finance.comment.shop_positive.2", "finance.comment.shop_positive.3"], seed + 4)
	else:
		value = _bm_pick_finance_comment(["finance.comment.stable.1", "finance.comment.stable.2", "finance.comment.stable.3"], seed + 5)

	lbl.text = "“" + value + "”"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	lbl.modulate = Color(1, 1, 1, 0.95)
	# Apply modern font (Inter)
	var font = load("res://fonts/Inter-Regular.ttf")
	if font != null:
		lbl.add_theme_font_override("font", font)

	lbl.anchor_left = 0.05
	lbl.anchor_right = 0.95
	lbl.anchor_top = 1.02
	lbl.anchor_bottom = 1.22
	lbl.offset_left = 0
	lbl.offset_right = 0
	lbl.offset_top = 0
	lbl.offset_bottom = 0
