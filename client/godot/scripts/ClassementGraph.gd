extends Control

const GRAPH_PADDING: float = 12.0
const GRAPH_LINE_WIDTH: float = 2.0

var ranking_series: Array = []
var total_matches: int = 22
var team_count: int = 12

func _ready() -> void:
	queue_redraw()

func set_graph_meta(total_matches_in: int, team_count_in: int) -> void:
	total_matches = max(1, total_matches_in)
	team_count = max(2, team_count_in)
	queue_redraw()

func set_ranking_series(series: Array) -> void:
	ranking_series = series.duplicate()
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

	# fond discret
	draw_rect(inner, Color(1, 1, 1, 0.035), true)

	# axes
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

	# repères horizontaux = positions de classement
	for ratio: float in [0.25, 0.50, 0.75]:
		var y: float = inner.position.y + inner.size.y * ratio
		draw_line(
			Vector2(inner.position.x, y),
			Vector2(inner.position.x + inner.size.x, y),
			Color(1, 1, 1, 0.06),
			1.0
		)

	# repères verticaux = numéro de match
	for ratio: float in [0.25, 0.50, 0.75]:
		var x: float = inner.position.x + inner.size.x * ratio
		draw_line(
			Vector2(x, inner.position.y),
			Vector2(x, inner.position.y + inner.size.y),
			Color(1, 1, 1, 0.045),
			1.0
		)

	_draw_ranking_series(inner, ranking_series, Color(0.95, 0.75, 0.22, 0.95))

func _draw_ranking_series(area: Rect2, values: Array, color: Color) -> void:
	if values.size() < 1:
		return

	var pts: Array[Vector2] = []
	var played: int = max(0, values.size() - 1)

	for match_idx in range(values.size()):
		var x_ratio: float = float(match_idx) / float(max(1, total_matches))
		var x: float = area.position.x + area.size.x * x_ratio

		var rank_value: float = clampf(float(values[match_idx]), 1.0, float(team_count))
		var y_ratio: float = (rank_value - 1.0) / float(max(1, team_count - 1))
		var y: float = area.position.y + area.size.y * y_ratio

		pts.append(Vector2(x, y))

	if pts.size() == 1:
		draw_circle(pts[0], 2.5, color)
		return

	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], color, GRAPH_LINE_WIDTH, true)

	for p in pts:
		draw_circle(p, 2.2, color)
