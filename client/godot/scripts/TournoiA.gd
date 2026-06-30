extends Control

const Save := preload("res://scripts/Save.gd")
const PlayerLife := preload("res://scripts/PlayerLife.gd")
const TuningData := preload("res://scripts/TuningData.gd")

var equipes := ["Bulls", "Panthères", "Toros", "Hawks", "Wolves", "Sharks", "Lions", "Kings"]
var round_actuel := 0
var quarts := []
var demis := []
var finale := []
var vainqueur := ""
var quarts_resultats := []
var demis_resultats := []
var finale_resultats := []
var vainqueur_resultat := ""

const TOURNAMENT_ID_MAP := {
	"TOURNOI_A": "tournoi_a",
	"INTERMEDIATE": "intermediaire",
	"ELITE": "elite"
}

const MONEY_TICK_SFX_CANDIDATES := [
	"res://audio/sfx/money_count.mp3",
	"res://audio/sfx/cash_count.mp3",
	"res://audio/sfx/coin.mp3",
	"res://audio/sfx/click.mp3"
]

var _tournament_reward_granted: bool = false
var _money_tick_player: AudioStreamPlayer = null


@onready var lbl_title: Label = get_node("UI/LblTitle") as Label
@onready var lbl_round1: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColRound1/LblRound1") as RichTextLabel
@onready var lbl_round2: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColRound2/LblRound2") as RichTextLabel
@onready var lbl_round3: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColRound3/LblRound3") as RichTextLabel
@onready var lbl_winner: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColWinner/LblWinner") as RichTextLabel
@onready var btn_simuler_tour: Button = get_node("UI/BtnSimulerTour") as Button
@onready var btn_retour: Button = get_node("UI/BtnRetour") as Button
@onready var ui_root: Control = get_node("UI") as Control

func _line_centered(text: String) -> String:
	return "[center]" + str(text).strip_edges() + "[/center]"

func _vs_centered() -> String:
	return "[center][font_size=18][color=#FFFFFF]— VS —[/color][/font_size][/center]"

func _bm_force_tournament_text_white(root: Node) -> void:
	if root == null:
		return
	if root is Label:
		(root as Label).add_theme_color_override("font_color", Color(1, 1, 1, 1))
	elif root is RichTextLabel:
		(root as RichTextLabel).add_theme_color_override("default_color", Color(1, 1, 1, 1))
	elif root is Button:
		var btn := root as Button
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 1))
	for child in root.get_children():
		_bm_force_tournament_text_white(child)

func _ensure_bracket_line(name: String) -> ColorRect:
	if ui_root == null:
		return null
	var n := ui_root.get_node_or_null(name) as ColorRect
	if n == null:
		n = ColorRect.new()
		n.name = name
		n.color = Color(0.12, 0.16, 0.22, 1.0)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.z_index = 100
		ui_root.add_child(n)
	return n

func _hide_all_bracket_lines() -> void:
	if ui_root == null:
		return
	for n in ["LineR2A", "LineR2B", "LineR2C", "LineR2D", "LineR3A", "LineR3B", "LineW"]:
		var line := ui_root.get_node_or_null(n) as ColorRect
		if line != null:
			line.visible = false

func _show_bracket_line(name: String, label: RichTextLabel, line_index: int, total_lines: int) -> void:
	if ui_root == null or label == null:
		return
	if total_lines <= 0:
		return

	var line := _ensure_bracket_line(name)
	if line == null:
		return

	var label_pos := label.global_position - ui_root.global_position

	var content_h := float(label.get_content_height())
	if content_h <= 0.0:
		content_h = label.size.y
	if content_h <= 0.0:
		content_h = 1.0

	var one_h := content_h / float(total_lines)
	var y := label_pos.y + (float(line_index) + 0.5) * one_h

	var x_right := label_pos.x - 4.0
	var x_left := x_right - 56.0

	line.position = Vector2(x_left, y - 2.0)
	line.size = Vector2(56.0, 4.0)
	line.visible = true

func _update_bracket_lines(_txt_r2: String, _txt_r3: String, _txt_w: String) -> void:
	_hide_all_bracket_lines()

	# Round 2
	if round_actuel >= 1 and lbl_round2 != null:
		var total_r2 := 16
		if demis.size() >= 1:
			_show_bracket_line("LineR2A", lbl_round2, 1, total_r2)
		if demis.size() >= 2:
			_show_bracket_line("LineR2B", lbl_round2, 5, total_r2)
		if demis.size() >= 3:
			_show_bracket_line("LineR2C", lbl_round2, 9, total_r2)
		if demis.size() >= 4:
			_show_bracket_line("LineR2D", lbl_round2, 13, total_r2)

	# Round 3
	if round_actuel >= 2 and lbl_round3 != null:
		var total_r3 := 16
		if finale.size() >= 1:
			_show_bracket_line("LineR3A", lbl_round3, 3, total_r3)
		if finale.size() >= 2:
			_show_bracket_line("LineR3B", lbl_round3, 12, total_r3)

	# Winner
	if round_actuel >= 3 and vainqueur != "" and lbl_winner != null:
		var total_w := 8
		_show_bracket_line("LineW", lbl_winner, 7, total_w)


func _bm_get_tournament_tuning_id() -> String:
	var k := _get_current_tournament_key()
	match k:
		"TOURNOI_A":
			return "tournoi_a"
		"INTERMEDIATE":
			return "intermediaire"
		"ELITE":
			return "elite"
		_:
			return "tournoi_a"

