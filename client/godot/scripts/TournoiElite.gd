extends Control

const Save := preload("res://scripts/Save.gd")
const PlayerLife := preload("res://scripts/PlayerLife.gd")
const TuningData := preload("res://scripts/TuningData.gd")

var equipes := ["Bulls", "Panthères", "Toros", "Hawks", "Wolves", "Sharks", "Lions", "Kings", "Falcons", "Raptors", "Storm", "Titans", "Dragons", "Comets", "Giants", "Foxes"]

var round_actuel := 0
var round1 := []
var round2 := []
var round3 := []
var round4 := []
var finale := []
var vainqueur := ""

var round1_resultats := []
var round2_resultats := []
var round3_resultats := []
var round4_resultats := []
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
@onready var lbl_round4: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColRound4/LblRound4") as RichTextLabel
@onready var lbl_winner: RichTextLabel = get_node("UI/BracketWrap/BracketMargin/RoundsRow/ColWinner/LblWinner") as RichTextLabel
@onready var btn_simuler_tour: Button = get_node("UI/BtnSimulerTour") as Button
@onready var btn_retour: Button = get_node("UI/BtnRetour") as Button
@onready var ui_root: Control = get_node("UI") as Control


const ELITE_VIRTUAL_LINES: int = 32
const ELITE_R1_TEAM_LINE_MAP := [0, 1, 4, 5, 8, 9, 12, 13, 16, 17, 20, 21, 24, 25, 28, 29]
const ELITE_R2_WINNER_LINE_MAP := [0.5, 4.66, 8.3, 12.46, 14.3, 18.46, 20.3, 24.46]
const ELITE_R3_WINNER_LINE_MAP := [2.85, 11, 19, 27]
const ELITE_R4_WINNER_LINE_MAP := [7, 23]
const ELITE_W_LINE_MAP := [15]


const ELITE_BRACKET_SLOTS := 8
const ELITE_R2_SLOT_MAP := [0, 1, 2, 3, 4, 5, 6, 7]
const ELITE_R3_SLOT_MAP := [1, 3, 5, 7]
const ELITE_R4_SLOT_MAP := [2, 6]
const ELITE_W_SLOT_MAP := [4]

func _line_centered(text: String) -> String:
	return "[center]" + str(text).strip_edges() + "[/center]"

func _vs_centered() -> String:
	return "[center][font_size=14][color=#FFFFFF]— VS —[/color][/font_size][/center]"

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


func _blank_lines(count: int) -> Array[String]:
	var lines: Array[String] = []
	for _i in range(count):
		lines.append("")
	return lines

func _build_text_from_line_map(values: Array, line_map: Array, total_lines: int) -> String:
	var lines: Array[String] = _blank_lines(total_lines)
	var count: int = mini(values.size(), line_map.size())
	for i in range(count):
		var idx: int = int(line_map[i])
		if idx >= 0 and idx < total_lines:
			lines[idx] = _line_centered(str(values[i]))
	return "\n".join(lines)


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
	for n in ["LineR2A", "LineR2B", "LineR2C", "LineR2D", "LineR2E", "LineR2F", "LineR2G", "LineR2H", "LineR3A", "LineR3B", "LineR3C", "LineR3D", "LineR4A", "LineR4B", "LineW"]:
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

	var content_h := label.size.y
	if content_h <= 0.0:
		content_h = 1.0

	var one_h := content_h / float(total_lines)
	var y := label_pos.y + (float(line_index) + 0.5) * one_h

	var x_right := label_pos.x - 4.0
	var x_left := x_right - 42.0

	line.position = Vector2(x_left, y - 2.0)
	line.size = Vector2(42.0, 4.0)
	line.visible = true


