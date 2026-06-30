extends Control

const GRAPH_WIDTH_RATIO := 0.28
const GRAPH_HEIGHT_RATIO := 0.33
const GRAPH_RIGHT_MARGIN := 24.0
const GRAPH_CENTER_Y_OFFSET := 0.0
const GRAPH_PADDING := 12.0
const GRAPH_LINE_WIDTH := 3.0
const GRAPH_RANGE_PAD_RATIO := 0.12

var recettes_series: Array = []
var depenses_series: Array = []
var solde_series: Array = []

func _ready() -> void:
	queue_redraw()

func set_finance_series(recettes: Array, depenses: Array, solde: Array) -> void:
	recettes_series = recettes.duplicate()
	depenses_series = depenses.duplicate()
	solde_series = solde.duplicate()
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return

	var pad: float = GRAPH_PADDING
	var inner: Rect2 = Rect2(
		Vector2(pad, pad),
		Vector2(max(1.0, r.size.x - pad * 2.0), max(1.0, r.size.y - pad * 2.0))
	)

	draw_rect(inner, Color(1, 1, 1, 0.035), true)

	var bounds: Dictionary = _compute_solde_bounds()
	var min_v: float = float(bounds["min"])
	var max_v: float = float(bounds["max"])

	# Axes légers
	draw_line(
		Vector2(inner.position.x, inner.position.y + inner.size.y),
		Vector2(inner.position.x + inner.size.x, inner.position.y + inner.size.y),
		Color(1, 1, 1, 0.18),
		1.0
	)
	draw_line(
		Vector2(inner.position.x, inner.position.y),
		Vector2(inner.position.x, inner.position.y + inner.size.y),
		Color(1, 1, 1, 0.12),
		1.0
	)

	# Repères horizontaux légers
	for ratio: float in [0.25, 0.50, 0.75]:
		var y: float = inner.position.y + inner.size.y * ratio
		draw_line(
			Vector2(inner.position.x, y),
			Vector2(inner.position.x + inner.size.x, y),
			Color(1, 1, 1, 0.06),
			1.0
		)

	# Ligne zéro si visible
	if min_v < 0.0 and max_v > 0.0:
		var zero_ratio: float = (0.0 - min_v) / max(0.0001, max_v - min_v)
		var zero_y: float = inner.position.y + inner.size.y - (zero_ratio * inner.size.y)
		draw_line(
			Vector2(inner.position.x, zero_y),
			Vector2(inner.position.x + inner.size.x, zero_y),
			Color(1, 1, 1, 0.12),
			1.0
		)

	# Solde uniquement
	_draw_series(inner, solde_series, Color(0.24, 0.58, 0.95, 0.98), min_v, max_v)

func _compute_solde_bounds() -> Dictionary:
	var min_v: float = 0.0
	var max_v: float = 1.0
	var has_any: bool = false

	for v in solde_series:
		var fv: float = float(v)
		if not has_any:
			min_v = fv
			max_v = fv
			has_any = true
		else:
			min_v = min(min_v, fv)
			max_v = max(max_v, fv)

	if not has_any:
		return {"min": 0.0, "max": 1.0}

	var span: float = max_v - min_v
	if is_equal_approx(span, 0.0):
		var flat_pad: float = max(1.0, abs(max_v) * 0.10)
		return {"min": min_v - flat_pad, "max": max_v + flat_pad}

	var pad: float = max(1.0, span * GRAPH_RANGE_PAD_RATIO)
	return {"min": min_v - pad, "max": max_v + pad}

func _draw_series(area: Rect2, values: Array, color: Color, min_v: float, max_v: float) -> void:
	if values.size() < 1:
		return

	var pts: Array[Vector2] = []
	var count: int = values.size()

	for i in range(count):
		var x: float = area.position.x + (area.size.x * float(i) / float(max(1, count - 1)))
		var norm: float = (float(values[i]) - min_v) / max(0.0001, max_v - min_v)
		var y: float = area.position.y + area.size.y - (norm * area.size.y)
		pts.append(Vector2(x, y))

	if pts.size() == 1:
		draw_circle(pts[0], 4.0, color)
		return

	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], color, GRAPH_LINE_WIDTH, true)

	for p in pts:
		draw_circle(p, 3.0, color)

	# Dernier point un peu plus visible
	draw_circle(pts[pts.size() - 1], 4.2, color)