func _bm_get_current_season_number() -> int:
	var path := "user://savegame.json"
	if not FileAccess.file_exists(path):
		return 1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 1
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		if parsed.has("season_number"):
			return max(1, int(parsed.get("season_number", 1)))
		var progress = parsed.get("progress", {})
		if progress is Dictionary and progress.has("season_number"):
			return max(1, int(progress.get("season_number", 1)))
	return 1

func _bm_get_current_team_rank_value() -> int:
	var ss := get_node_or_null("/root/SeasonState")
	var my_team := _get_my_team_name()
	if ss != null and ss.has_method("get_current_club_rank"):
		return max(1, int(ss.call("get_current_club_rank", my_team)))
	return 8

func _bm_get_current_team_rating_value() -> float:
	var path := "user://savegame.json"
	if not FileAccess.file_exists(path):
		return 60.0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 60.0
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return 60.0

	var players_by_id = parsed.get("players_by_id", {})
	var roster = parsed.get("roster", {})
	var selected_ids = []

	if roster is Dictionary:
		selected_ids = roster.get("selected_ids", [])

	var total := 0.0
	var count := 0

	if selected_ids is Array and players_by_id is Dictionary:
		for pid in selected_ids:
			var pd = players_by_id.get(pid, {})
			if pd is Dictionary:
				var rating := float(pd.get("overall", pd.get("rating", pd.get("ponderation", pd.get("pondération", pd.get("note", 0))))))
				if rating > 0.0:
					total += rating
					count += 1

	if count > 0:
		return total / float(count)

	return 60.0


func _jouer_match_avec_score(e1: String, e2: String) -> Dictionary:
	var s1 := randi_range(62, 98)
	var s2 := randi_range(62, 98)

	var my_team := _get_my_team_name().strip_edges()
	var tournoi_id := _bm_get_tournament_tuning_id()
	var season_number := _bm_get_current_season_number()
	var team_rank := _bm_get_current_team_rank_value()
	var team_rating := _bm_get_current_team_rating_value()
	var player_boost := TuningData.get_tournament_player_boost(tournoi_id, season_number, team_rank, team_rating, 1.0)
	var boost_points := int(round(player_boost * 20.0))

	if my_team != "":
		if str(e1).strip_edges() == my_team:
			s1 += boost_points
		elif str(e2).strip_edges() == my_team:
			s2 += boost_points

	while s1 == s2:
		s2 = randi_range(62, 98)
		if my_team != "":
			if str(e1).strip_edges() == my_team:
				s1 = max(s1, randi_range(62, 98) + boost_points)
			elif str(e2).strip_edges() == my_team:
				s2 = max(s2, randi_range(62, 98) + boost_points)

	var winner := e1
	var winner_score := s1
	var loser_score := s2

	if s2 > s1:
		winner = e2
		winner_score = s2
		loser_score = s1

	print("[TOURNOI BOOST] id=", tournoi_id, " season=", season_number, " rank=", team_rank, " rating=", snapped(team_rating, 0.1), " boost=", snapped(player_boost, 0.001), " points=", boost_points, " match=", e1, " vs ", e2, " => ", s1, "-", s2)

	return {
		"e1": e1,
		"e2": e2,
		"s1": s1,
		"s2": s2,
		"winner": winner,
		"winner_score": winner_score,
		"loser_score": loser_score
	}

func _get_my_team_name() -> String:
	var ss := get_node_or_null("/root/SeasonState")
	if ss != null and ss.has_method("bm_get_my_team_name"):
		return str(ss.call("bm_get_my_team_name")).strip_edges()
	return ""



func _bm_get_saved_tournament_crest_texture(team_name: String) -> Texture2D:
	var d: Dictionary = PlayerLife.load_savegame()
	var crest_path: String = PlayerLife.get_display_crest_path(d, team_name)
	if crest_path == "":
		return null
	if not ResourceLoader.exists(crest_path):
		return null

	return load(crest_path) as Texture2D

func _get_current_tournament_key() -> String:
	return "TOURNOI_A"

func _get_tournament_reward(tournament_key: String, outcome: String) -> Dictionary:
	var tuning_id := str(TOURNAMENT_ID_MAP.get(tournament_key, "")).strip_edges()
	if tuning_id == "":
		return {"euros": 0, "tokens": 0, "xp": 0}
	if not TuningData.TOURNAMENT_TUNING.has(tuning_id):
		return {"euros": 0, "tokens": 0, "xp": 0}
	var tournoi_data: Dictionary = TuningData.TOURNAMENT_TUNING[tuning_id] as Dictionary
	if not tournoi_data.has(outcome):
		return {"euros": 0, "tokens": 0, "xp": 0}
	var reward: Variant = tournoi_data.get(outcome, {})
	if reward is Dictionary:
		return (reward as Dictionary).duplicate(true)
	return {"euros": 0, "tokens": 0, "xp": 0}

func _fmt_reward_amount(v: int) -> String:
	var negative: bool = v < 0
	var s: String = str(abs(v))
	var out: String = ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out + " €"
	if negative:
		out = "-" + out
	return out

func _get_money_tick_path() -> String:
	for path in MONEY_TICK_SFX_CANDIDATES:
		if ResourceLoader.exists(path):
			return path
	return ""