func _show_bracket_line_float(name: String, label: RichTextLabel, line_center: float, total_lines: int) -> void:
	if ui_root == null or label == null:
		return
	if total_lines <= 0:
		return

	var line := _ensure_bracket_line(name)
	if line == null:
		return

	var label_pos := label.global_position - ui_root.global_position

	var content_h := label.size.y
	if content_h <= 0.0:
		content_h = 1.0

	var one_h := content_h / float(total_lines)
	var y := label_pos.y + line_center * one_h

	var x_right := label_pos.x - 4.0
	var x_left := x_right - 42.0

	line.position = Vector2(x_left, y - 2.0)
	line.size = Vector2(42.0, 4.0)
	line.visible = true


func _build_round_text_on_slots(values: Array, slot_map: Array, total_slots: int) -> String:
	var lines: Array[String] = []
	for _i in range(total_slots):
		lines.append("")

	var count: int = min(values.size(), slot_map.size())
	for i in range(count):
		var slot_idx: int = int(slot_map[i])
		if slot_idx >= 0 and slot_idx < total_slots:
			lines[slot_idx] = _line_centered(str(values[i]))

	return "\n".join(lines)

func _update_bracket_lines(_txt_r2: String, _txt_r3: String, _txt_r4: String, _txt_w: String) -> void:
	_hide_all_bracket_lines()

	if round_actuel >= 1 and lbl_round2 != null:
		for i in range(mini(round2.size(), 8)):
			if i == 1:
				continue
			if i >= 3:
				continue
			var _center_r1_to_r2: float = 0.5 + float(i) * 3.0
			if i == 0:
				_center_r1_to_r2 += 0.60
			_show_bracket_line_float("LineR2" + char(65 + i), lbl_round2, _center_r1_to_r2, ELITE_VIRTUAL_LINES)

	if round_actuel >= 2 and lbl_round3 != null and round3.size() >= 1:
		_show_bracket_line("LineR3A", lbl_round3, 3, ELITE_VIRTUAL_LINES)

	if round_actuel >= 3 and lbl_round4 != null:
		for i in range(mini(round4.size(), ELITE_R4_WINNER_LINE_MAP.size())):
			_show_bracket_line("LineR4" + char(65 + i), lbl_round4, int(ELITE_R4_WINNER_LINE_MAP[i]), ELITE_VIRTUAL_LINES)

	if round_actuel >= 4 and vainqueur != "" and lbl_winner != null:
		_show_bracket_line("LineW", lbl_winner, int(ELITE_W_LINE_MAP[0]), ELITE_VIRTUAL_LINES)


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
	var team_crest_map: Dictionary = d.get("team_crest_map", {}) as Dictionary
	if team_crest_map.is_empty():
		return null

	var cid: String = str(team_crest_map.get(team_name.strip_edges(), "")).strip_edges()
	if cid == "":
		return null

	var idx: int = int(cid.replace("starter_crest_", ""))
	if idx <= 0:
		return null

	var crest_path: String = "res://assets/images/blasons/blason_%d.png" % idx
	if not ResourceLoader.exists(crest_path):
		return null

	return load(crest_path) as Texture2D

func _get_current_tournament_key() -> String:
	return "ELITE"

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


func _bm_refresh_tokens_hud_from_save(d_save: Dictionary) -> void:
	if typeof(d_save) != TYPE_DICTIONARY:
		return
	var tokens_ui: int = PlayerLife.get_tokens(d_save)
	var root: Node = get_tree().current_scene
	if root == null:
		root = self

	for n in root.find_children("LblHudTokens", "Label", true, false):
		if n is Label:
			(n as Label).text = "Tokens " + str(tokens_ui)


func _animate_tournament_reward_amount(lbl: Label, euros_gain: int) -> void:
	if lbl == null:
		return

	var displayed: int = 0
	var start_ms: int = Time.get_ticks_msec()
	var base_gain: int = euros_gain
	if base_gain < 10:
		base_gain = 10
	var duration_ms: int = int(round(float(base_gain) / 12000.0 * 1000.0))
	duration_ms = clamp(duration_ms, 900, 2400)

	while true:
		var elapsed: int = Time.get_ticks_msec() - start_ms
		var t: float = min(1.0, float(elapsed) / float(duration_ms))
		displayed = int(round(lerp(0.0, float(euros_gain), t)))
		lbl.text = _fmt_reward_amount(displayed)
		_play_money_tick_once()
		if t >= 1.0:
			break
		await get_tree().create_timer(0.05).timeout

	lbl.text = _fmt_reward_amount(euros_gain)

