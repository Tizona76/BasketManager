extends RefCounted

const CAPACITE_STADE_NIVEAUX: Dictionary = {
	1: {
		0: 5500,
		1: 5500,
		2: 7500,
		3: 10000
	},
	2: {
		1: 13000,
		2: 17000,
		3: 25000
	},
	3: {
		1: 32000,
		2: 42000
	}
}

const COUT_NIVEAU_STADE: Dictionary = {
	"1_1": 20000,
	"1_2": 180000,
	"1_3": 300000,
	"2_1": 480000,
	"2_2": 760000,
	"2_3": 1150000,
	"3_1": 1700000,
	"3_2": 2500000,
}

const DUREE_TRAVAUX_STADE: Dictionary = {
	"1_1": 1,
	"1_2": 5,
	"1_3": 7,
	"2_1": 9,
	"2_2": 11,
	"2_3": 15,
	"3_1": 17,
	"3_2": 22,
}

const ACCELERATION_TOKENS: Dictionary = {
	"1_2": 15,
	"1_3": 21,
	"2_1": 27,
	"2_2": 33,
	"2_3": 45,
	"3_1": 51,
	"3_2": 66,
}


const SHOP_PRICE_CAP_MULT_BY_STADIUM: Dictionary = {
	"1_0": 1.00,
	"1_1": 1.00,
	"1_2": 1.25,
	"1_3": 1.25,
	"2_1": 1.25,
	"2_2": 1.25,
	"2_3": 1.25,
	"3_1": 1.25,
	"3_2": 1.25,
}

const SHOP_STOCK_MULT_BY_STADIUM: Dictionary = {
	"1_0": 1.00,
	"1_1": 1.00,
	"1_2": 1.20,
	"1_3": 1.20,
	"2_1": 1.20,
	"2_2": 1.20,
	"2_3": 1.20,
	"3_1": 1.20,
	"3_2": 1.20,
}

const TICKETING_PRICE_CAP_MULT_BY_STADIUM: Dictionary = {
	"1_0": 1.00,
	"1_1": 1.00,
	"1_2": 1.15,
	"1_3": 1.15,
	"2_1": 1.15,
	"2_2": 1.15,
	"2_3": 1.15,
	"3_1": 1.15,
	"3_2": 1.15,
}

const DUREE_TRAVAUX_DEFAUT: int = 0

const LEVEL_OVERRIDES: Dictionary = {
	"1_2": {"tabs_add": ["Cafétéria"]},
	"1_3": {"tabs_add": ["Parkings"]}
}

static func level_key(ng: int, ns: int) -> String:
	return str(ng) + "_" + str(ns)

static func get_capacity(ng: int, ns: int) -> int:
	var by_global: Variant = CAPACITE_STADE_NIVEAUX.get(ng, {})
	if typeof(by_global) != TYPE_DICTIONARY:
		return 0
	return int((by_global as Dictionary).get(ns, 0))

static func get_cost(ng: int, ns: int) -> int:
	return int(COUT_NIVEAU_STADE.get(level_key(ng, ns), 0))

static func get_duration(ng: int, ns: int) -> int:
	return int(DUREE_TRAVAUX_STADE.get(level_key(ng, ns), DUREE_TRAVAUX_DEFAUT))

static func get_all_levels() -> Array:
	return [
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(1, 3),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(2, 3),
		Vector2i(3, 1),
		Vector2i(3, 2)
	]

static func get_next_level(ng: int, ns: int) -> Variant:
	var cur: Vector2i = Vector2i(ng, ns)
	var levels: Array = get_all_levels()

	for lv in levels:
		var lv2: Vector2i = lv
		if lv2.x > cur.x or (lv2.x == cur.x and lv2.y > cur.y):
			return lv2

	return null

static func level_leq(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y <= b.y)

static func get_tabs_for_level(ng: int, ns: int, base_tabs: Array = ["Stade", "Billetterie", "Boutique"]) -> Array:
	var tabs: Array = base_tabs.duplicate()
	var cur: Vector2i = Vector2i(ng, ns)

	for raw_key in LEVEL_OVERRIDES.keys():
		var raw_key_str: String = str(raw_key)
		var parts: PackedStringArray = raw_key_str.split("_")
		if parts.size() != 2:
			continue

		var lv: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		if level_leq(lv, cur):
			var row: Variant = LEVEL_OVERRIDES.get(raw_key_str, {})
			if typeof(row) == TYPE_DICTIONARY:
				var tabs_add: Variant = (row as Dictionary).get("tabs_add", [])
				if typeof(tabs_add) == TYPE_ARRAY:
					for t in tabs_add:
						if not tabs.has(t):
							tabs.append(t)

	return tabs


func get_upgrade_duration(ng: int, ns: int) -> int:
	return int(DUREE_TRAVAUX_STADE.get(level_key(ng, ns), 0))

func get_upgrade_tokens(ng: int, ns: int) -> int:
	return int(ACCELERATION_TOKENS.get(level_key(ng, ns), 0))


static func get_shop_price_cap_mult(ng: int, ns: int) -> float:
	return float(SHOP_PRICE_CAP_MULT_BY_STADIUM.get(level_key(ng, ns), 1.0))

static func get_ticketing_price_cap_mult(ng: int, ns: int) -> float:
	return float(TICKETING_PRICE_CAP_MULT_BY_STADIUM.get(level_key(ng, ns), 1.0))


static func get_shop_stock_mult(ng: int, ns: int) -> float:
	return float(SHOP_STOCK_MULT_BY_STADIUM.get(level_key(ng, ns), 1.0))