func _ensure_money_tick_player() -> AudioStreamPlayer:
	if _money_tick_player != null and is_instance_valid(_money_tick_player):
		return _money_tick_player

	_money_tick_player = AudioStreamPlayer.new()
	_money_tick_player.name = "TournamentMoneyTickAudio"
	add_child(_money_tick_player)
	return _money_tick_player

func _play_money_tick_once() -> void:
	var path: String = _get_money_tick_path()
	if path == "":
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return

	var player: AudioStreamPlayer = _ensure_money_tick_player()
	player.stream = stream
	player.play()

func _to_int_safe(v: Variant) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(round(v))
		TYPE_STRING:
			return String(v).to_int()
		_:
			return 0

func _grant_tournament_reward_once(tournament_key: String, outcome: String) -> Dictionary:
	var reward: Dictionary = _get_tournament_reward(tournament_key, outcome)
	if _tournament_reward_granted:
		return reward

	_tournament_reward_granted = true

	var euros_gain: int = _to_int_safe(reward.get("euros", 0))

	var tokens_gain: int = _to_int_safe(reward.get("tokens", 0))
	var xp_gain: int = _to_int_safe(reward.get("xp", 0))
	if euros_gain <= 0 and tokens_gain <= 0 and xp_gain <= 0:
		return reward

	var d: Dictionary = PlayerLife.load_savegame()
	if typeof(d) != TYPE_DICTIONARY:
		d = {}

	if euros_gain > 0:
		var total_tournois_now: int = _to_int_safe(d.get("total_tournois", 0))
		d["total_tournois"] = total_tournois_now + euros_gain

		var total_recettes_now: int = _to_int_safe(d.get("total_recettes", 0))
		d["total_recettes"] = total_recettes_now + euros_gain

	if tokens_gain > 0:
		var PL = load("res://scripts/PlayerLife.gd")
		PL.add_tokens(d, tokens_gain, "tournament_reward_%s_%s" % [tournament_key, outcome])

	if xp_gain > 0:
		PlayerLife.add_club_xp(d, xp_gain, "tournament_reward_%s_%s" % [tournament_key, outcome])

	PlayerLife.write_savegame(d)
	_bm_refresh_tokens_hud_from_save(d)
	return reward

func _bm_refresh_tokens_hud_from_save(d: Dictionary) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
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


func _animate_tournament_reward_amount(lbl: Label, euros_gain: int) -> void:
	if lbl == null or not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return

	var displayed: int = 0
	var start_ms: int = Time.get_ticks_msec()
	var base_gain: int = euros_gain
	if base_gain < 10:
		base_gain = 10

	var duration_ms: int = int(round(float(base_gain) / 12000.0 * 1000.0))
	duration_ms = clampi(duration_ms, 2200, 4200)

	var last_tick_ms: int = -9999

	while displayed < euros_gain and is_instance_valid(lbl) and lbl.is_inside_tree() and is_inside_tree():
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return

		var elapsed: int = Time.get_ticks_msec() - start_ms
		var ratio: float = clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)
		var target: int = int(floor((float(euros_gain) * ratio) / 10.0)) * 10

		if target > euros_gain:
			target = euros_gain

		if target > displayed:
			displayed = target
			if not is_instance_valid(lbl) or not lbl.is_inside_tree():
				return
			lbl.text = _fmt_reward_amount(displayed)

			var now_ms: int = Time.get_ticks_msec()
			if now_ms - last_tick_ms >= 45:
				_play_money_tick_once()
				last_tick_ms = now_ms

	if not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	lbl.text = _fmt_reward_amount(euros_gain)

func _animate_tournament_reward_tokens(lbl: Label, tokens_gain: int) -> void:
	if lbl == null or not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	if tokens_gain <= 0:
		lbl.text = "+0"
		return

	lbl.text = "+0"
	var displayed := 0
	while displayed < tokens_gain and is_instance_valid(lbl) and lbl.is_inside_tree() and is_inside_tree():
		displayed += 1
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return
		lbl.text = "+" + str(displayed)
		var tree := get_tree()
		if tree == null:
			return
		await tree.create_timer(0.08).timeout
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return

	if not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	lbl.text = "+" + str(tokens_gain)