func _animate_tournament_reward_tokens(lbl: Label, tokens_gain: int) -> void:
	if lbl == null:
		return
	if tokens_gain <= 0:
		lbl.text = "+0"
		return

	lbl.text = "+0"
	var displayed := 0
	while displayed < tokens_gain:
		displayed += 1
		lbl.text = "+" + str(displayed)
		var tree := get_tree()
		if tree == null:
			break
		await tree.create_timer(0.08).timeout

	lbl.text = "+" + str(tokens_gain)

func _show_tournament_reward_popup(tournament_key: String, outcome: String) -> void:
	var already := get_node_or_null("TournamentRewardPopup")
	if already != null:
		return

	var reward: Dictionary = _get_tournament_reward(tournament_key, outcome)
	var euros_gain: int = _to_int_safe(reward.get("euros", 0))
	var tokens_gain: int = _to_int_safe(reward.get("tokens", 0))

	if tokens_gain > 0:
		print("[DEBUG TOKENS DISPLAY] +", tokens_gain)

	if euros_gain <= 0 and tokens_gain <= 0:
		return

	_bm_store_tournament_result("winner")
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
	)
	card.add_child(btn)

	_animate_tournament_reward_amount(amount_lbl, euros_gain)
	_animate_tournament_reward_tokens(tokens_amount_lbl, tokens_gain)


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
		var v := str(season_results.get("elite", "")).strip_edges()
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

	season_results["elite"] = result_key
	all_results[season_key] = season_results
	d["tournament_results_by_season"] = all_results
	_bm_write_tournament_save_dict(d)


func _show_finalist_popup() -> void:
	_bm_store_tournament_result("finalist")
	var my_team := _get_my_team_name()
	if my_team == "":
		return
	if round4.size() < 2:
		return
	if str(vainqueur).strip_edges() == "":
		return

	var is_finalist := false
	for e in round4:
		if str(e).strip_edges() == my_team:
			is_finalist = true
			break

	if not is_finalist:
		return
	if str(vainqueur).strip_edges() == my_team:
		return

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

func _show_victory_popup() -> void:
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
	# CONFETTIS (copié de TournoiA)
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


	var subtitle := Label.new()
	subtitle.text = _tr_or("tournois.victory_subtitle_elite", "Victoire dans le tournoi Élite")
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

func _tr_or(key: String, fallback: String) -> String:
	var t := tr(key)
	if t == "" or t == key:
		return fallback
	return t

func _play_tournament_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("play_music"):
		am.call("play_music", "res://assets/audio_mp3/tournois.mp3", true, false)

