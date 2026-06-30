extends Control

@export var active_items_count: int = 4
@export var club_level: int = 1
@export var icons_dir: String = "res://assets/images/boutique/"
@export var row_height: float = 92.0

const ITEM_IDS := ["ballon", "casquette", "drapeau", "tshirt", "echarpe", "gourde", "mochila"]

const STOCKS_BY_LEVEL := {
	1: {"ballon": 60, "casquette": 40, "drapeau": 30, "tshirt": 25, "echarpe": 0, "gourde": 0, "mochila": 0},
	2: {"ballon": 70, "casquette": 50, "drapeau": 40, "tshirt": 30, "echarpe": 20, "gourde": 0, "mochila": 0},
	3: {"ballon": 80, "casquette": 60, "drapeau": 45, "tshirt": 35, "echarpe": 25, "gourde": 15, "mochila": 0},
	4: {"ballon": 90, "casquette": 70, "drapeau": 55, "tshirt": 40, "echarpe": 30, "gourde": 20, "mochila": 10},
}

var prices := {"ballon": 12, "casquette": 18, "drapeau": 10, "tshirt": 22, "echarpe": 16, "gourde": 8, "mochila": 25}

@onready var grid: GridContainer = $VBox/Grid
@onready var lbl_total: Label = $VBox/Bottom/LblTotalValue

func _ready() -> void:
	_build_rows()
	_refresh_total()

func _build_rows() -> void:
	# Nettoyage
	for c in grid.get_children():
		c.queue_free()

	# En-têtes (3 colonnes)
	var h_prod := Label.new()
	h_prod.text = "Produit"
	h_prod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_prod.add_theme_font_size_override("font_size", 22)

	var h_stock := Label.new()
	h_stock.text = "Stock"
	h_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_stock.add_theme_font_size_override("font_size", 22)

	var h_price := Label.new()
	h_price.text = "Prix"
	h_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_price.add_theme_font_size_override("font_size", 22)

	grid.add_child(h_prod)
	grid.add_child(h_stock)
	grid.add_child(h_price)

	# Lignes fixes
	for i in range(ITEM_IDS.size()):
		var id := ITEM_IDS[i]
		var unlocked := i < active_items_count

		# --- Colonne 1 : icon + nom ---
		var h_item := HBoxContainer.new()
		h_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_item.custom_minimum_size = Vector2(0, row_height)
		h_item.alignment = BoxContainer.ALIGNMENT_BEGIN

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _try_load_icon(id)

		var name := Label.new()
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text = _label_for(id)

		h_item.add_child(icon)
		h_item.add_child(name)

		# --- Colonne 2 : stock ---
		var lbl_stock := Label.new()
		lbl_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_stock.custom_minimum_size = Vector2(0, row_height)
		lbl_stock.text = str(_stock_for(id))

		# --- Colonne 3 : prix (-  prix  +) ---
		var h_price_row := HBoxContainer.new()
		h_price_row.custom_minimum_size = Vector2(0, row_height)
		h_price_row.alignment = BoxContainer.ALIGNMENT_CENTER

		var btn_minus := Button.new()
		btn_minus.text = "-"
		btn_minus.disabled = not unlocked
		btn_minus.pressed.connect(func():
			_set_price(id, prices.get(id, 0) - 1)
		)

		var lbl_price := Label.new()
		lbl_price.name = "LblPrice_" + id
		lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_price.custom_minimum_size = Vector2(70, 0)
		lbl_price.text = str(prices.get(id, 0))

		var btn_plus := Button.new()
		btn_plus.text = "+"
		btn_plus.disabled = not unlocked
		btn_plus.pressed.connect(func():
			_set_price(id, prices.get(id, 0) + 1)
		)

		h_price_row.add_child(btn_minus)
		h_price_row.add_child(lbl_price)
		h_price_row.add_child(btn_plus)

		# Griser si non débloqué
		if not unlocked:
			h_item.modulate = Color(1, 1, 1, 0.35)
			lbl_stock.modulate = Color(1, 1, 1, 0.35)
			h_price_row.modulate = Color(1, 1, 1, 0.35)

		# Injection dans le Grid (3 colonnes)
		grid.add_child(h_item)
		grid.add_child(lbl_stock)
		grid.add_child(h_price_row)

func _set_price(id: String, value: int) -> void:
	value = clamp(value, 0, 9999)
	prices[id] = value
	var n := grid.find_child("LblPrice_" + id, true, false)
	if n != null:
		n.text = str(value)
	_refresh_total()

func _stock_for(id: String) -> int:
	var d := STOCKS_BY_LEVEL.get(club_level, STOCKS_BY_LEVEL.get(1, {}))
	return int(d.get(id, 0))

func _refresh_total() -> void:
	var total := 0
	for id in ITEM_IDS:
		total += _stock_for(id) * int(prices.get(id, 0))
	lbl_total.text = str(total)

func _try_load_icon(id: String) -> Texture2D:
	var p := icons_dir + id + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	return null

func _label_for(id: String) -> String:
	match id:
		"ballon": return "Ballon"
		"casquette": return "Casquette"
		"drapeau": return "Drapeau"
		"tshirt": return "T-shirt"
		"echarpe": return "Écharpe"
		"gourde": return "Gourde"
		"mochila": return "Mochila"
		_: return id