func _show_tournament_reward_popup(tournament_key: String, outcome: String) -> void:
	var already := get_node_or_null("TournamentRewardPopup")
	if already != null:
		return

	var reward: Dictionary = _grant_tournament_reward_once(tournament_key, outcome)
	var save := PlayerLife.load_savegame()
	var ms_t: Dictionary = save.get("missions_state", {}) as Dictionary
	var c_t: Dictionary = ms_t.get("counters", {}) as Dictionary
	c_t["tournois_participations"] = int(c_t.get("tournois_participations", 0)) + 1
	ms_t["counters"] = c_t
	save["missions_state"] = ms_t
	PlayerLife.write_savegame(save)
	var euros_gain: int = _to_int_safe(reward.get("euros", 0))
	var tokens_gain: int = _to_int_safe(reward.get("tokens", 0))

	if tokens_gain > 0:
		print("[DEBUG TOKENS DISPLAY] +", tokens_gain)

	if euros_gain <= 0 and tokens_gain <= 0:
		return

	var popup := Control.new()
	popup.name = "TournamentRewardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 230
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(560, 320)
	card.size = Vector2(560, 320)
	card.position = Vector2(
		(get_viewport_rect().size.x - 560.0) * 0.5,
		(get_viewport_rect().size.y - 320.0) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = _tr_or("tournois.reward_title", "Récompense du tournoi")
	title.position = Vector2(0, 28)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	card.add_child(title)

	var subtitle_money := Label.new()
	subtitle_money.text = _tr_or("tournois.reward_subtitle", "Prize money")
	subtitle_money.position = Vector2(35, 82)
	subtitle_money.size = Vector2(220, 32)
	subtitle_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_money.add_theme_font_size_override("font_size", 22)
	card.add_child(subtitle_money)

	var subtitle_tokens := Label.new()
	subtitle_tokens.text = _tr_or("tournois.reward_tokens_title", "Prize tokens")
	subtitle_tokens.position = Vector2(305, 82)
	subtitle_tokens.size = Vector2(220, 32)
	subtitle_tokens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_tokens.add_theme_font_size_override("font_size", 22)
	subtitle_tokens.add_theme_color_override("font_color", Color(1.00, 0.82, 0.30, 1.0))
	card.add_child(subtitle_tokens)

	var amount_lbl := Label.new()
	amount_lbl.text = _fmt_reward_amount(0)
	amount_lbl.position = Vector2(35, 126)
	amount_lbl.size = Vector2(220, 54)
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 42)
	amount_lbl.add_theme_color_override("font_color", Color(0.18, 0.72, 0.25, 1.0))
	card.add_child(amount_lbl)

	var tokens_row := HBoxContainer.new()
	tokens_row.position = Vector2(305, 126)
	tokens_row.size = Vector2(220, 54)
	tokens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens_row.add_theme_constant_override("separation", 8)
	card.add_child(tokens_row)

	var tokens_amount_lbl := Label.new()
	tokens_amount_lbl.text = "+0"
	tokens_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tokens_amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tokens_amount_lbl.add_theme_font_size_override("font_size", 42)
	tokens_amount_lbl.add_theme_color_override("font_color", Color(1.00, 0.72, 0.18, 1.0))
	tokens_row.add_child(tokens_amount_lbl)

	var tokens_icon := TextureRect.new()
	tokens_icon.texture = load("res://assets/images/token.png") as Texture2D
	tokens_icon.custom_minimum_size = Vector2(36, 36)
	tokens_icon.size = Vector2(36, 36)
	tokens_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tokens_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tokens_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tokens_row.add_child(tokens_icon)

	var btn := Button.new()
	btn.text = _tr_or("common.close", "Fermer")
	btn.custom_minimum_size = Vector2(180, 52)
	btn.size = Vector2(180, 52)
	btn.position = Vector2(190, 230)
	btn.pressed.connect(func():
		popup.queue_free()
		_show_tournament_reward_popup(_get_current_tournament_key(), "victory")
	)
	card.add_child(btn)

	_animate_tournament_reward_amount(amount_lbl, euros_gain)
	_animate_tournament_reward_tokens(tokens_amount_lbl, tokens_gain)