func _stop_tournament_music() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	if am.has_method("stop_music"):
		am.call("stop_music")

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

	var impact_zoom := create_tween()
	impact_zoom.set_parallel(true)
	impact_zoom.tween_property(layer, "scale", Vector2(1.05, 1.05), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_zoom.tween_property(layer, "position", Vector2(-40, -25), 0.14)

	await get_tree().create_timer(0.14).timeout

	var impact_reset := create_tween()
	impact_reset.set_parallel(true)
	impact_reset.tween_property(layer, "scale", Vector2(1.0, 1.0), 0.18)
	impact_reset.tween_property(layer, "position", Vector2.ZERO, 0.18)

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
	randomize()
	_play_tournament_music()

	if btn_retour != null:
		btn_retour.text = tr("teamname.back")
		_bm_style_internal_tournament_back_button()
	_bm_style_tournament_titles_and_headers()
	if btn_simuler_tour != null:
		btn_simuler_tour.text = tr("tournois.launch_round")
	if lbl_title != null:
		lbl_title.text = tr("tournois.elite")

	if btn_simuler_tour != null and not btn_simuler_tour.pressed.is_connected(_on_btn_simuler_tour_pressed):
		btn_simuler_tour.pressed.connect(_on_btn_simuler_tour_pressed)
	if btn_retour != null and not btn_retour.pressed.is_connected(_on_btn_retour_pressed):
		btn_retour.pressed.connect(_on_btn_retour_pressed)

	_reset_tournament()
	# BM FIX: ne pas bloquer un nouveau tournoi à cause d'un résultat d'une ancienne saison
	_refresh_bracket()
	_bm_render_clean_elite_bracket()
	_bm_render_simple_bracket()

func _refresh_bracket() -> void:
	var display_r1: Array[String] = []
	for i in range(round1.size()):
		var m = round1[i]
		var e1 := str(m[0])
		var e2 := str(m[1])

		var a1 := e1
		var a2 := e2
		if i < round1_resultats.size():
			var r = round1_resultats[i]
			a1 = str(r["e1"]) + " (" + str(r["s1"]) + ")"
			a2 = str(r["e2"]) + " (" + str(r["s2"]) + ")"

		display_r1.append(a1)
		display_r1.append(a2)

	var txt_r1: String = _build_text_from_line_map(display_r1, ELITE_R1_TEAM_LINE_MAP, ELITE_VIRTUAL_LINES)

	var display_r2: Array[String] = []
	for i in range(round2.size()):
		var nom_affiche_r2: String = str(round2[i])
		if round_actuel >= 2 and i < round2_resultats.size():
			nom_affiche_r2 = str(round2_resultats[i])
		display_r2.append(nom_affiche_r2)
	var txt_r2: String = _build_text_from_line_map(display_r2, ELITE_R2_WINNER_LINE_MAP, ELITE_VIRTUAL_LINES)

	var display_r3: Array[String] = []
	var round3_visible: int = mini(round3.size(), 1)
	for i in range(round3_visible):
		var nom_affiche_r3: String = str(round3[i])
		if round_actuel >= 3 and i < round3_resultats.size():
			nom_affiche_r3 = str(round3_resultats[i])
		display_r3.append(nom_affiche_r3)
	var txt_r3: String = _build_text_from_line_map(display_r3, ELITE_R3_WINNER_LINE_MAP, ELITE_VIRTUAL_LINES)

	var display_r4: Array[String] = []
	for i in range(round4.size()):
		var nom_affiche_r4: String = str(round4[i])
		if round_actuel >= 4 and i < round4_resultats.size():
			nom_affiche_r4 = str(round4_resultats[i])
		display_r4.append(nom_affiche_r4)
	var txt_r4: String = _build_text_from_line_map(display_r4, ELITE_R4_WINNER_LINE_MAP, ELITE_VIRTUAL_LINES)

	var display_w: Array[String] = []
	if vainqueur != "":
		display_w.append(vainqueur)
	var txt_w: String = _build_text_from_line_map(display_w, ELITE_W_LINE_MAP, ELITE_VIRTUAL_LINES)
	if lbl_round1 != null:
		lbl_round1.text = txt_r1
	if lbl_round2 != null:
		lbl_round2.text = txt_r2
	if lbl_round3 != null:
		lbl_round3.text = txt_r3
	if lbl_round4 != null:
		lbl_round4.text = txt_r4
	if lbl_winner != null:
		lbl_winner.text = txt_w

	if btn_simuler_tour != null:
		btn_simuler_tour.text = (tr("tournois.completed") if round_actuel >= 5 else tr("tournois.launch_round"))
		btn_simuler_tour.disabled = (round_actuel >= 5)
	_bm_force_tournament_text_white(ui_root)

	call_deferred("#_update_bracket_lines", txt_r2, txt_r3, txt_r4, txt_w)

func _on_btn_simuler_tour_pressed() -> void:
	_jouer_round()
	_refresh_bracket()
	_bm_render_clean_elite_bracket()
	_bm_render_simple_bracket()

func _on_btn_retour_pressed() -> void:
	_stop_tournament_music()
	get_tree().change_scene_to_file("res://scenes/TournoisAccueil.tscn")

func _build_tournament_teams() -> Array:
	var teams := equipes.duplicate()
	var my_team := _get_my_team_name()
	if my_team == "":
		return teams

	var found := false
	for i in range(teams.size()):
		if str(teams[i]).strip_edges() == my_team:
			found = true
			break

	if not found:
		if teams.size() > 0:
			teams[0] = my_team
		else:
			teams.append(my_team)

	return teams

func _reset_tournament() -> void:
	round1.clear()
	round2.clear()
	round3.clear()
	round4.clear()
	finale.clear()
	vainqueur = ""

	round_actuel = 0
	round1_resultats.clear()
	round2_resultats.clear()
	round3_resultats.clear()
	round4_resultats.clear()
	finale_resultats.clear()
	vainqueur_resultat = ""
	_tournament_reward_granted = false

	var equipes_tournoi := _build_tournament_teams()
	for i in range(0, equipes_tournoi.size(), 2):
		round1.append([equipes_tournoi[i], equipes_tournoi[i + 1]])

func _jouer_round() -> void:
	if round_actuel == 0:
		round2.clear()
		round1_resultats.clear()
		for m in round1:
			var r := _jouer_match_avec_score(str(m[0]), str(m[1]))
			round1_resultats.append(r)
			round2.append(str(r["winner"]))
		round_actuel = 1

	elif round_actuel == 1:
		round3.clear()
		round2_resultats.clear()
		for i in range(0, round2.size(), 2):
			var e1 := str(round2[i])
			var e2 := str(round2[i + 1])
			var r := _jouer_match_avec_score(e1, e2)
			round2_resultats.append(e1 + " (" + str(r["s1"]) + ")")
			round2_resultats.append(e2 + " (" + str(r["s2"]) + ")")
			round3.append(str(r["winner"]))
		round_actuel = 2

	elif round_actuel == 2:
		round4.clear()
		round3_resultats.clear()
		for i in range(0, round3.size(), 2):
			var e1 := str(round3[i])
			var e2 := str(round3[i + 1])
			var r := _jouer_match_avec_score(e1, e2)
			round3_resultats.append(e1 + " (" + str(r["s1"]) + ")")
			round3_resultats.append(e2 + " (" + str(r["s2"]) + ")")
			round4.append(str(r["winner"]))
		round_actuel = 3

	elif round_actuel == 3:
		if round4.size() >= 2:
			var e1 := str(round4[0])
			var e2 := str(round4[1])
			var r := _jouer_match_avec_score(e1, e2)
			round4_resultats.clear()
			round4_resultats.append(e1 + " (" + str(r["s1"]) + ")")
			round4_resultats.append(e2 + " (" + str(r["s2"]) + ")")
			vainqueur = str(r["winner"])
			vainqueur_resultat = vainqueur
			_bm_store_tournament_result("played")
			await _bm_show_tournament_final_cinematic(e1, e2, int(r["s1"]), int(r["s2"]), vainqueur)
			_bm_render_clean_elite_bracket()
			var my_team := _get_my_team_name().strip_edges()
			if my_team != "" and str(vainqueur).strip_edges() == my_team:
				var reward := _grant_tournament_reward_once(_get_current_tournament_key(), "victory")
				var euros_gain := _to_int_safe(reward.get("euros", 0))
				_show_victory_popup()
			elif my_team != "" and (str(e1).strip_edges() == my_team or str(e2).strip_edges() == my_team):
				_show_finalist_popup()
			round_actuel = 5


func _create_match_block(e1: String, e2: String) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(140, 60)

	var l1 := Label.new()
	l1.text = e1
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var l2 := Label.new()
	l2.text = e2
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vb.add_child(l1)
	vb.add_child(l2)

	return vb


func _render_elite_bracket() -> void:
	var root := get_node("UI/EliteBracketRoot")

	var col1 = root.get_node("ColR1")
	var col2 = root.get_node("ColR2")
	var col3 = root.get_node("ColR3")
	var col4 = root.get_node("ColR4")
	var col5 = root.get_node("ColW")

	for c in [col1, col2, col3, col4, col5]:
		for child in c.get_children():
			child.queue_free()

	# ROUND 1
	if round1_resultats.size() > 0:
		for r in round1_resultats:
			col1.add_child(_create_match_block(
				str(r.get("e1", "")) + " (" + str(r.get("s1", 0)) + ")",
				str(r.get("e2", "")) + " (" + str(r.get("s2", 0)) + ")"
			))
	else:
		for m in round1:
			col1.add_child(_create_match_block(str(m[0]), str(m[1])))

	# ROUND 2
	if round2_resultats.size() > 0:
		for i in range(0, round2_resultats.size(), 2):
			if i + 1 < round2_resultats.size():
				col2.add_child(_create_match_block(str(round2_resultats[i]), str(round2_resultats[i + 1])))
	else:
		for i in range(0, round2.size(), 2):
			if i + 1 < round2.size():
				col2.add_child(_create_match_block(str(round2[i]), str(round2[i + 1])))

	# ROUND 3
	if round3_resultats.size() > 0:
		for i in range(0, round3_resultats.size(), 2):
			if i + 1 < round3_resultats.size():
				col3.add_child(_create_match_block(str(round3_resultats[i]), str(round3_resultats[i + 1])))
	else:
		for i in range(0, round3.size(), 2):
			if i + 1 < round3.size():
				col3.add_child(_create_match_block(str(round3[i]), str(round3[i + 1])))

	# ROUND 4
	if round4_resultats.size() > 0:
		for i in range(0, round4_resultats.size(), 2):
			if i + 1 < round4_resultats.size():
				col4.add_child(_create_match_block(str(round4_resultats[i]), str(round4_resultats[i + 1])))
	else:
		for i in range(0, round4.size(), 2):
			if i + 1 < round4.size():
				col4.add_child(_create_match_block(str(round4[i]), str(round4[i + 1])))

	# WINNER
	if vainqueur != "":
		col5.add_child(_create_match_block(str(vainqueur), ""))


func _bm_render_simple_bracket() -> void:
	# Sécurité nodes
	var col_r1 = get_node_or_null("UI/EliteBracketRoot/ColR1/LblRound1")
	var col_r2 = get_node_or_null("UI/EliteBracketRoot/ColR2/LblRound2")
	var col_r3 = get_node_or_null("UI/EliteBracketRoot/ColR3/LblRound3")
	var col_r4 = get_node_or_null("UI/EliteBracketRoot/ColR4/LblRound4")
	var col_w  = get_node_or_null("UI/EliteBracketRoot/ColW/LblWinner")

	if col_r1 == null:
		return

	# -------- ROUND 1 (16 équipes → 8 matchs)
	var txt_r1 := ""
	for i in range(0, equipes.size(), 2):
		var a = equipes[i]
		var b = equipes[i+1]
		txt_r1 += str(a) + " vs " + str(b) + "\n\n"

	col_r1.text = txt_r1

	# -------- ROUND 2
	if col_r2 != null:
		var txt_r2 := ""
		for i in range(0, round2.size(), 2):
			var a = round2[i]
			var b = round2[i+1]
			txt_r2 += str(a) + " vs " + str(b) + "\n\n"
		col_r2.text = txt_r2

	# -------- ROUND 3
	if col_r3 != null:
		var txt_r3 := ""
		for i in range(0, round3.size(), 2):
			var a = round3[i]
			var b = round3[i+1]
			txt_r3 += str(a) + " vs " + str(b) + "\n\n"
		col_r3.text = txt_r3

	# -------- ROUND 4 (finale)
	if col_r4 != null:
		var txt_r4 := ""
		if round4.size() >= 2:
			txt_r4 = str(round4[0]) + " vs " + str(round4[1])
		col_r4.text = txt_r4

	# -------- WINNER
	if col_w != null and vainqueur != "":
		col_w.text = str(vainqueur)




func _bm_build_centered_slot_text(entries: Array[String], max_slots: int) -> String:
	var slots: Array[String] = []
	for _i in range(max_slots):
		slots.append("")

	var count: int = mini(entries.size(), max_slots)
	var top_empty: int = maxi(0, int(floor(float(max_slots - count) / 2.0)))

	for i in range(count):
		var idx: int = top_empty + i
		if idx >= 0 and idx < slots.size():
			slots[idx] = entries[i]

	return "\n\n".join(slots)

func _bm_render_clean_elite_bracket() -> void:
	var body_r1 := get_node_or_null("UI/EliteBracketClean/ColR1/BodyR1") as RichTextLabel
	var body_r2 := get_node_or_null("UI/EliteBracketClean/ColR2/BodyR2") as RichTextLabel
	var body_r3 := get_node_or_null("UI/EliteBracketClean/ColR3/BodyR3") as RichTextLabel
	var body_r4 := get_node_or_null("UI/EliteBracketClean/ColR4/BodyR4") as RichTextLabel
	var body_w := get_node_or_null("UI/EliteBracketClean/ColW/BodyW") as RichTextLabel

	if body_r1 == null:
		return

	var r1_entries: Array[String] = []
	if round1_resultats.size() > 0:
		for r in round1_resultats:
			r1_entries.append(str(r.get("e1", "")) + " (" + str(r.get("s1", 0)) + ") vs " + str(r.get("e2", "")) + " (" + str(r.get("s2", 0)) + ")")
	else:
		for i in range(round1.size()):
			var m = round1[i]
			r1_entries.append(str(m[0]) + " vs " + str(m[1]))
	body_r1.text = "\n\n".join(r1_entries)

	if body_r2 != null:
		var r2_entries: Array[String] = []
		if round2_resultats.size() > 0:
			for i in range(0, round2_resultats.size(), 2):
				if i + 1 < round2_resultats.size():
					r2_entries.append(str(round2_resultats[i]) + " vs " + str(round2_resultats[i + 1]))
		else:
			for i in range(0, round2.size(), 2):
				if i + 1 < round2.size():
					r2_entries.append(str(round2[i]) + " vs " + str(round2[i + 1]))
		body_r2.text = _bm_build_centered_slot_text(r2_entries, 8)

	if body_r3 != null:
		var r3_entries: Array[String] = []
		if round3_resultats.size() > 0:
			for i in range(0, round3_resultats.size(), 2):
				if i + 1 < round3_resultats.size():
					r3_entries.append(str(round3_resultats[i]) + " vs " + str(round3_resultats[i + 1]))
		else:
			for i in range(0, round3.size(), 2):
				if i + 1 < round3.size():
					r3_entries.append(str(round3[i]) + " vs " + str(round3[i + 1]))
		body_r3.text = _bm_build_centered_slot_text(r3_entries, 8)

	if body_r4 != null:
		var r4_entries: Array[String] = []
		if round4_resultats.size() > 0:
			for i in range(0, round4_resultats.size(), 2):
				if i + 1 < round4_resultats.size():
					r4_entries.append(str(round4_resultats[i]) + " vs " + str(round4_resultats[i + 1]))
		else:
			if round4.size() >= 2:
				r4_entries.append(str(round4[0]) + " vs " + str(round4[1]))
		body_r4.text = _bm_build_centered_slot_text(r4_entries, 8)

	if body_w != null:
		var w_entries: Array[String] = []
		if vainqueur != "":
			w_entries.append("🏆 " + str(vainqueur))
		body_w.text = _bm_build_centered_slot_text(w_entries, 8)