# BM_TOURNOI_FINAL_CINEMATIC_V1
func _bm_show_tournament_final_cinematic(team_a: String, team_b: String, score_a: int, score_b: int, winner_name: String) -> void:
	var old := get_node_or_null("TournamentFinalCinematic")
	if old != null:
		old.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "TournamentFinalCinematic"
	layer.layer = 120
	add_child(layer)

	var vp := get_viewport_rect().size

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var title := Label.new()
	title.text = "TOURNAMENT FINAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.size = Vector2(vp.x, 70)
	title.position = Vector2(0, vp.y * 0.12)
	title.modulate.a = 0.0
	layer.add_child(title)

	var left := Label.new()
	left.text = team_a
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_theme_font_size_override("font_size", 30)
	left.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	left.add_theme_constant_override("outline_size", 3)
	left.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	left.size = Vector2(vp.x * 0.40, 80)
	left.position = Vector2(-vp.x * 0.45, vp.y * 0.36)
	layer.add_child(left)

	var right := Label.new()
	right.text = team_b
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_theme_font_size_override("font_size", 30)
	right.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	right.add_theme_constant_override("outline_size", 3)
	right.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	right.size = Vector2(vp.x * 0.40, 80)
	right.position = Vector2(vp.x * 1.05, vp.y * 0.36)
	layer.add_child(right)

	var left_team_crest := _bm_get_saved_tournament_crest_texture(team_a)
	var right_team_crest := _bm_get_saved_tournament_crest_texture(team_b)
	var my_team_for_crest := _get_my_team_name().strip_edges()
	var crest_size := 150.0
	var left_crest: TextureRect = null
	var right_crest: TextureRect = null
	if left_team_crest != null or right_team_crest != null:
		if left_team_crest != null:
			left_crest = TextureRect.new()
			left_crest.texture = left_team_crest
			left_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			left_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			left_crest.size = Vector2(crest_size, crest_size)
			left_crest.position = Vector2(-vp.x * 0.45 + (vp.x * 0.40 - crest_size) * 0.5, vp.y * 0.50 + (90.0 - crest_size) * 0.5)
			layer.add_child(left_crest)
		if right_team_crest != null:
			right_crest = TextureRect.new()
			right_crest.texture = right_team_crest
			right_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			right_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			right_crest.size = Vector2(crest_size, crest_size)
			right_crest.position = Vector2(vp.x * 1.05 + (vp.x * 0.40 - crest_size) * 0.5, vp.y * 0.50 + (90.0 - crest_size) * 0.5)
			layer.add_child(right_crest)

	var vs_lbl := Label.new()
	vs_lbl.text = "VS"
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_size_override("font_size", 42)
	vs_lbl.add_theme_constant_override("outline_size", 5)
	vs_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
	vs_lbl.add_theme_color_override("font_color", Color(1.0,0.86,0.28,1.0))
	vs_lbl.size = Vector2(180, 80)
	vs_lbl.position = Vector2((vp.x - 180) * 0.5, vp.y * 0.36)
	vs_lbl.modulate.a = 0.0
	layer.add_child(vs_lbl)

	var score := Label.new()
	score.text = str(score_a) + "  -  " + str(score_b)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 58)
	score.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	score.add_theme_constant_override("outline_size", 5)
	score.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.95))
	score.size = Vector2(vp.x, 90)
	score.position = Vector2(0, vp.y * 0.50)
	score.scale = Vector2(0.65, 0.65)
	score.modulate.a = 0.0
	layer.add_child(score)

	var champion := Label.new()
	champion.text = "CHAMPIONS: " + winner_name
	champion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	champion.add_theme_font_size_override("font_size", 38)
	champion.add_theme_color_override("font_color", Color(1.0, 0.72, 0.16, 1.0))
	champion.add_theme_constant_override("outline_size", 5)
	champion.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	champion.size = Vector2(vp.x, 90)
	champion.position = Vector2(0, vp.y * 0.66)
	champion.scale = Vector2(0.75, 0.75)
	champion.modulate.a = 0.0
	layer.add_child(champion)

	var flash_top := ColorRect.new()
	flash_top.color = Color(1.0, 0.72, 0.12, 0.0)
	flash_top.size = Vector2(vp.x, 5)
	flash_top.position = Vector2(-vp.x, vp.y * 0.30)
	layer.add_child(flash_top)

	var flash_bottom := ColorRect.new()
	flash_bottom.color = Color(1.0, 0.72, 0.12, 0.0)
	flash_bottom.size = Vector2(vp.x, 5)
	flash_bottom.position = Vector2(vp.x, vp.y * 0.75)
	layer.add_child(flash_bottom)

	var sparks := CPUParticles2D.new()
	sparks.amount = 90
	sparks.lifetime = 1.35
	sparks.one_shot = false
	sparks.emitting = true
	sparks.explosiveness = 0.55
	sparks.spread = 160.0
	sparks.gravity = Vector2(0, 120)
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 190.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 5.0
	sparks.color = Color(1.0, 0.72, 0.12, 0.85)
	sparks.position = Vector2(vp.x * 0.5, vp.y * 0.55)
	layer.add_child(sparks)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(overlay, "color:a", 0.72, 0.28)
	t.tween_property(title, "modulate:a", 1.0, 0.35)
	t.tween_property(left, "position:x", vp.x * 0.07, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(right, "position:x", vp.x * 0.53, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if left_crest != null:
		t.tween_property(left_crest, "position:x", vp.x * 0.07 + (vp.x * 0.40 - crest_size) * 0.5, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if right_crest != null:
		t.tween_property(right_crest, "position:x", vp.x * 0.53 + (vp.x * 0.40 - crest_size) * 0.5, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(vs_lbl, "modulate:a", 1.0, 0.35)
	t.tween_property(flash_top, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(flash_top, "color:a", 0.75, 0.18)
	t.tween_property(flash_bottom, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(flash_bottom, "color:a", 0.75, 0.18)

	await get_tree().create_timer(0.65).timeout

	var btn := Button.new()
	btn.text = "PLAY!"
	btn.size = Vector2(210, 64)
	btn.position = Vector2((vp.x - 210) * 0.5, vp.y * 0.80)
	btn.add_theme_font_size_override("font_size", 28)
	var play_style := StyleBoxFlat.new()
	play_style.bg_color = Color(1.0, 0.62, 0.08, 0.96)
	play_style.border_color = Color(1.0, 0.92, 0.45, 1.0)
	play_style.border_width_left = 2
	play_style.border_width_right = 2
	play_style.border_width_top = 2
	play_style.border_width_bottom = 5
	play_style.corner_radius_top_left = 14
	play_style.corner_radius_top_right = 14
	play_style.corner_radius_bottom_left = 14
	play_style.corner_radius_bottom_right = 14
	play_style.shadow_color = Color(1.0, 0.55, 0.0, 0.45)
	play_style.shadow_size = 14
	play_style.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", play_style)
	btn.add_theme_stylebox_override("hover", play_style)
	btn.add_theme_stylebox_override("pressed", play_style)
	btn.add_theme_color_override("font_color", Color(0.08, 0.05, 0.0, 1.0))
	btn.modulate.a = 0.0
	layer.add_child(btn)

	var t4 := create_tween()
	t4.set_parallel(true)
	t4.tween_property(btn, "modulate:a", 1.0, 0.25)
	t4.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await btn.pressed

	btn.text = "CLOSE"

	var impact_flash := ColorRect.new()
	impact_flash.color = Color(1.0, 0.82, 0.28, 0.0)
	impact_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(impact_flash)

	var impact_sound := AudioStreamPlayer.new()
	var sfx := load("res://audio/sfx/click.mp3")
	if sfx != null:
		impact_sound.stream = sfx
		impact_sound.volume_db = -2.0
		layer.add_child(impact_sound)
		impact_sound.play()

	var flash_tween := create_tween()
	flash_tween.tween_property(impact_flash, "color:a", 0.55, 0.06)
	flash_tween.tween_property(impact_flash, "color:a", 0.0, 0.20)

	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(vs_lbl, "modulate:a", 0.0, 0.18)
	reveal.tween_property(score, "modulate:a", 1.0, 0.22)
	reveal.tween_property(score, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.20).timeout

	var reveal2 := create_tween()
	reveal2.set_parallel(true)
	reveal2.tween_property(score, "scale", Vector2(1.0, 1.0), 0.14)
	reveal2.tween_property(champion, "modulate:a", 1.0, 0.25)
	reveal2.tween_property(champion, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	btn.release_focus()
	await get_tree().process_frame
	await btn.pressed

	if is_instance_valid(layer):
		layer.queue_free()

func _schedule_tournament_victory_popup() -> void:
	var my_team := _get_my_team_name()
	if my_team == "":
		return
	if str(vainqueur).strip_edges() != my_team:
		return

	var tree := get_tree()
	if tree == null:
		return

	var timer := tree.create_timer(1.5)
	timer.timeout.connect(func():
		if is_inside_tree():
			_schedule_tournament_victory_popup()
	)


func _bm_load_tournament_save_dict() -> Dictionary:
	var d := PlayerLife.load_savegame()
	return d if d is Dictionary else {}

func _bm_write_tournament_save_dict(d: Dictionary) -> void:
	PlayerLife.write_savegame(d)

func _bm_has_tournament_result_any_season() -> bool:
	var d := _bm_load_tournament_save_dict()
	var all_results = d.get("tournament_results_by_season", {})
	if not (all_results is Dictionary):
		return false

	for season_key in all_results.keys():
		var season_results = all_results.get(season_key, {})
		if not (season_results is Dictionary):
			continue
		var v := str(season_results.get("tournoi_a", "")).strip_edges()
		if v != "":
			return true

	return false

func _bm_store_tournament_result(result_key: String) -> void:
	var d := _bm_load_tournament_save_dict()
	var season_key := str(d.get("season_id", "")).strip_edges()
	if season_key == "":
		season_key = "season_1"

	var all_results = d.get("tournament_results_by_season", {})
	if not (all_results is Dictionary):
		all_results = {}

	var season_results = all_results.get(season_key, {})
	if not (season_results is Dictionary):
		season_results = {}

	season_results["tournoi_a"] = result_key
	all_results[season_key] = season_results
	d["tournament_results_by_season"] = all_results
	_bm_write_tournament_save_dict(d)


func _maybe_show_tournament_finalist_popup() -> void:
	var my_team := _get_my_team_name()
	if my_team == "":
		return
	if finale.size() < 2:
		return
	if str(vainqueur).strip_edges() == "":
		return

	var is_finalist := false
	for e in finale:
		if str(e).strip_edges() == my_team:
			is_finalist = true
			break

	if not is_finalist:
		return
	if str(vainqueur).strip_edges() == my_team:
		return

	_bm_store_tournament_result("finalist")
	var already := get_node_or_null("TournamentFinalistPopup")
	if already != null:
		return

	var popup := Control.new()
	popup.name = "TournamentFinalistPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 205
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(560, 320)
	card.size = Vector2(560, 320)
	card.position = Vector2(
		(get_viewport_rect().size.x - 560.0) * 0.5,
		(get_viewport_rect().size.y - 320.0) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = "🥈 " + _tr_or("tournois.finalist_title", "2e place !")
	title.position = Vector2(0, 28)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	card.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _tr_or("tournois.finalist_subtitle", "Votre équipe termine finaliste du tournoi")
	subtitle.position = Vector2(30, 88)
	subtitle.size = Vector2(500, 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	card.add_child(subtitle)

	var medal := Label.new()
	medal.text = "🥈"
	medal.position = Vector2(0, 132)
	medal.size = Vector2(560, 70)
	medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal.add_theme_font_size_override("font_size", 56)
	card.add_child(medal)

	var btn := Button.new()
	btn.text = _tr_or("common.close", "Fermer")
	btn.custom_minimum_size = Vector2(180, 52)
	btn.size = Vector2(180, 52)
	btn.position = Vector2(190, 248)
	btn.pressed.connect(func():
		popup.queue_free()
		call_deferred("_show_tournament_reward_popup", _get_current_tournament_key(), "finalist")
	)
	card.add_child(btn)

func _maybe_show_tournament_victory_popup() -> void:
	var my_team := _get_my_team_name()
	if my_team == "":
		return
	if str(vainqueur).strip_edges() != my_team:
		return

	_bm_store_tournament_result("winner")
	var d_cup: Dictionary = PlayerLife.load_savegame()
	if typeof(d_cup) == TYPE_DICTIONARY:
		d_cup["club_has_tournament_cup_crest"] = true
		PlayerLife.write_savegame(d_cup)
	var already := get_node_or_null("TournamentVictoryPopup")
	if already != null:
		return

	var popup := Control.new()
	popup.name = "TournamentVictoryPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 200
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(560, 320)
	card.size = Vector2(560, 320)
	card.position = Vector2(
		(get_viewport_rect().size.x - 560.0) * 0.5,
		(get_viewport_rect().size.y - 320.0) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = "🏆 " + _tr_or("tournois.victory_title", "Victoire !")
	title.position = Vector2(0, 28)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	card.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _tr_or("tournois.victory_subtitle", "Victoire dans le Tournoi A")
	subtitle.position = Vector2(30, 88)
	subtitle.size = Vector2(500, 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	card.add_child(subtitle)

	var trophy := Label.new()
	trophy.text = "🏆"
	trophy.position = Vector2(0, 132)
	trophy.size = Vector2(560, 70)
	trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trophy.add_theme_font_size_override("font_size", 56)
	card.add_child(trophy)

	var btn := Button.new()
	btn.text = _tr_or("common.close", "Fermer")
	btn.custom_minimum_size = Vector2(180, 52)
	btn.size = Vector2(180, 52)
	btn.position = Vector2(190, 248)
	btn.pressed.connect(func():
		popup.queue_free()
		call_deferred("_show_tournament_reward_popup", _get_current_tournament_key(), "victory")
	)
	card.add_child(btn)

	var confetti := CPUParticles2D.new()
	confetti.amount = 90
	confetti.lifetime = 2.2
	confetti.one_shot = false
	confetti.emitting = true
	confetti.explosiveness = 0.25
	confetti.spread = 180.0
	confetti.gravity = Vector2(0, 260)
	confetti.initial_velocity_min = 90.0
	confetti.initial_velocity_max = 170.0
	confetti.scale_amount_min = 4.0
	confetti.scale_amount_max = 7.0
	confetti.position = Vector2(280, 40)
	card.add_child(confetti)

	_stop_tournois_music()

	_stop_tournois_music()

	var victory_path := "res://audio/sfx/victory_jingle.mp3"
	if ResourceLoader.exists(victory_path):
		var player := AudioStreamPlayer.new()
		player.name = "TournamentVictoryAudio"
		player.stream = load(victory_path)
		add_child(player)
		player.finished.connect(func():
			if is_instance_valid(player):
				player.queue_free()
		)
		player.play()

func _tr_or(key: String, fallback: String) -> String:
	var t := tr(key)
	if t == "" or t == key:
		return fallback
	return t

func _play_tournois_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("play_music"):
		am.call("play_music", "res://assets/audio_mp3/tournois.mp3", true, false)

func _stop_tournois_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("stop_music"):
		am.call("stop_music")

func _bm_style_tournament_title_label(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _bm_style_tournament_round_header(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.40))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_font_size_override("font_size", 27)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.09, 0.18, 0.76)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.55, 0.08, 0.75)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	lbl.add_theme_stylebox_override("normal", sb)


func _bm_style_tournament_titles_and_headers() -> void:
	_bm_style_tournament_title_label(lbl_title)
	for path in [
		"UI/BracketWrap/BracketMargin/RoundsRow/ColRound1/LblRound1Title",
		"UI/BracketWrap/BracketMargin/RoundsRow/ColRound2/LblRound2Title",
		"UI/BracketWrap/BracketMargin/RoundsRow/ColRound3/LblRound3Title",
		"UI/BracketWrap/BracketMargin/RoundsRow/ColRound4/LblRound4Title",
		"UI/BracketWrap/BracketMargin/RoundsRow/ColWinner/LblWinnerTitle",
		"UI/EliteBracketClean/ColR1/TitleR1",
		"UI/EliteBracketClean/ColR2/TitleR2",
		"UI/EliteBracketClean/ColR3/TitleR3",
		"UI/EliteBracketClean/ColR4/TitleR4"
	]:
		var h := get_node_or_null(path) as Label
		if h != null:
			_bm_style_tournament_round_header(h)



func _bm_make_internal_tournament_back_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
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


func _bm_style_internal_tournament_back_button() -> void:
	if btn_retour == null:
		return
	var normal := _bm_make_internal_tournament_back_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_internal_tournament_back_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_internal_tournament_back_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_internal_tournament_back_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)
	btn_retour.add_theme_stylebox_override("normal", normal)
	btn_retour.add_theme_stylebox_override("hover", hover)
	btn_retour.add_theme_stylebox_override("focus", hover)
	btn_retour.add_theme_stylebox_override("pressed", pressed)
	btn_retour.add_theme_stylebox_override("disabled", disabled)
	btn_retour.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))


func _ready() -> void:
	_play_tournois_music()
	if btn_retour != null:
		btn_retour.text = tr("teamname.back")
		_bm_style_internal_tournament_back_button()
	_bm_style_tournament_titles_and_headers()
	if btn_simuler_tour != null:
		btn_simuler_tour.pressed.connect(_on_simuler_tour_pressed)
	if btn_retour != null:
		btn_retour.pressed.connect(_on_retour_pressed)
	_init_tournoi()
	# BM FIX: ne pas bloquer un nouveau tournoi à cause d'un résultat d'une ancienne saison
	_refresh_ui()

func _refresh_ui() -> void:
	if lbl_title != null:
		lbl_title.text = tr("tournois.tournament_a") + " - " + tr("tournois.beginner")

	var txt_r1 := ""
	for i in range(quarts.size()):
		var m = quarts[i]
		var top_name := str(m[0])
		var bot_name := str(m[1])

		if i < quarts_resultats.size():
			var r = quarts_resultats[i]
			top_name += " (" + str(r["s1"]) + ")"
			bot_name += " (" + str(r["s2"]) + ")"

		txt_r1 += _line_centered(top_name) + "\n" + _vs_centered() + "\n" + _line_centered(bot_name) + "\n\n"

	# Chaque bloc de match du round 1 fait 4 lignes :
	# equipe1 / vs / equipe2 / ligne vide
	# On place donc le vainqueur du match précédent avec 3 lignes vides après lui.
	var txt_r2 := ""
	for i in range(demis.size()):
		var nom_affiche := str(demis[i])
		if round_actuel >= 2 and i < demis_resultats.size():
			nom_affiche = str(demis_resultats[i])
		txt_r2 += "\n" + _line_centered(nom_affiche) + "\n\n\n"

	# Chaque finaliste doit tomber au centre de deux blocs du round 2
	var txt_r3 := ""
	for i in range(finale.size()):
		var nom_affiche := str(finale[i])
		if round_actuel >= 3 and i < finale_resultats.size():
			nom_affiche = str(finale_resultats[i])
		txt_r3 += "\n\n\n" + _line_centered(nom_affiche) + "\n\n\n\n"
		if i == 0:
			txt_r3 += "\n"

	# Le vainqueur doit tomber au centre de la finale
	var txt_w := ""
	if vainqueur != "":
		var nom_affiche := vainqueur
		if vainqueur_resultat != "":
			nom_affiche = vainqueur_resultat
		txt_w = "\n\n\n\n\n\n\n" + _line_centered(nom_affiche)

	if lbl_round1 != null:
		lbl_round1.text = txt_r1
	if lbl_round2 != null:
		lbl_round2.text = txt_r2
	if lbl_round3 != null:
		lbl_round3.text = txt_r3
	if lbl_winner != null:
		lbl_winner.text = txt_w

	if btn_simuler_tour != null:
		btn_simuler_tour.text = (tr("tournois.completed") if round_actuel >= 3 else tr("tournois.launch_round"))
		btn_simuler_tour.disabled = (round_actuel >= 3)
	_bm_force_tournament_text_white(ui_root)

	call_deferred("_update_bracket_lines", txt_r2, txt_r3, txt_w)

func _on_simuler_tour_pressed() -> void:
	_jouer_round()

func _on_retour_pressed() -> void:
	var tree := get_tree()
	if tree != null and ResourceLoader.exists("res://scenes/TournoisAccueil.tscn"):
		tree.change_scene_to_file("res://scenes/TournoisAccueil.tscn")


func _build_tournament_teams() -> Array:
	var teams := equipes.duplicate()
	var my_team := _get_my_team_name()

	if my_team == "":
		return teams

	var already_present := false
	var my_cmp := my_team.strip_edges().to_lower()
	for t in teams:
		if str(t).strip_edges().to_lower() == my_cmp:
			already_present = true
			break

	if not already_present:
		if teams.size() > 0:
			teams[0] = my_team
		else:
			teams.append(my_team)

	return teams

func _init_tournoi() -> void:
	_tournament_reward_granted = false
	quarts.clear()
	demis.clear()
	finale.clear()
	vainqueur = ""
	round_actuel = 0
	quarts_resultats.clear()
	demis_resultats.clear()
	finale_resultats.clear()
	vainqueur_resultat = ""

	print("[TOURNOI A] my_team=", _get_my_team_name())
	var dbg_save_svc := get_node_or_null("/root/SaveSvc")
	var dbg_ss := get_node_or_null("/root/SeasonState")
	var dbg_a := ""
	var dbg_b := ""
	var dbg_c := _get_my_team_name()
	if dbg_save_svc != null and dbg_save_svc.has_method("get_club_name"):
		dbg_a = str(dbg_save_svc.call("get_club_name")).strip_edges()
	if dbg_ss != null and dbg_ss.has_method("bm_get_my_team_name"):
		dbg_b = str(dbg_ss.call("bm_get_my_team_name")).strip_edges()
	var equipes_tournoi := _build_tournament_teams()

	for i in range(0, equipes_tournoi.size(), 2):
		quarts.append([equipes_tournoi[i], equipes_tournoi[i + 1]])

func _jouer_match(e1: String, e2: String) -> String:
	return e1 if randi() % 2 == 0 else e2

func _jouer_round() -> void:
	if round_actuel == 0:
		demis.clear()
		quarts_resultats.clear()
		demis_resultats.clear()

		for m in quarts:
			var r := _jouer_match_avec_score(str(m[0]), str(m[1]))
			quarts_resultats.append(r)
			demis.append(str(r["winner"]))

		round_actuel = 1

	elif round_actuel == 1:
		finale.clear()
		demis_resultats.clear()
		finale_resultats.clear()

		for i in range(0, demis.size(), 2):
			var e1 := str(demis[i])
			var e2 := str(demis[i + 1])
			var r := _jouer_match_avec_score(e1, e2)

			demis_resultats.append(e1 + " (" + str(r["s1"]) + ")")
			demis_resultats.append(e2 + " (" + str(r["s2"]) + ")")

			finale.append(str(r["winner"]))

		round_actuel = 2

	elif round_actuel == 2:
		finale_resultats.clear()

		var e1 := str(finale[0])
		var e2 := str(finale[1])
		var r := _jouer_match_avec_score(e1, e2)

		finale_resultats.append(e1 + " (" + str(r["s1"]) + ")")
		finale_resultats.append(e2 + " (" + str(r["s2"]) + ")")

		vainqueur = str(r["winner"])
		vainqueur_resultat = str(r["winner"]) + " (" + str(r["winner_score"]) + ")"
		_bm_store_tournament_result("played")
		round_actuel = 3
		await _bm_show_tournament_final_cinematic(e1, e2, int(r["s1"]), int(r["s2"]), vainqueur)
		_maybe_show_tournament_victory_popup()
	_maybe_show_tournament_finalist_popup()

	_refresh_ui()
