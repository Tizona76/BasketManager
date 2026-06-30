extends Control

const BM_TEST_FORCE_MERCATO_OPEN := false # TEST TEMPORAIRE: remettre à false après tests
const PL = preload("res://scripts/PlayerLife.gd")
const Selection := preload("res://scripts/Selection.gd")
const TuningData := preload("res://scripts/TuningData.gd")
const TOKEN_ICON := preload("res://assets/images/token.png")


var _close_x_lock_until_ms: int = 0
var _last_match_finance_popup_shown_this_entry: bool = false
@onready var standings_panel: Control = get_node_or_null("StandingsPanel") as Control
@onready var lbl_standings: RichTextLabel = get_node_or_null("StandingsPanel/LblStandings") as RichTextLabel

var _tw_match_pulse: Tween = null
var _btn_match_base_pos: Vector2 = Vector2.ZERO

# --- Références UI ---
@onready var bg: TextureRect = get_node("BG") as TextureRect

@onready var btn_classement: Button = get_node("UI/Tabs/BtnClassement") as Button
@onready var btn_statistiques: Button = get_node("UI/Tabs/BtnStatistiques") as Button
@onready var btn_calendrier: Button = get_node("UI/Tabs/BtnCalendrier") as Button
@onready var lbl_hud_level: Label = get_node_or_null("UI/HudProgressPanel/HudVBox/LblHudLevel") as Label
@onready var lbl_hud_xp: Label = get_node_or_null("UI/HudProgressPanel/HudVBox/LblHudXp") as Label
@onready var lbl_hud_tokens: Label = get_node_or_null("UI/HudProgressPanel/HudVBox/TokensRow/LblHudTokens") as Label

var _hud_last_xp_displayed: int = -1
var _hud_last_level_displayed: int = -1
var _hud_xp_tween: Tween = null
var _mission_tokens_popup_pending: int = 0
var _mission_tokens_popup_pending_labels: Array = []


func _apply_i18n_tabs() -> void:
	# Tabs Saison (noms issus des clés existantes dans translations.csv)
	if btn_classement != null:
		btn_classement.text = tr("saison.tab.standings")
	if btn_statistiques != null:
		btn_statistiques.text = tr("saison.tab.stats")
	if btn_calendrier != null:
		btn_calendrier.text = tr("saison.tab.calendar")
	if btn_missions != null:
		if not btn_missions.pressed.is_connected(_on_btn_missions_pressed):
			btn_missions.pressed.connect(_on_btn_missions_pressed)
		btn_missions.text = tr("saison.tab.missions")
	if btn_tournois != null:
		btn_tournois.text = tr("saison.tab.tournois")
	if btn_mercato != null:
		btn_mercato.text = tr("menu.mercato")
@onready var btn_mercato: Button = get_node("UI/Tabs/BtnMercato") as Button
@onready var btn_missions: Button = get_node("UI/Tabs/BtnMissions") as Button

func _on_btn_missions_pressed() -> void:
	_bm_stop_unlock_glow(btn_missions)
	_show_missions_panel()


@onready var btn_tournois: Button = get_node_or_null("UI/Tabs/BtnTournois") as Button
@onready var btn_match: Button = get_node("UI/BtnMatch") as Button

var _btn_match_tween: Tween = null
var _btn_match_base_scale: Vector2 = Vector2.ONE
var _btn_match_halo: Panel = null
var _btn_match_halo_tween: Tween = null
@onready var btn_retour: Button = get_node("UI/BtnRetour") as Button

var _unlock_glow_tweens: Dictionary = {}

func _bm_unlock_glow_key(btn_name: String) -> String:
	if btn_name == "BtnTournois" or btn_name == "BtnMissions":
		var save: Dictionary = PL.load_savegame()
		if typeof(save) == TYPE_DICTIONARY:
			return "season_unlock_glow_seen_s%s_%s" % [str(int(save.get("season_number", 1))), btn_name]
	return "season_unlock_glow_seen_" + btn_name

func _bm_unlock_glow_should_run(btn: Button, required_matches: int) -> bool:
	if btn == null:
		return false
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return false
	var matches_played: int = int(save.get("season_round", 0))
	if matches_played < required_matches:
		return false
	if not btn.visible:
		return false
	return not bool(save.get(_bm_unlock_glow_key(String(btn.name)), false))

func _bm_stop_unlock_glow(btn: Button, persist_seen: bool = true) -> void:
	if btn == null:
		return
	var k := String(btn.name)
	if _unlock_glow_tweens.has(k):
		var tw = _unlock_glow_tweens[k]
		if tw != null and is_instance_valid(tw):
			tw.kill()
		_unlock_glow_tweens.erase(k)
	btn.modulate = Color(1, 1, 1, 1)
	btn.self_modulate = Color(1, 1, 1, 1)
	if persist_seen:
		var save: Dictionary = PL.load_savegame()
		if typeof(save) == TYPE_DICTIONARY:
			save[_bm_unlock_glow_key(k)] = true
			PL.write_savegame(save)

func _bm_start_unlock_glow(btn: Button) -> void:
	if btn == null:
		return
	_bm_stop_unlock_glow(btn, false)
	btn.modulate = Color(1, 1, 1, 1)
	btn.self_modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(btn, "self_modulate", Color(0.45, 0.72, 1.35, 1.0), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "self_modulate", Color(1, 1, 1, 1), 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_unlock_glow_tweens[String(btn.name)] = tw

func _bm_apply_unlock_glows() -> void:
	if btn_calendrier != null and _bm_unlock_glow_should_run(btn_calendrier, 0):
		_bm_start_unlock_glow(btn_calendrier)
	if _bm_unlock_glow_should_run(btn_classement, 1):
		_bm_start_unlock_glow(btn_classement)
	if btn_tournois != null and _bm_unlock_glow_should_run(btn_tournois, 10):
		_bm_start_unlock_glow(btn_tournois)
	if _bm_unlock_glow_should_run(btn_missions, 15):
		_bm_start_unlock_glow(btn_missions)

func _bm_stop_all_unlock_glows() -> void:
	if btn_calendrier != null:
		_bm_stop_unlock_glow(btn_calendrier, false)
	if btn_classement != null:
		_bm_stop_unlock_glow(btn_classement, false)
	if btn_tournois != null:
		_bm_stop_unlock_glow(btn_tournois, false)
	if btn_missions != null:
		_bm_stop_unlock_glow(btn_missions, false)


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



func _bm_make_action_button_style(bg: Color, glow: Color, bottom_w: int, shadow_size: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_bottom = bottom_w
	sb.border_color = glow
	sb.shadow_color = Color(glow.r, glow.g, glow.b, 0.34)
	sb.shadow_size = shadow_size
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _bm_style_btn_match_action() -> void:
	if btn_match == null:
		return

	var normal := _bm_make_action_button_style(Color(0.03, 0.16, 0.38, 0.98), Color(1.0, 0.05, 0.06, 0.92), 4, 8)
	var hover := _bm_make_action_button_style(Color(0.05, 0.24, 0.55, 0.98), Color(1.0, 0.12, 0.12, 1.0), 6, 14)
	var pressed := _bm_make_action_button_style(Color(0.02, 0.11, 0.28, 1.0), Color(0.85, 0.02, 0.03, 1.0), 5, 6)
	var disabled := _bm_make_action_button_style(Color(0.08, 0.08, 0.09, 0.70), Color(0.45, 0.08, 0.08, 0.55), 3, 3)

	btn_match.add_theme_stylebox_override("normal", normal)
	btn_match.add_theme_stylebox_override("hover", hover)
	btn_match.add_theme_stylebox_override("pressed", pressed)
	btn_match.add_theme_stylebox_override("disabled", disabled)
	btn_match.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_match.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_match.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_match.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	btn_match.add_theme_font_size_override("font_size", 26)

func _bm_style_btn_retour() -> void:
	if btn_retour == null:
		return

	var normal := _bm_make_back_button_style(Color(0.90, 0.05, 0.05, 1.0), Color(0, 0, 0, 0.35), 3, 6)
	var hover := _bm_make_back_button_style(Color(1.0, 0.10, 0.10, 1.0), Color(0, 0, 0, 0.45), 4, 8)
	var pressed := _bm_make_back_button_style(Color(0.70, 0.02, 0.02, 1.0), Color(0, 0, 0, 0.25), 2, 4)
	var disabled := _bm_make_back_button_style(Color(0.40, 0.10, 0.10, 0.60), Color(0, 0, 0, 0.20), 2, 2)

	btn_retour.add_theme_stylebox_override("normal", normal)
	btn_retour.add_theme_stylebox_override("hover", hover)
	btn_retour.add_theme_stylebox_override("pressed", pressed)
	btn_retour.add_theme_stylebox_override("disabled", disabled)
	btn_retour.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn_retour.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	var _back_fs: int = 22
	if _bm_saison_is_mobile_landscape():
		_back_fs = 24
	btn_retour.add_theme_font_size_override("font_size", _back_fs)
	btn_retour.custom_minimum_size = Vector2(180, 56)

func _bm_apply_i18n_btn_retour() -> void:
	if btn_retour != null:
		btn_retour.set_meta("i18n_key", "season.back_to_management")
		btn_retour.text = "season.back_to_management"
		I18nSvc.apply_node(btn_retour)
		_bm_style_btn_retour()

@onready var popup_bienvenue: Panel = get_node("Overlays/PopupBienvenue") as Panel
@onready var btn_close_bienvenue: Button = get_node("Overlays/PopupBienvenue/BtnCloseBienvenue") as Button
@onready var lbl_bienvenue: RichTextLabel = get_node_or_null("Overlays/PopupBienvenue/LblBienvenue") as RichTextLabel
@onready var img_popup_ball_bienvenue: TextureRect = get_node_or_null("Overlays/PopupBienvenue/ImgPopupBallBienvenue") as TextureRect
@onready var btn_close_classement: Button = get_node_or_null("UI/BtnCloseClassement") as Button
@onready var standings_graph_panel: ColorRect = get_node_or_null("StandingsGraphPanel") as ColorRect
@onready var standings_graph_title: Label = get_node_or_null("StandingsGraphPanel/StandingsGraphTitle") as Label
@onready var standings_graph: Control = get_node_or_null("StandingsGraphPanel/StandingsGraph") as Control
@onready var missions_panel: ColorRect = get_node_or_null("MissionsPanel") as ColorRect
@onready var missions_card: Panel = get_node_or_null("MissionsPanel/MissionsCard") as Panel
@onready var lbl_missions_title: Label = get_node_or_null("MissionsPanel/MissionsCard/LblMissionsTitle") as Label
@onready var lbl_missions_level: Label = get_node_or_null("MissionsPanel/MissionsCard/LblMissionsLevel") as Label
@onready var lbl_missions_status: Label = get_node_or_null("MissionsPanel/MissionsCard/LblMissionsStatus") as Label
@onready var lbl_missions_reward: Label = get_node_or_null("MissionsPanel/MissionsCard/LblMissionsReward") as Label
@onready var metro_canvas: Control = get_node_or_null("MissionsPanel/MissionsCard/MetroCanvas") as Control
@onready var btn_close_missions: Button = get_node_or_null("MissionsPanel/MissionsCard/BtnCloseMissions") as Button
@onready var btn_claim_mission: Button = get_node_or_null("MissionsPanel/MissionsCard/BtnClaimMission") as Button


var calendrier_modal: Control = null
var popup_fin_saison: Panel = null
var btn_popup_fin_saison: Button = null

var lbl_season_day: Label = null

# --- Ready ---


func _bm_lang_code() -> String:
	var loc := TranslationServer.get_locale().to_lower()
	if loc.begins_with("fr"):
		return "fr"
	if loc.begins_with("es"):
		return "es"
	if loc.begins_with("it"):
		return "it"
	if loc.begins_with("pt"):
		return "pt"
	return "en"

func _bm_popup_fallback(key: String) -> String:
	var lang := _bm_lang_code()

	var data := {
		"popup_intro_title": {
			"fr": "🏀 Bienvenue dans Basket Manager",
			"en": "🏀 Welcome to Basket Manager",
			"es": "🏀 Bienvenido a Basket Manager",
			"it": "🏀 Benvenuto in Basket Manager",
			"pt": "🏀 Bem-vindo ao Basket Manager"
		},
		"popup_intro_build_title": {
			"fr": "🏟 Construisez votre club",
			"en": "🏟 Build your club",
			"es": "🏟 Construye tu club",
			"it": "🏟 Costruisci il tuo club",
			"pt": "🏟 Construa seu clube"
		},
		"popup_intro_build_body": {
			"fr": "Gérez votre effectif, vos finances et votre stade.",
			"en": "Manage your roster, finances and stadium.",
			"es": "Gestiona tu plantilla, tus finanzas y tu estadio.",
			"it": "Gestisci il tuo roster, le finanze e lo stadio.",
			"pt": "Gerencie seu elenco, suas finanças e seu estádio."
		},
		"popup_intro_decisions_title": {
			"fr": "📊 Prenez les bonnes décisions",
			"en": "📊 Make the right decisions",
			"es": "📊 Toma las decisiones correctas",
			"it": "📊 Prendi le decisioni giuste",
			"pt": "📊 Tome as decisões certas"
		},
		"popup_intro_decisions_body": {
			"fr": "Recrutez des joueurs, développez votre popularité et faites progresser votre équipe.",
			"en": "Recruit players, grow your popularity and develop your team.",
			"es": "Ficha jugadores, aumenta tu popularidad y desarrolla tu equipo.",
			"it": "Ingaggia giocatori, aumenta la tua popolarità e sviluppa la tua squadra.",
			"pt": "Contrate jogadores, aumente sua popularidade e desenvolva sua equipe."
		},
		"popup_intro_sim_title": {
			"fr": "⚡ Les matchs sont simulés",
			"en": "⚡ Matches are simulated",
			"es": "⚡ Los partidos se simulan",
			"it": "⚡ Le partite sono simulate",
			"pt": "⚡ As partidas são simuladas"
		},
		"popup_intro_sim_body": {
			"fr": "Votre stratégie et votre effectif déterminent le résultat.",
			"en": "Your strategy and squad determine the result.",
			"es": "Tu estrategia y tu plantilla determinan el resultado.",
			"it": "La tua strategia e la tua rosa determinano il risultato.",
			"pt": "Sua estratégia e seu elenco determinam o resultado."
		},
		"popup_match_title": {
			"fr": "🏀 Journée de match",
			"en": "🏀 Welcome to Match Day",
			"es": "🏀 Día de partido",
			"it": "🏀 Giorno della partita",
			"pt": "🏀 Dia de jogo"
		},
		"popup_match_play_title": {
			"fr": "⚡ Lancez vos matchs",
			"en": "⚡ Launch your matches",
			"es": "⚡ Lanza tus partidos",
			"it": "⚡ Avvia le partite",
			"pt": "⚡ Lance suas partidas"
		},
		"popup_match_play_body": {
			"fr": "Suivez le déroulement du match avec un résultat visuel en temps réel.",
			"en": "Watch the game unfold with live visual results.",
			"es": "Sigue el partido con resultados visuales en tiempo real.",
			"it": "Segui la partita con risultati visivi in tempo reale.",
			"pt": "Acompanhe a partida com resultados visuais em tempo real."
		},
		"popup_match_season_title": {
			"fr": "📈 Suivez votre saison",
			"en": "📈 Follow your season",
			"es": "📈 Sigue tu temporada",
			"it": "📈 Segui la tua stagione",
			"pt": "📈 Acompanhe sua temporada"
		},
		"popup_match_season_body": {
			"fr": "Consultez le classement et suivez la progression de votre club.",
			"en": "Check the standings and track your club’s progress.",
			"es": "Consulta la clasificación y sigue el progreso de tu club.",
			"it": "Controlla la classifica e segui i progressi del tuo club.",
			"pt": "Veja a classificação e acompanhe o progresso do seu clube."
		},
		"popup_match_extra_title": {
			"fr": "🏆 Relevez des défis supplémentaires",
			"en": "🏆 Take on extra challenges",
			"es": "🏆 Acepta nuevos desafíos",
			"it": "🏆 Affronta nuove sfide",
			"pt": "🏆 Enfrente novos desafios"
		},
		"popup_match_extra_body": {
			"fr": "Participez aux tournois et accomplissez des missions pour développer votre club.",
			"en": "Join tournaments and complete missions to grow your club.",
			"es": "Participa en torneos y completa misiones para desarrollar tu club.",
			"it": "Partecipa ai tornei e completa missioni per far crescere il tuo club.",
			"pt": "Participe de torneios e complete missões para desenvolver seu clube."
		},
		"popup_stadium_title": {
			"fr": "Avant votre prochain match",
			"en": "Before your next game",
			"es": "Antes de tu próximo partido",
			"it": "Prima della tua prossima partita",
			"pt": "Antes da sua próxima partida"
		},
		"popup_stadium_body": {
			"fr": "Avant votre prochain match, il est important de gérer votre stade. Mettez un prix dans votre billetterie et votre boutique pour percevoir vos premiers revenus des visiteurs au stade.",
			"en": "Before your next game, manage your stadium. Set a price in your ticketing and shop to earn your first revenue from stadium visitors.",
			"es": "Antes de tu próximo partido, es importante gestionar tu estadio. Pon un precio en tu taquilla y en tu tienda para obtener tus primeros ingresos de los visitantes del estadio.",
			"it": "Prima della tua prossima partita, è importante gestire il tuo stadio. Imposta un prezzo per la biglietteria e il negozio per ottenere i tuoi primi ricavi dai visitatori dello stadio.",
			"pt": "Antes da sua próxima partida, é importante administrar seu estádio. Defina um preço na bilheteria e na loja para obter suas primeiras receitas dos visitantes do estádio."
		},
		"popup_stadium_cta": {
			"fr": "Go to Stadium",
			"en": "Go to Stadium",
			"es": "Go to Stadium",
			"it": "Go to Stadium",
			"pt": "Go to Stadium"
		},
		"popup_intro_close": {
			"fr": "OK",
			"en": "OK",
			"es": "OK",
			"it": "OK",
			"pt": "OK"
		}
	}

	if not data.has(key):
		return key

	var entry: Dictionary = data[key]
	return str(entry.get(lang, entry.get("en", key)))

func _bm_tr_or_fallback(key: String, fallback: String = "") -> String:
	var v := tr(key)
	if v == key or v.strip_edges() == "":
		if fallback.strip_edges() != "":
			return fallback
		return _bm_popup_fallback(key)
	return v

func _bm_popup_intro_text() -> String:
	return _bm_tr_or_fallback("popup_stadium_title") + "\n\n" \
		+ _bm_tr_or_fallback("popup_stadium_body") + "\n\n" \
		+ _bm_tr_or_fallback("popup_stadium_home_only", "Stadium visitor income only happens during home matches.")

func _bm_should_show_intro_popup_once() -> bool:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return false
	if int(save.get("season_number", 1)) != 1:
		return false
	if int(save.get("season_round", 0)) != 2:
		return false
	return not bool(save.get("intro_popup_first_match_seen", false))

func _bm_mark_intro_popup_seen() -> void:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	save["intro_popup_first_match_seen"] = true
	PL.write_savegame(save)


func _bm_play_popup_bienvenue_ball_anim() -> void:
	if img_popup_ball_bienvenue == null:
		return
	var base_top := img_popup_ball_bienvenue.offset_top
	var base_bottom := img_popup_ball_bienvenue.offset_bottom
	img_popup_ball_bienvenue.modulate.a = 1.0
	img_popup_ball_bienvenue.offset_top = base_top
	img_popup_ball_bienvenue.offset_bottom = base_bottom
	var tw_ball := create_tween()
	tw_ball.set_loops()
	tw_ball.tween_property(img_popup_ball_bienvenue, "offset_top", base_top - 10.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_ball.parallel().tween_property(img_popup_ball_bienvenue, "offset_bottom", base_bottom - 10.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_ball.tween_property(img_popup_ball_bienvenue, "offset_top", base_top, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw_ball.parallel().tween_property(img_popup_ball_bienvenue, "offset_bottom", base_bottom, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw_ball.tween_interval(0.10)

func _apply_i18n_standings_graph() -> void:
	if standings_graph_title != null:
		standings_graph_title.text = _bm_tr_or_fallback("standings.graph.title", "Évolution classement")



func _bm_get_saved_crest_id(save: Dictionary) -> String:
	var cid: String = str(save.get("club_crest_id", save.get("selected_crest_id", ""))).strip_edges()
	if cid == "" and save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		cid = str((save["roster"] as Dictionary).get("selected_crest_id", "")).strip_edges()
	return cid


func _bm_update_management_crest_header() -> void:
	var icon := get_node_or_null("ManagementCrestHeaderIcon") as TextureRect
	var glow := get_node_or_null("ManagementCrestHeaderGlow") as Panel
	if icon != null:
		icon.queue_free()
	if glow != null:
		glow.queue_free()
	return

	var save: Dictionary = PL.load_savegame()
	var cid: String = _bm_get_saved_crest_id(save)
	print("[CREST LOAD DEBUG] cid=", cid, " root=", save.get("club_crest_id", ""), " selected=", save.get("selected_crest_id", ""), " roster=", (save.get("roster", {}) as Dictionary).get("selected_crest_id", ""))
	if cid == "":
		if icon != null:
			icon.queue_free()
		if glow != null:
			glow.queue_free()
		return

	var idx_txt: String = cid.replace("starter_crest_", "")
	var idx: int = int(idx_txt)
	if idx <= 0:
		return

	var crest_path: String = "res://assets/images/blasons/blason_%d.png" % idx
	print("[CREST LOAD DEBUG] path=", crest_path, " exists=", ResourceLoader.exists(crest_path))
	if not ResourceLoader.exists(crest_path):
		return

	if glow == null:
		glow = Panel.new()
		glow.name = "ManagementCrestHeaderGlow"
		glow.set_as_top_level(true)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.z_index = 120
		add_child(glow)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.68, 0.12, 0.10)
		sb.border_color = Color(1.0, 0.76, 0.18, 0.88)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.shadow_color = Color(1.0, 0.58, 0.08, 0.38)
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 3)
		glow.add_theme_stylebox_override("panel", sb)

	if icon == null:
		icon = TextureRect.new()
		icon.name = "ManagementCrestHeaderIcon"
		icon.set_as_top_level(true)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 121
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)

	icon.texture = load(crest_path)
	icon.size = Vector2(54, 54)
	glow.size = Vector2(62, 62)

	var vp: Vector2 = get_viewport_rect().size
	var day_y: float = btn_match.global_position.y - 68.0
	if lbl_season_day != null and is_instance_valid(lbl_season_day):
		day_y = lbl_season_day.global_position.y
	var x: float = (vp.x - icon.size.x) * 0.5
	var y: float = maxf(12.0, day_y - icon.size.y - 24.0)

	glow.global_position = Vector2((vp.x - glow.size.x) * 0.5, y - 4.0)
	icon.global_position = Vector2(x, y)



func _get_league_team_count() -> int:
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss == null:
		return 12
	var st: Dictionary = ss.standings
	if st.size() > 0:
		return max(2, st.size())
	return 12


func _get_real_ranking_series() -> Array:
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss == null:
		return []

	if ss.has_method("get_ranking_history_as_float_array"):
		var hist: Array = ss.call("get_ranking_history_as_float_array")
		if hist.size() > 0:
			return hist

	return []


func _get_current_rank_fallback_series() -> Array:
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss == null:
		return [12.0]

	var save := PL.load_savegame()
	var my_name: String = str(save.get("team_name", "Mon équipe")).strip_edges()
	if my_name == "":
		my_name = "Mon équipe"

	if ss.has_method("get_current_club_rank"):
		var rank: int = int(ss.call("get_current_club_rank", my_name))
		return [float(rank)]

	return [12.0]


func _bm_goal_ordinal_rank(rank_value: int) -> String:
	var r: int = max(1, rank_value)
	var suffix := "th"
	var mod100 := r % 100
	if mod100 < 11 or mod100 > 13:
		match r % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return str(r) + suffix


func _bm_goal_current_rank(save: Dictionary) -> int:
	var team_name := str(save.get("team_name", "")).strip_edges()
	if team_name == "" and save.has("club") and typeof(save["club"]) == TYPE_DICTIONARY:
		team_name = str((save["club"] as Dictionary).get("name", "")).strip_edges()
	if team_name == "":
		team_name = "BM Club"
	if SeasonState.has_method("get_current_club_rank"):
		return int(SeasonState.get_current_club_rank(team_name))
	return 1


func _bm_maybe_show_shop_restock_notice_match14() -> void:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	if int(save.get("season_round", 0)) != 13:
		return
	if bool(save.get("shop_restock_notice_match14_seen", false)):
		return

	save["shop_restock_notice_match14_seen"] = true
	PL.write_savegame(save)

	var vp: Vector2 = get_viewport_rect().size
	var mobile := _bm_saison_is_mobile_layout()

	var overlay := Control.new()
	overlay.name = "ShopRestockNoticeOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 30000
	overlay.set_as_top_level(true)
	overlay.z_as_relative = false
	overlay.global_position = Vector2.ZERO
	overlay.size = vp

	var overlays := get_node_or_null("Overlays") as Control
	if overlays != null:
		overlays.add_child(overlay)
		overlay.move_to_front()
	else:
		add_child(overlay)
		overlay.move_to_front()

	var dark := ColorRect.new()
	dark.name = "ShopRestockNoticeBackdrop"
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.38)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dark)

	var card := Panel.new()
	card.name = "ShopRestockNoticeCard"
	var card_size := Vector2(780, 190)
	if mobile:
		card_size = Vector2(minf(vp.x * 0.88, 720.0), 178.0)
	card.size = card_size
	card.custom_minimum_size = card_size
	card.position = (vp - card_size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.94)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.78, 0.22, 0.88)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", sb)
	card.z_index = 1
	overlay.add_child(card)
	card.move_to_front()
	overlay.move_to_front()
	overlay.call_deferred("move_to_front")

	var lbl := Label.new()
	lbl.text = "Demand is growing.\nBefore the next game, check your Shop stocks and prices."
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 44 if not mobile else 36)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	card.scale = Vector2(0.92, 0.92)
	card.pivot_offset = card.size * 0.5

	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.22)
	tw.tween_interval(4.0)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)


func _bm_maybe_show_climb_standings_goal_match17() -> void:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	if bool(save.get("goal_climb_standings_match17_seen", false)):
		return

	save["goal_climb_standings_match17_seen"] = true
	PL.write_savegame(save)

	var vp: Vector2 = get_viewport_rect().size
	var mobile := _bm_saison_is_mobile_layout()

	var overlay := Control.new()
	overlay.name = "GoalClimbStandingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 30000
	overlay.set_as_top_level(true)
	overlay.z_as_relative = false
	overlay.global_position = Vector2.ZERO
	overlay.size = vp
	var overlays := get_node_or_null("Overlays") as Control
	if overlays != null:
		overlays.add_child(overlay)
		overlay.move_to_front()
	else:
		add_child(overlay)
		overlay.move_to_front()

	var dark := ColorRect.new()
	dark.name = "GoalClimbStandingsBackdrop"
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.38)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dark)

	var card := Panel.new()
	card.name = "GoalClimbStandingsCard"
	var card_size := Vector2(780, 190)
	if mobile:
		card_size = Vector2(minf(vp.x * 0.88, 720.0), 178.0)
	card.size = card_size
	card.position = (vp - card_size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.03, 0.055, 0.94)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.78, 0.22, 0.88)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", sb)
	# BM_GOAL_POPUP_CENTER_SCREEN_V2
	card.position = (vp - card.size) * 0.5
	card.z_index = 1
	overlay.add_child(card)

	var lbl := Label.new()
	lbl.text = tr("goal.climb_standings_match17").replace("{rank}", _bm_goal_ordinal_rank(_bm_goal_current_rank(save))).replace("<br>", "\n")
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 44 if not mobile else 36)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	card.scale = Vector2(0.92, 0.92)
	card.pivot_offset = card.size * 0.5

	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.22)
	tw.tween_interval(4.0)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.45)
	tw.tween_callback(overlay.queue_free)


func _refresh_standings_graph() -> void:
	if standings_graph_panel == null:
		return
	if standings_graph == null:
		return
	if not standings_graph.has_method("set_ranking_series"):
		return

	var is_classement: bool = (SeasonState.zone_selectionnee_saison == "classement")
	standings_graph_panel.visible = is_classement
	if not is_classement:
		return

	if standings_graph_title != null:
		standings_graph_title.text = _bm_tr_or_fallback("standings.graph.title", "Évolution classement")

	if standings_graph.has_method("set_graph_meta"):
		standings_graph.call("set_graph_meta", int(SeasonState.total_matchs_saison), _get_league_team_count())

	var ranking_series: Array = _get_real_ranking_series()
	if ranking_series.size() <= 0:
		ranking_series = _get_current_rank_fallback_series()

	standings_graph.call("set_ranking_series", ranking_series)


func _bm_refresh_progress_hud(animated: bool = false) -> void:
	var save := PL.load_savegame()
	var club_level_ui: int = PL.get_club_level(save)
	var club_xp_ui: int = PL.get_club_xp(save)
	var tokens_ui: int = PL.get_tokens(save)
	var first_init: bool = (_hud_last_xp_displayed < 0)

	if lbl_hud_level != null:
		lbl_hud_level.text = "Lv " + str(club_level_ui)

	if lbl_hud_tokens != null:
		lbl_hud_tokens.text = "Tokens " + str(tokens_ui)

	if lbl_hud_xp == null:
		_hud_last_xp_displayed = club_xp_ui
		_hud_last_level_displayed = club_level_ui
		return

	if _hud_xp_tween != null:
		_hud_xp_tween.kill()
		_hud_xp_tween = null

	if first_init or not animated or club_xp_ui <= _hud_last_xp_displayed:
		lbl_hud_xp.text = "XP " + str(club_xp_ui)
		_hud_last_xp_displayed = club_xp_ui
		_hud_last_level_displayed = club_level_ui
		_bm_store_progress_hud_seen(club_level_ui, club_xp_ui)
		return

	var xp_from := _hud_last_xp_displayed
	var xp_to := club_xp_ui
	var level_changed: bool = (_hud_last_level_displayed >= 0 and club_level_ui != _hud_last_level_displayed)

	var holder := {"value": xp_from}
	_hud_xp_tween = create_tween()
	_hud_xp_tween.set_trans(Tween.TRANS_SINE)
	_hud_xp_tween.set_ease(Tween.EASE_OUT)

	_hud_xp_tween.tween_method(func(v):
		holder["value"] = int(round(float(v)))
		if lbl_hud_xp != null:
			lbl_hud_xp.text = "XP " + str(int(holder["value"]))
	, xp_from, xp_to, 0.55)

	if lbl_hud_xp != null:
		lbl_hud_xp.scale = Vector2.ONE
		_hud_xp_tween.parallel().tween_property(lbl_hud_xp, "scale", Vector2(1.10, 1.10), 0.16)
		_hud_xp_tween.tween_property(lbl_hud_xp, "scale", Vector2.ONE, 0.18)

	if level_changed and lbl_hud_level != null:
		lbl_hud_level.scale = Vector2.ONE
		_hud_xp_tween.parallel().tween_property(lbl_hud_level, "scale", Vector2(1.08, 1.08), 0.16)
		_hud_xp_tween.tween_property(lbl_hud_level, "scale", Vector2.ONE, 0.18)

	_hud_xp_tween.finished.connect(func():
		if lbl_hud_xp != null:
			lbl_hud_xp.text = "XP " + str(club_xp_ui)
		if lbl_hud_level != null:
			lbl_hud_level.text = "Lv " + str(club_level_ui)
		_hud_last_xp_displayed = club_xp_ui
		_hud_last_level_displayed = club_level_ui
		_bm_store_progress_hud_seen(club_level_ui, club_xp_ui)
		_hud_xp_tween = null
	)


func _bm_store_progress_hud_seen(level_value: int, xp_value: int) -> void:
	SeasonState.set_meta("hud_last_seen_level", int(level_value))
	SeasonState.set_meta("hud_last_seen_xp", int(xp_value))


func _bm_show_market_coming_soon_popup() -> void:
	var popup := AcceptDialog.new()
	popup.title = "Market"
	popup.dialog_text = "Coming soon. Stay tuned !"
	if popup.get_label() != null:
		popup.get_label().add_theme_font_size_override("font_size", 18)
	popup.ok_button_text = "OK"
	popup.dialog_hide_on_ok = true
	popup.min_size = Vector2i(420, 0)
	add_child(popup)
	popup.popup_centered()


func _bm_format_int_spaces(v: int) -> String:
	var n := int(v)
	var neg := n < 0
	var s := str(abs(n))
	var parts: Array[String] = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))
		s = s.substr(0, s.length() - 3)
	parts.insert(0, s)
	var out := " ".join(parts)
	if neg:
		out = "-" + out
	return out

func _season_reward_menu_fmt_amount(v: int) -> String:
	return "+" + _bm_format_int_spaces(int(v)) + " €"

func _season_reward_menu_animate_amount(lbl: Label, euros_gain: int) -> void:
	if lbl == null:
		return
	var displayed: int = 0
	var start_ms: int = Time.get_ticks_msec()
	var base_gain: int = maxi(euros_gain, 10)
	var duration_ms: int = int(round(float(base_gain) / 12000.0 * 1000.0))
	duration_ms = clampi(duration_ms, 2200, 4200)

	while displayed < euros_gain and is_instance_valid(lbl) and lbl.is_inside_tree() and is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return
		var elapsed: int = Time.get_ticks_msec() - start_ms
		var ratio: float = clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)
		var target: int = int(floor((float(euros_gain) * ratio) / 10.0)) * 10
		if target > euros_gain:
			target = euros_gain
		if target > displayed:
			displayed = target
			lbl.text = _season_reward_menu_fmt_amount(displayed)

	if not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	lbl.text = _season_reward_menu_fmt_amount(euros_gain)

func _season_reward_menu_animate_tokens(lbl: Label, tokens_gain: int) -> void:
	if lbl == null or not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	if tokens_gain <= 0:
		lbl.text = "+0"
		return

	lbl.text = "+0"
	var displayed: int = 0
	while displayed < tokens_gain and is_instance_valid(lbl) and lbl.is_inside_tree() and is_inside_tree():
		displayed += 1
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return
		lbl.text = "+" + str(displayed)
		await get_tree().create_timer(0.08).timeout
		if not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return

	if not is_instance_valid(lbl) or not lbl.is_inside_tree():
		return
	lbl.text = "+" + str(tokens_gain)

func _show_mission_tokens_reward_popup(tokens_gain: int) -> void:
	if tokens_gain <= 0:
		return
	if get_node_or_null("MissionTokensRewardPopup") != null:
		return
	# BM_TOKENS_POPUP_DISPLAY_HUD_TOTAL_V1
	# Affichage UX : montrer le total réel de tokens, cohérent avec le HUD.
	var save_tokens_popup: Dictionary = PL.load_savegame()
	var tokens_display: int = tokens_gain
	if typeof(save_tokens_popup) == TYPE_DICTIONARY:
		tokens_display = PL.get_tokens(save_tokens_popup)

	var popup := Control.new()
	popup.name = "MissionTokensRewardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 265
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.66)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(360, 210)
	card.size = Vector2(430, 320)
	card.position = (get_viewport_rect().size - card.size) * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var mission_txt := _bm_tr_or_fallback("popup.tokens.first_reward.fallback_mission", "Mission completed.")
	if _mission_tokens_popup_pending_labels.size() > 0:
		var clean_labels: Array = []
		for label_any in _mission_tokens_popup_pending_labels:
			var label_txt := str(label_any).strip_edges()
			if label_txt != "":
				clean_labels.append(label_txt)
		if clean_labels.size() > 0:
			mission_txt = " + ".join(clean_labels)
	_mission_tokens_popup_pending_labels = []

	var lbl_mission := Label.new()
	lbl_mission.text = mission_txt.strip_edges() + ". Congrats !"
	lbl_mission.position = Vector2(20, 18)
	lbl_mission.size = Vector2(320, 34)
	lbl_mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mission.add_theme_font_size_override("font_size", 24)
	card.add_child(lbl_mission)

	var lbl_line2 := Label.new()
	lbl_line2.text = _bm_tr_or_fallback("popup.tokens.first_reward.line2", "You just earned {amount} tokens.").replace("{amount}", str(tokens_display))
	lbl_line2.position = Vector2(20, 155)
	lbl_line2.size = Vector2(390, 30)
	lbl_line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_line2.add_theme_font_size_override("font_size", 22)
	card.add_child(lbl_line2)

	var lbl_line3 := Label.new()
	lbl_line3.text = _bm_tr_or_fallback("popup.tokens.first_reward.line3", "Tokens unlock premium upgrades and special content.")
	lbl_line3.position = Vector2(20, 188)
	lbl_line3.size = Vector2(390, 30)
	lbl_line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_line3.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_line3.add_theme_font_size_override("font_size", 22)
	card.add_child(lbl_line3)

	var tokens_row := HBoxContainer.new()
	tokens_row.position = Vector2(15, 74)
	tokens_row.size = Vector2(400, 62)
	tokens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens_row.add_theme_constant_override("separation", 8)
	card.add_child(tokens_row)

	var tokens_amount_lbl := Label.new()
	tokens_amount_lbl.text = "+0"
	tokens_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tokens_amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tokens_amount_lbl.add_theme_font_size_override("font_size", 48)
	tokens_amount_lbl.add_theme_color_override("font_color", Color(1.00, 0.72, 0.18, 1.0))
	tokens_row.add_child(tokens_amount_lbl)

	var tokens_icon := TextureRect.new()
	tokens_icon.texture = TOKEN_ICON
	tokens_icon.custom_minimum_size = Vector2(40, 40)
	tokens_icon.size = Vector2(40, 40)
	tokens_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tokens_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tokens_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tokens_row.add_child(tokens_icon)

	var btn := Button.new()
	btn.text = "Close"
	btn.custom_minimum_size = Vector2(160, 46)
	btn.size = Vector2(160, 46)
	btn.position = Vector2(120, 235)
	btn.pressed.connect(func():
		popup.queue_free()
	)
	card.add_child(btn)

	_season_reward_menu_animate_tokens(tokens_amount_lbl, tokens_display)


func _bm_flush_pending_mission_tokens_popup() -> void:
	if _mission_tokens_popup_pending <= 0 and _mission_tokens_popup_pending_labels.is_empty():
		return
	if get_node_or_null("LastMatchFinancePopup") != null:
		call_deferred("_bm_flush_pending_mission_tokens_popup_after_frame")
		return
	if get_node_or_null("MissionTokensRewardPopup") != null:
		return
	var tokens_gain := maxi(1, _mission_tokens_popup_pending)
	_mission_tokens_popup_pending = 0
	call_deferred("_show_mission_tokens_reward_popup", tokens_gain)


func _bm_flush_pending_mission_tokens_popup_after_frame() -> void:
	await get_tree().process_frame
	_bm_flush_pending_mission_tokens_popup()


func _last_match_finance_fmt_signed_amount(v: int) -> String:
	var sign := "+"
	if v < 0:
		sign = "-"
	return sign + _bm_format_int_spaces(abs(v)) + " €"

func _last_match_finance_animate_xp(lbl: Label, xp_gain: int) -> void:
	if lbl == null or not is_instance_valid(lbl):
		return
	if xp_gain <= 0:
		if is_instance_valid(lbl):
			lbl.text = "+0 XP"
		return

	lbl.text = "+0 XP"
	var displayed: int = 0
	while displayed < xp_gain:
		if lbl == null or not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return
		displayed += 1
		lbl.text = "+" + str(displayed) + " XP"
		await get_tree().create_timer(0.08).timeout
		if lbl == null or not is_instance_valid(lbl) or not lbl.is_inside_tree():
			return

	if lbl != null and is_instance_valid(lbl) and lbl.is_inside_tree():
		lbl.text = "+" + str(xp_gain) + " XP"

func _show_pending_season_reward_popup(rank: int, euros_gain: int, tokens_gain: int) -> void:
	var already := get_node_or_null("SeasonRewardPopup")
	if already != null:
		return
	if euros_gain <= 0 and tokens_gain <= 0:
		return

	var popup := Control.new()
	popup.name = "SeasonRewardPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 260
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(620, 340)
	card.size = Vector2(620, 340)
	card.position = Vector2(
		(get_viewport_rect().size.x - 620.0) * 0.5,
		(get_viewport_rect().size.y - 340.0) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = "Season reward"
	title.position = Vector2(0, 24)
	title.size = Vector2(620, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	card.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Final rank: #" + str(rank)
	subtitle.position = Vector2(0, 66)
	subtitle.size = Vector2(620, 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(subtitle)

	var subtitle_money := Label.new()
	subtitle_money.text = "Prize money"
	subtitle_money.position = Vector2(45, 116)
	subtitle_money.size = Vector2(230, 32)
	subtitle_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_money.add_theme_font_size_override("font_size", 22)
	card.add_child(subtitle_money)

	var subtitle_tokens := Label.new()
	subtitle_tokens.text = "Prize tokens"
	subtitle_tokens.position = Vector2(345, 116)
	subtitle_tokens.size = Vector2(230, 32)
	subtitle_tokens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_tokens.add_theme_font_size_override("font_size", 22)
	subtitle_tokens.add_theme_color_override("font_color", Color(1.00, 0.82, 0.30, 1.0))
	card.add_child(subtitle_tokens)

	var amount_lbl := Label.new()
	amount_lbl.text = _season_reward_menu_fmt_amount(0)
	amount_lbl.position = Vector2(45, 158)
	amount_lbl.size = Vector2(230, 54)
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 42)
	amount_lbl.add_theme_color_override("font_color", Color(0.18, 0.72, 0.25, 1.0))
	card.add_child(amount_lbl)

	var tokens_row := HBoxContainer.new()
	tokens_row.position = Vector2(345, 158)
	tokens_row.size = Vector2(230, 54)
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
	btn.text = "Close"
	btn.custom_minimum_size = Vector2(180, 52)
	btn.size = Vector2(180, 52)
	btn.position = Vector2(220, 254)
	btn.pressed.connect(func():
		popup.queue_free()
	)
	card.add_child(btn)

	_season_reward_menu_animate_amount(amount_lbl, euros_gain)
	_season_reward_menu_animate_tokens(tokens_amount_lbl, tokens_gain)

func _maybe_show_pending_season_reward_popup() -> void:
	var PL = load("res://scripts/PlayerLife.gd")
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	if not save.has("pending_season_reward_popup") or typeof(save["pending_season_reward_popup"]) != TYPE_DICTIONARY:
		return

	var reward: Dictionary = save["pending_season_reward_popup"] as Dictionary
	var rank: int = int(reward.get("rank", 0))
	var euros_gain: int = int(reward.get("euros", 0))
	var tokens_gain: int = int(reward.get("tokens", 0))

	save.erase("pending_season_reward_popup")
	PL.write_savegame(save)

	if euros_gain > 0 or tokens_gain > 0:
		call_deferred("_show_pending_season_reward_popup", rank, euros_gain, tokens_gain)

func _show_pending_season_reward_popup_after_end_season() -> void:
	var PL = load("res://scripts/PlayerLife.gd")
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	if not save.has("pending_season_reward_popup") or typeof(save["pending_season_reward_popup"]) != TYPE_DICTIONARY:
		return

	var reward: Dictionary = save["pending_season_reward_popup"] as Dictionary
	var rank: int = int(reward.get("rank", 0))
	var euros_gain: int = int(reward.get("euros", 0))
	var tokens_gain: int = int(reward.get("tokens", 0))

	save.erase("pending_season_reward_popup")
	PL.write_savegame(save)

	if euros_gain > 0 or tokens_gain > 0:
		call_deferred("_show_pending_season_reward_popup", rank, euros_gain, tokens_gain)


func _show_last_match_finance_popup(recettes_gain: int, depenses_gain: int, xp_gain: int) -> void:
	var already := get_node_or_null("LastMatchFinancePopup")
	if already != null:
		return

	var popup := Control.new()
	popup.name = "LastMatchFinancePopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 240
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var card := Panel.new()
	var card_w: float = 700.0
	var card_h: float = 360.0
	if _bm_saison_is_mobile_layout():
		card_w *= 1.15
		card_h *= 1.15
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	card.position = Vector2(
		(get_viewport_rect().size.x - card_w) * 0.5,
		(get_viewport_rect().size.y - card_h) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(card)

	var title := Label.new()
	title.text = _bm_tr_or_fallback("popup.last_match_finance.title", "Last match financial summary")
	title.position = Vector2(40, 24)
	title.size = Vector2(620, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var lbl_income_title := Label.new()
	lbl_income_title.text = _bm_tr_or_fallback("popup.last_match_finance.income", "Income")
	lbl_income_title.position = Vector2(70, 95)
	lbl_income_title.size = Vector2(180, 32)
	lbl_income_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_income_title.add_theme_font_size_override("font_size", 22)
	lbl_income_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(lbl_income_title)

	var lbl_expenses_title := Label.new()
	lbl_expenses_title.text = _bm_tr_or_fallback("popup.last_match_finance.expenses", "Expenses")
	lbl_expenses_title.position = Vector2(260, 95)
	lbl_expenses_title.size = Vector2(180, 32)
	lbl_expenses_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_expenses_title.add_theme_font_size_override("font_size", 22)
	lbl_expenses_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(lbl_expenses_title)

	var lbl_xp_title := Label.new()
	lbl_xp_title.text = _bm_tr_or_fallback("popup.last_match_finance.xp", "XP")
	lbl_xp_title.position = Vector2(450, 95)
	lbl_xp_title.size = Vector2(180, 32)
	lbl_xp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_xp_title.add_theme_font_size_override("font_size", 22)
	lbl_xp_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(lbl_xp_title)

	var income_lbl := Label.new()
	income_lbl.text = _season_reward_menu_fmt_amount(0)
	income_lbl.position = Vector2(70, 150)
	income_lbl.size = Vector2(180, 52)
	income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	income_lbl.add_theme_font_size_override("font_size", 38)
	income_lbl.add_theme_color_override("font_color", Color(0.18, 0.72, 0.25, 1.0))
	card.add_child(income_lbl)

	var expenses_lbl := Label.new()
	expenses_lbl.text = "-0 €"
	expenses_lbl.position = Vector2(260, 150)
	expenses_lbl.size = Vector2(180, 52)
	expenses_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expenses_lbl.add_theme_font_size_override("font_size", 38)
	expenses_lbl.add_theme_color_override("font_color", Color(0.86, 0.22, 0.22, 1.0))
	card.add_child(expenses_lbl)

	var xp_lbl := Label.new()
	xp_lbl.text = "+0 XP"
	xp_lbl.position = Vector2(450, 150)
	xp_lbl.size = Vector2(180, 52)
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_lbl.add_theme_font_size_override("font_size", 38)
	xp_lbl.add_theme_color_override("font_color", Color(0.20, 0.55, 0.95, 1.0))
	card.add_child(xp_lbl)

	var ball := TextureRect.new()
	ball.texture = load("res://assets/images/ball.png") as Texture2D
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.custom_minimum_size = Vector2(44, 44)
	ball.size = Vector2(44, 44)
	ball.position = Vector2(328, 214)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ball)

	var tw_ball := create_tween()
	tw_ball.set_loops()
	tw_ball.tween_property(ball, "position:y", 204.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_ball.tween_property(ball, "position:y", 214.0, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw_ball.tween_interval(0.10)

	var btn := Button.new()
	var _save_cta: Dictionary = PL.load_savegame()
	var _round_cta: int = 0
	if typeof(_save_cta) == TYPE_DICTIONARY:
		_round_cta = int(_save_cta.get("season_round", 0))
	var _open_finances_cta: bool = (_round_cta <= 1)
	btn.text = (_bm_tr_or_fallback("popup.last_match_finance.cta_finances", "See club finances") if _open_finances_cta else "Close")
	btn.custom_minimum_size = Vector2(320, 52)
	btn.size = Vector2(320, 52)
	btn.position = Vector2(190, 270)

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
	btn.add_theme_stylebox_override("normal", _sb_close)

	var _sb_close_hover := _sb_close.duplicate()
	_sb_close_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
	btn.add_theme_stylebox_override("hover", _sb_close_hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func():
		var tree := get_tree()
		popup.queue_free()
		call_deferred("_bm_flush_pending_mission_tokens_popup_after_frame")
		var round_cta_now: int = _round_cta
		var save_cta_now: Dictionary = PL.load_savegame()
		if typeof(save_cta_now) == TYPE_DICTIONARY:
			round_cta_now = int(save_cta_now.get("season_round", round_cta_now))
			if save_cta_now.has("progress") and typeof(save_cta_now["progress"]) == TYPE_DICTIONARY:
				round_cta_now = maxi(round_cta_now, int((save_cta_now["progress"] as Dictionary).get("journee", round_cta_now + 1)) - 1)
		if round_cta_now == 13:
			call_deferred("_bm_maybe_show_shop_restock_notice_match14")

		if round_cta_now == 18:
			call_deferred("_bm_maybe_show_climb_standings_goal_match17")

		if round_cta_now >= int(SeasonState.total_matchs_saison):
			call_deferred("_open_end_season_popup")
			return

		if _open_finances_cta and tree != null and ResourceLoader.exists("res://scenes/Finances.tscn"):
			tree.call_deferred("change_scene_to_file", "res://scenes/Finances.tscn")
	)
	card.add_child(btn)

	# BM_LAST_MATCH_FINANCE_POPUP_TEXT_PLUS4_FORCE_V3
	title.add_theme_font_size_override("font_size", 32)
	lbl_income_title.add_theme_font_size_override("font_size", 26)
	lbl_expenses_title.add_theme_font_size_override("font_size", 26)
	lbl_xp_title.add_theme_font_size_override("font_size", 26)
	income_lbl.add_theme_font_size_override("font_size", 42)
	expenses_lbl.add_theme_font_size_override("font_size", 42)
	xp_lbl.add_theme_font_size_override("font_size", 42)
	btn.add_theme_font_size_override("font_size", 28)
	if _bm_saison_is_mobile_layout():
		lbl_income_title.add_theme_font_size_override("font_size", 28)
		lbl_expenses_title.add_theme_font_size_override("font_size", 28)
		lbl_xp_title.add_theme_font_size_override("font_size", 28)
		income_lbl.add_theme_font_size_override("font_size", 44)
		expenses_lbl.add_theme_font_size_override("font_size", 44)
		xp_lbl.add_theme_font_size_override("font_size", 44)

	_season_reward_menu_animate_amount(income_lbl, recettes_gain)

	var dep_abs: int = abs(depenses_gain)
	if dep_abs <= 0:
		if is_instance_valid(expenses_lbl) and expenses_lbl.is_inside_tree():
			expenses_lbl.text = "-0 €"
	else:
		var displayed: int = 0
		while displayed < dep_abs and is_instance_valid(expenses_lbl) and expenses_lbl.is_inside_tree() and is_inside_tree():
			await get_tree().process_frame
			if not is_instance_valid(expenses_lbl) or not expenses_lbl.is_inside_tree():
				return
			displayed = mini(dep_abs, displayed + maxi(1, int(ceil(float(dep_abs) / 40.0))))
			expenses_lbl.text = "-" + _bm_format_int_spaces(displayed) + " €"
		if not is_instance_valid(expenses_lbl) or not expenses_lbl.is_inside_tree():
			return
		expenses_lbl.text = "-" + _bm_format_int_spaces(dep_abs) + " €"

	_last_match_finance_animate_xp(xp_lbl, xp_gain)

func _maybe_show_last_match_finance_popup() -> void:
	var save: Dictionary = PL.load_savegame()

	# 🚫 BLOQUE popup si aucun match joué
	var matchs_joues := int(save.get("season_round", 0))
	if matchs_joues == 0:
		return
	var recettes_gain: int = int(save.get("last_match_finance_recettes", 0))
	var depenses_gain: int = int(save.get("last_match_finance_depenses", 0))
	var xp_gain: int = int(save.get("last_match_finance_xp", 0))

	# 🚫 Anti-popup fantôme : si pending existe mais sans vraies valeurs,
	# on consomme le flag et on nettoie immédiatement.
	if recettes_gain == 0 and depenses_gain == 0 and xp_gain == 0:
		save["last_match_finance_popup_pending"] = false
		save.erase("last_match_finance_recettes")
		save.erase("last_match_finance_depenses")
		save.erase("last_match_finance_xp")
		PL.write_savegame(save)
		return

	save["last_match_finance_popup_pending"] = false
	save.erase("last_match_finance_recettes")
	save.erase("last_match_finance_depenses")
	save.erase("last_match_finance_xp")
	PL.write_savegame(save)
	_last_match_finance_popup_shown_this_entry = true

	call_deferred("_show_last_match_finance_popup", recettes_gain, depenses_gain, xp_gain)



func _show_match_compo_intro_popup() -> void:
	return

func _maybe_show_match_compo_intro_popup() -> void:
	return

func _bm_apply_early_tabs_visibility() -> void:
	var d_any: Variant = PL.load_savegame()
	if typeof(d_any) != TYPE_DICTIONARY:
		return
	var d: Dictionary = d_any as Dictionary

	var matches_played: int = int(d.get("season_round", 0))

	var btn_calendar = get_node_or_null("UI/Tabs/BtnCalendrier")
	var btn_standings = get_node_or_null("UI/Tabs/BtnClassement")
	var btn_market = get_node_or_null("UI/Tabs/BtnMercato")
	var btn_missions = get_node_or_null("UI/Tabs/BtnMissions")
	var btn_tournament = get_node_or_null("UI/Tabs/BtnTournois")

	# Toujours visible
	if btn_calendar != null:
		btn_calendar.visible = true

	# Market visible seulement après le match 20 joué
	if btn_market != null:
		btn_market.visible = (int(d.get("season_number", 1)) >= 2)
		btn_market.disabled = false

	# Toujours cachés dans ce flow early
	if btn_missions != null:
		btn_missions.visible = (matches_played >= 15)
	if btn_tournament != null:
		btn_tournament.visible = (matches_played >= 10)

	# Classement seulement après le 1er match
	if btn_standings != null:
		btn_standings.visible = (matches_played >= 1)


func _bm_ensure_season_start_progress_baseline() -> void:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return
	var changed := false
	if not save.has("season_start_xp"):
		save["season_start_xp"] = PL.get_club_xp(save)
		changed = true
	if not save.has("season_start_tokens"):
		save["season_start_tokens"] = PL.get_tokens(save)
		changed = true
	if changed:
		PL.write_savegame(save)

func _ready() -> void:
	PL._bm_debug_dump_active_save_path()
	call_deferred("_bm_update_management_crest_header")
	_bm_ensure_season_start_progress_baseline()
	var save_boot := PL.load_savegame()
	var boot_level := PL.get_club_level(save_boot)
	var boot_xp := PL.get_club_xp(save_boot)
	var seen_level := boot_level
	var seen_xp := boot_xp
	var animate_progress := false
	if SeasonState.has_meta("hud_last_seen_xp"):
		seen_xp = int(SeasonState.get_meta("hud_last_seen_xp"))
		seen_level = int(SeasonState.get_meta("hud_last_seen_level", boot_level))
		animate_progress = (boot_xp > seen_xp)

	_hud_last_xp_displayed = seen_xp
	_hud_last_level_displayed = seen_level
	_bm_refresh_progress_hud(animate_progress)
	var _missions_boot_save: Dictionary = PL.load_savegame()
	if typeof(_missions_boot_save) == TYPE_DICTIONARY:
		var _missions_boot_level := _missions_get_level()
		var _missions_boot_level_data: Array = _missions_get_level_data(_missions_boot_level)
		var _missions_boot_counters: Dictionary = _missions_get_counters(_missions_boot_save)
		if _missions_auto_claim_reached(_missions_boot_save, _missions_boot_level_data, _missions_boot_counters) > 0:
			_bm_refresh_progress_hud(false)
	_bm_apply_i18n_btn_retour()
	_apply_i18n_tabs()
	_apply_i18n()
	_apply_i18n_standings_graph()
	_ensure_saison_buttons_active()
	var save: Dictionary = PL.load_savegame()
	PL.ensure_mercato_schema(save)
	var mercato_boot: Dictionary = save.get("mercato", {}) as Dictionary
	var mercato_ids_boot: Array = mercato_boot.get("current_ids", []) as Array
	if mercato_ids_boot.is_empty():
		PL.refresh_mercato_pool(save, "boot")
		PL.write_savegame(save)

	_ensure_season_day_label()
	var save_after := PL.load_savegame()
	if save_after.has("pending_season_reward") and typeof(save_after["pending_season_reward"]) == TYPE_DICTIONARY:
		var r: Dictionary = save_after["pending_season_reward"] as Dictionary
		save_after.erase("pending_season_reward")
		PL.write_savegame(save_after)
		call_deferred("_show_season_reward_popup", int(r.get("rank", 0)), int(r.get("euros", 0)), int(r.get("tokens", 0)))

	_maybe_show_last_match_finance_popup()
	if not _last_match_finance_popup_shown_this_entry:
		var save_popup_gate: Dictionary = PL.load_savegame()
		if typeof(save_popup_gate) == TYPE_DICTIONARY:
			var round_popup_gate: int = int(save_popup_gate.get("season_round", 0))
			if save_popup_gate.has("progress") and typeof(save_popup_gate["progress"]) == TYPE_DICTIONARY:
				round_popup_gate = maxi(round_popup_gate, int((save_popup_gate["progress"] as Dictionary).get("journee", round_popup_gate + 1)) - 1)
			if round_popup_gate >= int(SeasonState.total_matchs_saison):
				call_deferred("_open_end_season_popup")
			elif round_popup_gate == 18:
				call_deferred("_bm_maybe_show_climb_standings_goal_match17")
	# BM_SHOP_RESTOCK_NOTICE_AFTER_FINANCE_POPUP_V1: déclenché après fermeture du popup de fin de match
	for _nm in ["PopularityBadge", "PopularityBadge2"]:
		var _pop_lbl := get_node_or_null("UI/%s" % _nm) as Label
		if _pop_lbl == null:
			_pop_lbl = get_node_or_null(_nm) as Label
		if _pop_lbl != null:
			_pop_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if btn_close_classement != null:
		btn_close_classement.mouse_filter = Control.MOUSE_FILTER_STOP

	# BtnMatch micro hover (léger, HTML5)
	if btn_match != null:
		_btn_match_base_scale = btn_match.scale
		_btn_match_base_pos = btn_match.position
		if not btn_match.mouse_entered.is_connected(_on_btn_match_mouse_entered):
			btn_match.mouse_entered.connect(_on_btn_match_mouse_entered)
		if not btn_match.mouse_exited.is_connected(_on_btn_match_mouse_exited):
			btn_match.mouse_exited.connect(_on_btn_match_mouse_exited)

	# Close X Classement (ne dépend pas de BtnMatch)
	if btn_close_classement != null:
		btn_close_classement.focus_mode = Control.FOCUS_NONE
		btn_close_classement.disabled = false
		btn_close_classement.visible = false
		if not btn_close_classement.pressed.is_connected(_on_btn_close_classement_pressed):
			btn_close_classement.pressed.connect(_on_btn_close_classement_pressed)
		if not btn_close_classement.gui_input.is_connected(_on_close_x_gui_input):
			btn_close_classement.gui_input.connect(_on_close_x_gui_input)


	if btn_match != null:
		btn_match.text = tr("season.btn_play_match")
		_bm_style_btn_match_action()
		var _save := PL.load_savegame()
		if int(_save.get("matchs_joues", 0)) == 0:
			call_deferred("_bm_add_play_match_halo")
	# --- FIX INPUT GLOBAL ---
	mouse_filter = Control.MOUSE_FILTER_PASS

	get_node("UI").mouse_filter = Control.MOUSE_FILTER_PASS
	get_node("UI/Tabs").mouse_filter = Control.MOUSE_FILTER_PASS

	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_node("Overlays").mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	# Fond d'écran Saison
	bg.texture = load("res://assets/images/backgrounds/fond_saison.png")

	# ✅ CRITIQUE : ne bloque pas les clics
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_bm_saison_apply_mobile_bg_and_halo_layout")
	call_deferred("_bm_saison_apply_mobile_hud_layout")
	call_deferred("_bm_saison_apply_mobile_top_left_buttons_plus20_text_plus2")
	call_deferred("_bm_saison_apply_mobile_play_button_plus20_text_plus2")
	call_deferred("_bm_saison_apply_mobile_day_and_popularity_texts")
	call_deferred("_bm_saison_align_mobile_play_and_day")

	# Early flow tabs visibility
	_bm_apply_early_tabs_visibility()

	if popup_bienvenue != null:
		var _sb_popup_bienvenue := StyleBoxFlat.new()
		_sb_popup_bienvenue.bg_color = Color(0.03, 0.04, 0.08, 0.94)
		_sb_popup_bienvenue.corner_radius_top_left = 18
		_sb_popup_bienvenue.corner_radius_top_right = 18
		_sb_popup_bienvenue.corner_radius_bottom_left = 18
		_sb_popup_bienvenue.corner_radius_bottom_right = 18
		_sb_popup_bienvenue.border_width_left = 2
		_sb_popup_bienvenue.border_width_top = 2
		_sb_popup_bienvenue.border_width_right = 2
		_sb_popup_bienvenue.border_width_bottom = 2
		_sb_popup_bienvenue.border_color = Color(0.85, 0.75, 0.25, 0.22)
		popup_bienvenue.add_theme_stylebox_override("panel", _sb_popup_bienvenue)

	if btn_close_bienvenue != null:
		btn_close_bienvenue.text = _bm_tr_or_fallback("popup_stadium_cta", "Go to Stadium")
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
		btn_close_bienvenue.add_theme_stylebox_override("normal", _sb_close)

		var _sb_close_hover := _sb_close.duplicate()
		_sb_close_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
		btn_close_bienvenue.add_theme_stylebox_override("hover", _sb_close_hover)
		btn_close_bienvenue.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var _btn_fs = int(btn_close_bienvenue.get_theme_font_size("font_size"))
		if _bm_saison_is_mobile_layout():
			btn_close_bienvenue.add_theme_font_size_override("font_size", _btn_fs + 10)
		else:
			btn_close_bienvenue.add_theme_font_size_override("font_size", _btn_fs + 4)
	if lbl_bienvenue != null:
		lbl_bienvenue.size.x += 140.0
		var _txt = _bm_popup_intro_text()
		_txt = _txt.replace("🏀", ">>").replace("⚡", ">>").replace("📈", ">>").replace("🏆", ">>")
		# centre uniquement la 1ère ligne (titre)
		var _lines = _txt.split("\n")
		if _lines.size() > 0:
			var _title = _lines[0].replace(">>", "").strip_edges()
			_lines[0] = "[center][font_size=32][b]" + _title + "[/b][/font_size][/center]"
			for _i in range(1, _lines.size()):
				if str(_lines[_i]).strip_edges() != "":
					_lines[_i] = "[font_size=30]" + str(_lines[_i]) + "[/font_size]"
		_txt = "\n".join(_lines)

		lbl_bienvenue.bbcode_enabled = true
		lbl_bienvenue.scroll_active = false
		lbl_bienvenue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_bienvenue.fit_content = false

		lbl_bienvenue.add_theme_font_size_override("normal_font_size", 30)
		lbl_bienvenue.add_theme_font_size_override("bold_font_size", 30)
		lbl_bienvenue.add_theme_font_size_override("italics_font_size", 30)
		lbl_bienvenue.add_theme_font_size_override("bold_italics_font_size", 30)

		lbl_bienvenue.text = _txt
		lbl_bienvenue.size = lbl_bienvenue.size + Vector2(0.0, 220.0)


	# Popup bienvenue affichée une seule fois
	if popup_bienvenue != null:
		popup_bienvenue.size = popup_bienvenue.size + Vector2(140.0, 180.0)
		popup_bienvenue.z_index = 500
		popup_bienvenue.set_as_top_level(true)
		if _bm_saison_is_mobile_layout():
			popup_bienvenue.size = popup_bienvenue.size + Vector2(30.0, 40.0)
			var _vp_popup := get_viewport_rect().size
			popup_bienvenue.position = (_vp_popup - popup_bienvenue.size) * 0.5
			popup_bienvenue.move_to_front()

	popup_bienvenue.visible = _bm_should_show_intro_popup_once()
	if popup_bienvenue.visible:
		_bm_play_popup_bienvenue_ball_anim()


	# IMPORTANT: un overlay invisible ne doit pas bloquer les clics
	popup_bienvenue.mouse_filter = (Control.MOUSE_FILTER_STOP if popup_bienvenue.visible else Control.MOUSE_FILTER_IGNORE)
	# Connexions onglets (équivalent SAISON_MENU_MAP Python)
	btn_classement.pressed.connect(func(): _select_zone("classement"))
	btn_statistiques.pressed.connect(func(): _select_zone("statistiques"))
	btn_calendrier.pressed.connect(func(): _bm_stop_unlock_glow(btn_calendrier); _select_zone("calendrier"))
	btn_mercato.pressed.connect(func(): _bm_open_mercato_from_saison())

	# Boutons secondaires
	btn_retour.pressed.connect(_on_retour_pressed)
	if btn_tournois != null:
		btn_tournois.pressed.connect(_on_tournois_pressed)
	btn_match.pressed.connect(func(): _bm_stop_all_unlock_glows(); _on_match_pressed())

	# Popup bienvenue
	btn_close_bienvenue.pressed.connect(_on_close_bienvenue_pressed)
	if missions_panel != null:
		missions_panel.visible = false
		missions_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_close_missions != null and not btn_close_missions.pressed.is_connected(_on_close_missions_pressed):
		btn_close_missions.pressed.connect(_on_close_missions_pressed)
	if btn_claim_mission != null and not btn_claim_mission.pressed.is_connected(_on_claim_mission_pressed):
		btn_claim_mission.pressed.connect(_on_claim_mission_pressed)
	_missions_apply_button_styles()


	# Re-force early flow tabs visibility after all setup
	_bm_apply_early_tabs_visibility()
	call_deferred("_bm_apply_unlock_glows")
	_bm_apply_unlock_glows()

	# DEBUG: confirmer que le clic Calendrier arrive
	if btn_calendrier != null:
		btn_calendrier.pressed.connect(func():
			print("[SAISON] BtnCalendrier pressed (raw)")
			_select_zone("calendrier")
		)
	# --- DEBUG calendrier: vérifier bouton + clic
	print("[SAISON][CHK] popup_visible=", popup_bienvenue.visible)
	print("[SAISON][CHK] BtnCalendrier=", btn_calendrier)
	if btn_calendrier != null:
		print("[SAISON][CHK] BtnCalendrier disabled=", btn_calendrier.disabled, " visible=", btn_calendrier.visible, " mouse_filter=", btn_calendrier.mouse_filter)
		btn_calendrier.pressed.connect(func():
			print("[SAISON] BtnCalendrier pressed (raw)")
			_select_zone("calendrier")
		)
		
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("CLICK DETECTED AT ROOT")
		# PRIORITÉ: clic sur BtnRetour -> bascule Management (évite clear zone)
		if btn_retour != null:
			var r := btn_retour.get_global_rect()
			if r.has_point(get_global_mouse_position()):
				print("[SAISON] BtnRetour clicked at ROOT -> go Management")
				_on_btn_retour_pressed()
				return

	# Guard anti-réouverture après fermeture croix
	if Time.get_ticks_msec() < _close_x_lock_until_ms:
		return

	# _close_x_intercept_root
	# Si Classement est affiché et que le clic tombe sur la croix, on ferme immédiatement
	# + lock anti-réouverture (même frame / même clic) + hide UI fallback.
	if SeasonState.zone_selectionnee_saison == "classement" and btn_close_classement != null and btn_close_classement.visible:
		# Si on vient juste de fermer, on ignore les clics ROOT le temps que l'UI se mette à jour
		if Time.get_ticks_msec() < _close_x_lock_until_ms:
			return

		var mp: Vector2 = get_viewport().get_mouse_position()
		if mp.y > 120.0 and btn_close_classement.get_global_rect().has_point(mp):
			_close_x_lock_until_ms = Time.get_ticks_msec() + 200
			SeasonState.zone_selectionnee_saison = ""
			_force_hide_classement_ui()
			print("[SAISON] close X intercepted at ROOT -> classement fermé (lock=200ms)")
			return



# --- Sélection d’onglet ---
func _select_zone(zone: String) -> void:
	# Priorité overlay (comme Python)
	if popup_bienvenue != null and popup_bienvenue.visible:
		return

	# Si on quitte Classement, on le referme automatiquement
	if zone != "classement":
		_force_hide_classement_ui()
		if standings_panel != null:
			standings_panel.visible = false
		if standings_graph_panel != null:
			standings_graph_panel.visible = false

	SeasonState.zone_selectionnee_saison = zone
	if zone == "classement":
		_on_btn_classement_show_standings_pressed()
	print("[SAISON] zone_selectionnee_saison =", SeasonState.zone_selectionnee_saison)

	if zone == "calendrier":
		_open_calendrier_modal()
	elif zone == "mercato":
		_bm_show_market_coming_soon_popup()



# --- Bouton Retour ---
func _on_retour_pressed() -> void:
	if popup_bienvenue.visible:
		return
	# IMPORTANT: ne pas clear l'onglet Saison — on conserve l'état tant qu'aucun nouveau match
	print("[SAISON] retour -> go Management (keep zone_selectionnee_saison)")
	_on_btn_retour_pressed()

func _on_tournois_pressed() -> void:
	if popup_bienvenue != null and popup_bienvenue.visible:
		return
	_bm_stop_unlock_glow(btn_tournois)
	var tree := get_tree()
	if tree == null:
		print("[SAISON] get_tree() null -> impossible d'ouvrir TournoisAccueil")
		return
	if ResourceLoader.exists("res://scenes/TournoisAccueil.tscn"):
		tree.change_scene_to_file("res://scenes/TournoisAccueil.tscn")
		print("[SAISON] -> change_scene_to_file(TournoisAccueil)")
	else:
		print("[SAISON] TournoisAccueil.tscn introuvable")


func _on_tournois_back_requested() -> void:
	_bm_refresh_progress_hud(true)
	visible = true
	print("[SAISON] retour depuis TournoisAccueil -> MenuSaison")


func _prepare_new_season() -> void:
	var save := PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		print("[SAISON] Nouvelle saison annulée: save invalide")
		return

	if not save.has("progress") or typeof(save["progress"]) != TYPE_DICTIONARY:
		save["progress"] = {}

	var popularity_keep: int = int(save.get("popularite", 50))
	var current_season_number := int(save.get("season_number", 1))
	if current_season_number < 1:
		current_season_number = 1
	var end_summary_for_crest: Dictionary = _get_end_season_summary()
	if int(end_summary_for_crest.get("rank", 12)) == 1:
		save["club_season_winner_badge_until_season"] = current_season_number + 1
	save["season_number"] = current_season_number + 1
	save["season_id"] = "season_" + str(int(save["season_number"]))

	save["season_round"] = 0
	save["last_pop_fin_round"] = -1
	save["season_results"] = {}

	if save.has("roster") and typeof(save["roster"]) == TYPE_DICTIONARY:
		var roster_reset: Dictionary = save["roster"] as Dictionary
		roster_reset["auto_save_match_selection_paid"] = false
		roster_reset["match_selected_ids"] = []
		save["roster"] = roster_reset
	save["season_start_xp"] = PL.get_club_xp(save)
	save["season_start_tokens"] = PL.get_tokens(save)
	save["season_xp_earned"] = 0
	save["season_tokens_earned"] = 0

	# --- Coach contrat / coût saisonnier ---
	PL.ensure_progression_wallet_schema(save)
	if save.has("coachs") and typeof(save["coachs"]) == TYPE_DICTIONARY:
		var coachs: Dictionary = save["coachs"] as Dictionary
		var active_coach_id: String = str(coachs.get("active", "")).strip_edges()
		if active_coach_id != "":
			var duration_map := {
				"coach_junior": 2,
				"coach_confirme": 3,
				"coach_elite": 2
			}
			var duration: int = int(duration_map.get(active_coach_id, 1))
			var current_season: int = maxi(1, int(save.get("season_number", 1)))
			var hired_season: int = maxi(1, int(coachs.get("last_hired_season", current_season)))
			var used_seasons: int = current_season - hired_season + 1

			if used_seasons > duration:
				var owned_after: Array = (coachs.get("owned", []) as Array).duplicate()
				owned_after.erase(active_coach_id)
				coachs["owned"] = owned_after
				coachs["active"] = ""
				coachs["last_hired_season"] = 0
				print("[COACHS][EXPIRE] coach=", active_coach_id, " current_season=", current_season, " hired=", hired_season, " duration=", duration)
			else:
				var coach_price: Dictionary = PL.get_coach_price_data(active_coach_id)
				var coach_season_cost: int = int(coach_price.get("euros_cost", 0))
				if coach_season_cost > 0:
					if not save.has("wallet") or typeof(save["wallet"]) != TYPE_DICTIONARY:
						save["wallet"] = {}
					var wallet: Dictionary = save["wallet"] as Dictionary
					wallet["euros"] = maxi(0, int(wallet.get("euros", 0)) - coach_season_cost)
					save["wallet"] = wallet
					save["total_depenses"] = int(save.get("total_depenses", 0)) + coach_season_cost
					save["coachs_fees_total"] = int(save.get("coachs_fees_total", 0)) + coach_season_cost
					save["popup_expenses_splus1_coach_fee_pending"] = int(coach_season_cost)
					print("[POPUP S+1][SET] coach_fee_pending=", int(save["popup_expenses_splus1_coach_fee_pending"]), " season=", int(save.get("season_number", 0)))
					if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
						save["finance"] = {}
					(save["finance"] as Dictionary)["euros"] = int(wallet.get("euros", 0))
					print("[COACHS][SEASON_COST] coach=", active_coach_id, " euros=-", coach_season_cost, " season=", current_season)
			save["coachs"] = coachs

	# --- Vieillissement joueurs + recalcul perf/salaire ---
	var selection_calc := Selection.new()
	if save.has("players_by_id") and typeof(save["players_by_id"]) == TYPE_DICTIONARY:
		var by_id: Dictionary = save["players_by_id"] as Dictionary
		for pid in by_id.keys():
			var pl = by_id[pid]
			if typeof(pl) != TYPE_DICTIONARY:
				continue
			var p: Dictionary = pl as Dictionary
			p["age"] = int(p.get("age", 25)) + 1
			if p.has("pondération"):
				p["pondération"] = selection_calc._bm_calc_ponderation(p)
			elif p.has("ponderation"):
				p["ponderation"] = selection_calc._bm_calc_ponderation(p)
			else:
				p["pondération"] = selection_calc._bm_calc_ponderation(p)
			# salaire annuel conservé : ne pas le réécrire ici
			by_id[pid] = p
		save["players_by_id"] = by_id
		# sync players array used by MyTeam
		if save.has("players") and typeof(save["players"]) == TYPE_ARRAY:
			var arr: Array = save["players"] as Array
			for i in range(arr.size()):
				var pl2 = arr[i]
				if typeof(pl2) != TYPE_DICTIONARY:
					continue
				var p2: Dictionary = pl2 as Dictionary
				var k := str(int(p2.get("id", -1)))
				if by_id.has(k) and typeof(by_id[k]) == TYPE_DICTIONARY:
					arr[i] = (by_id[k] as Dictionary).duplicate(true)
			save["players"] = arr

	save["popularite"] = popularity_keep

	(save["progress"] as Dictionary)["journee"] = 1
	(save["progress"] as Dictionary)["wins"] = 0
	(save["progress"] as Dictionary)["losses"] = 0

	PL.write_savegame(save)
	var legacy_save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if legacy_save_file != null:
		legacy_save_file.store_string(JSON.stringify(save, "\t"))
		legacy_save_file.close()

	SeasonState.matchs_joues = 0
	SeasonState.popup_bienvenue_saison_deja_vu = true
	SeasonState.standings = {}
	SeasonState.ranking_history.clear()
	SeasonState.season_results_by_round.clear()
	SeasonState.opponent_name = ""

	print("[SAISON] Nouvelle saison préparée : season_round=0, journee=1, standings vidés")

	_ensure_season_day_label()
	
func _get_end_season_summary() -> Dictionary:
	var save := PL.load_savegame()
	var my_name := str(save.get("team_name", "Mon équipe")).strip_edges()
	if my_name == "":
		my_name = "Mon équipe"

	var rank := 12
	if SeasonState.has_method("get_current_club_rank"):
		rank = int(SeasonState.get_current_club_rank(my_name))

	var wins := 0
	var losses := 0
	if SeasonState.standings.has(my_name) and typeof(SeasonState.standings[my_name]) == TYPE_DICTIONARY:
		var row: Dictionary = SeasonState.standings[my_name] as Dictionary
		wins = int(row.get("W", 0))
		losses = int(row.get("L", 0))

	var season_start_xp := int(save.get("season_start_xp", PL.get_club_xp(save)))
	var xp_now := int(PL.get_club_xp(save))

	var xp_gain: int = maxi(0, int(save.get("season_xp_earned", max(0, xp_now - season_start_xp))))
	var tokens_gain: int = maxi(0, int(save.get("season_tokens_earned", 0)))

	return {
		"team_name": my_name,
		"rank": rank,
		"wins": wins,
		"losses": losses,
		"xp_gain": xp_gain,
		"tokens_gain": tokens_gain
	}


func _get_current_season_day_text() -> String:
	var save := PL.load_savegame()

	var season_number := 1
	var journee := 1

	if typeof(save) == TYPE_DICTIONARY:
		season_number = int(save.get("season_number", 1))
		if save.has("progress") and typeof(save["progress"]) == TYPE_DICTIONARY:
			journee = int((save["progress"] as Dictionary).get("journee", 1))

	if season_number < 1:
		season_number = 1
	if journee < 1:
		journee = 1

	var txt := tr("season.label")
	if txt == "season.label" or txt.strip_edges() == "":
		txt = "Season {season} - Day {day}"

	txt = txt.replace("{season}", str(season_number))
	txt = txt.replace("{day}", "%02d" % journee)
	return txt.to_upper()

func _ensure_season_day_label() -> void:
	if btn_match == null:
		return

	if lbl_season_day == null or not is_instance_valid(lbl_season_day):
		lbl_season_day = Label.new()
		lbl_season_day.name = "LblSeasonDay"
		lbl_season_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_season_day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_season_day.add_theme_font_size_override("font_size", 20)
		call_deferred("_bm_saison_apply_mobile_day_and_popularity_texts")
		call_deferred("_bm_saison_align_mobile_play_and_day")
		lbl_season_day.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
		lbl_season_day.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		lbl_season_day.add_theme_constant_override("shadow_offset_x", 2)
		lbl_season_day.add_theme_constant_override("shadow_offset_y", 3)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.07, 0.16, 0.90)
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		sb.corner_radius_bottom_left = 18
		sb.corner_radius_bottom_right = 18
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.20, 0.55, 0.95, 0.85)
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		lbl_season_day.add_theme_stylebox_override("normal", sb)

		add_child(lbl_season_day)
		move_child(lbl_season_day, get_node("Overlays").get_index())

	lbl_season_day.text = _get_current_season_day_text()
	lbl_season_day.size = Vector2(320, 48)
	lbl_season_day.position = Vector2(
		btn_match.position.x + (btn_match.size.x - lbl_season_day.size.x) * 0.5,
		btn_match.position.y - 68
	)

func _close_end_season_popup() -> void:
	if popup_fin_saison != null and is_instance_valid(popup_fin_saison):
		var popup_parent := popup_fin_saison.get_parent()
		if popup_parent != null and popup_parent.name == "EndSeasonOverlay":
			popup_parent.queue_free()
		else:
			popup_fin_saison.queue_free()
	popup_fin_saison = null
	btn_popup_fin_saison = null


func _on_confirm_new_season_pressed() -> void:
	_close_end_season_popup()
	_show_pending_season_reward_popup_after_end_season()
	_prepare_new_season()


func _open_end_season_popup() -> void:
	_close_end_season_popup()

	var summary := _get_end_season_summary()
	var rank: int = int(summary.get("rank", 12))
	var wins: int = int(summary.get("wins", 0))
	var losses: int = int(summary.get("losses", 0))
	var xp_gain: int = int(summary.get("xp_gain", 0))
	var tokens_gain: int = int(summary.get("tokens_gain", 0))


	popup_fin_saison = Panel.new()
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.03, 0.03, 0.05, 0.96)
	popup_sb.corner_radius_top_left = 18
	popup_sb.corner_radius_top_right = 18
	popup_sb.corner_radius_bottom_left = 18
	popup_sb.corner_radius_bottom_right = 18
	popup_sb.border_width_left = 2
	popup_sb.border_width_top = 2
	popup_sb.border_width_right = 2
	popup_sb.border_width_bottom = 2
	popup_sb.border_color = Color(0.85, 0.75, 0.25, 0.35)
	popup_fin_saison.add_theme_stylebox_override("panel", popup_sb)
	popup_fin_saison.name = "PopupFinSaison"
	popup_fin_saison.set_anchors_preset(Control.PRESET_TOP_LEFT)
	popup_fin_saison.custom_minimum_size = Vector2(620, 520)
	popup_fin_saison.size = Vector2(620, 520)
	popup_fin_saison.position = (get_viewport_rect().size - popup_fin_saison.size) * 0.5
	popup_fin_saison.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 8
	vbox.offset_right = -24
	vbox.offset_bottom = -8
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 6)
	popup_fin_saison.add_child(vbox)

	var title := Label.new()
	title.text = tr("END_SEASON_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	# Confettis blancs style Tournois
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
	confetti.position = Vector2(popup_fin_saison.size.x * 0.5, 40)
	confetti.modulate = Color(1, 1, 1, 1)
	confetti.z_index = 60
	popup_fin_saison.add_child(confetti)

	if rank == 1 or rank == 2:
		var img := TextureRect.new()
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(200, 125)

		var texture_path := ""
		if rank == 1:
			texture_path = "res://assets/images/recompenses/coupe.png"
		elif rank == 2:
			texture_path = "res://assets/images/medaille_argent.png"

		if texture_path != "" and ResourceLoader.exists(texture_path):
			img.texture = load(texture_path)
			vbox.add_child(img)

	var rank_text := ""
	if rank == 1:
		rank_text = tr("END_SEASON_RANK_1")
	elif rank == 2:
		rank_text = tr("END_SEASON_RANK_2")
	else:
		rank_text = tr("END_SEASON_RANK") % rank

	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 56)
	body.text = rank_text + "\n\n" \
		+ tr("END_SEASON_SUMMARY") + " :\n" \
		+ str(wins) + " " + tr("END_SEASON_WINS").to_lower() + " - " + str(losses) + " " + tr("END_SEASON_LOSSES").to_lower()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("normal_font_size", 22)
	vbox.add_child(body)

	var summary_box := VBoxContainer.new()
	summary_box.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_box.add_theme_constant_override("separation", 2)
	vbox.add_child(summary_box)

	var lbl_xp_gain := Label.new()
	lbl_xp_gain.text = "XP : +" + str(xp_gain)
	lbl_xp_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_xp_gain.add_theme_font_size_override("font_size", 22)
	summary_box.add_child(lbl_xp_gain)

	var tokens_row := HBoxContainer.new()
	tokens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens_row.add_theme_constant_override("separation", 4)
	summary_box.add_child(tokens_row)

	var token_icon := TextureRect.new()
	token_icon.texture = TOKEN_ICON
	token_icon.custom_minimum_size = Vector2(24, 24)
	token_icon.size = Vector2(24, 24)
	token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tokens_row.add_child(token_icon)

	var lbl_tokens_gain := Label.new()
	lbl_tokens_gain.text = "+" + str(tokens_gain)
	lbl_tokens_gain.add_theme_font_size_override("font_size", 22)
	lbl_tokens_gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tokens_row.add_child(lbl_tokens_gain)

	btn_popup_fin_saison = Button.new()
	btn_popup_fin_saison.text = tr("END_SEASON_NEW_SEASON")
	btn_popup_fin_saison.custom_minimum_size = Vector2(320, 42)
	# BM_END_SEASON_START_BUTTON_ORANGE_V1
	var sb_end_season_btn := StyleBoxFlat.new()
	sb_end_season_btn.bg_color = Color(1.0, 0.48, 0.08, 1.0)
	sb_end_season_btn.corner_radius_top_left = 12
	sb_end_season_btn.corner_radius_top_right = 12
	sb_end_season_btn.corner_radius_bottom_left = 12
	sb_end_season_btn.corner_radius_bottom_right = 12
	sb_end_season_btn.shadow_color = Color(0, 0, 0, 0.35)
	sb_end_season_btn.shadow_size = 8
	sb_end_season_btn.shadow_offset = Vector2(0, 3)
	btn_popup_fin_saison.add_theme_stylebox_override("normal", sb_end_season_btn)
	btn_popup_fin_saison.add_theme_stylebox_override("hover", sb_end_season_btn)
	btn_popup_fin_saison.add_theme_stylebox_override("pressed", sb_end_season_btn)
	btn_popup_fin_saison.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn_popup_fin_saison.add_theme_font_size_override("font_size", 22)
	btn_popup_fin_saison.pressed.connect(_on_confirm_new_season_pressed)
	vbox.add_child(btn_popup_fin_saison)

	# BM_END_SEASON_POPUP_FRONT_V3_OVER_PLAY
	var end_overlay := Control.new()
	end_overlay.name = "EndSeasonOverlay"
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.z_index = 30000
	end_overlay.set_as_top_level(true)
	end_overlay.z_as_relative = false
	end_overlay.global_position = Vector2.ZERO
	end_overlay.size = get_viewport_rect().size
	get_node("Overlays").add_child(end_overlay)
	end_overlay.move_to_front()

	var end_dark := ColorRect.new()
	end_dark.name = "EndSeasonBackdrop"
	end_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_dark.color = Color(0, 0, 0, 0.38)
	end_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(end_dark)

	end_overlay.add_child(popup_fin_saison)
	popup_fin_saison.position = (get_viewport_rect().size - popup_fin_saison.size) * 0.5
	popup_fin_saison.z_index = 1
	popup_fin_saison.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_fin_saison.move_to_front()
	popup_fin_saison.call_deferred("move_to_front")

	var victory_path := "res://audio/sfx/victory_jingle.mp3"
	if ResourceLoader.exists(victory_path):
		var player := AudioStreamPlayer.new()
		player.name = "EndSeasonVictoryJingle"
		player.stream = load(victory_path)
		popup_fin_saison.add_child(player)
		player.play()

	print("[SAISON] popup fin de saison ouvert rank=", rank, " wins=", wins, " losses=", losses)
	
# --- Bouton Match ---
func _on_match_pressed() -> void:
	if popup_bienvenue != null and popup_bienvenue.visible:
		return
	if popup_fin_saison != null and is_instance_valid(popup_fin_saison):
		return

	var save_guard := PL.load_savegame()
	var round_guard := int(SeasonState.matchs_joues)

	if typeof(save_guard) == TYPE_DICTIONARY:
		round_guard = int(save_guard.get("season_round", round_guard))
		if save_guard.has("progress") and typeof(save_guard["progress"]) == TYPE_DICTIONARY:
			var p: Dictionary = save_guard["progress"] as Dictionary
			round_guard = maxi(round_guard, int(p.get("journee", round_guard + 1)) - 1)

	SeasonState.matchs_joues = round_guard

	# Garde fin de saison (source of truth = save)
	if round_guard >= SeasonState.total_matchs_saison:
		print("[SAISON] Fin de saison détectée -> affichage popup fin de saison (round_guard=", round_guard, ")")
		_open_end_season_popup()
		return

	if _bm_should_open_match_compo_popup_on_play():
		_bm_show_match_compo_popup_on_play()
		return
	if popup_bienvenue != null and popup_bienvenue.visible:
		return
	if popup_fin_saison != null and is_instance_valid(popup_fin_saison):
		return

	# Garde fin de saison
	if SeasonState.matchs_joues >= SeasonState.total_matchs_saison:
		print("[SAISON] Fin de saison détectée -> affichage popup fin de saison")
		_open_end_season_popup()
		return

	# Lance la simulation
	print("[SAISON] click Match -> go MatchSim")

	# --- Set opponent name for MatchSim (affichage) ---
	var save := PL.load_savegame()
	var my_name := "Mon équipe"
	if typeof(save) == TYPE_DICTIONARY:
		var n := str(save.get("team_name", "")).strip_edges()
		if n != "":
			my_name = n
		var ss := get_node_or_null("/root/SeasonState")
		if ss != null:
			var round_index: int = int(save.get("season_round", 0))
			var fx: Dictionary = ss.get_user_fixture_for_round(my_name, round_index)
			ss.opponent_name = str(fx.get("opponent", ""))
			SeasonState.opponent_name = ss.opponent_name # miroir (safe)
		else:
			SeasonState.opponent_name = SeasonState.compute_next_opponent_name(my_name)
	print("[SAISON] opponent_name =", SeasonState.opponent_name)
	get_tree().change_scene_to_file("res://scenes/MatchSim.tscn")

# --- Fermeture popup bienvenue ---
func _on_close_bienvenue_pressed() -> void:
	SeasonState.popup_bienvenue_saison_deja_vu = true
	_bm_mark_intro_popup_seen()
	var tree := get_tree()
	if tree == null:
		print("[SAISON][ERR] get_tree() null -> impossible d'ouvrir Stadium")
		return
	print("[SAISON] popup bienvenue -> Go to Stadium")
	tree.change_scene_to_file("res://scenes/StadiumMinimal.tscn")


func _open_calendrier_modal() -> void:
	if calendrier_modal != null:
		return

	var modal_scene: PackedScene = load("res://scenes/CalendrierModal.tscn")
	if modal_scene == null:
		push_error("[SAISON] CalendrierModal.tscn introuvable (load=null)")
		return
	calendrier_modal = modal_scene.instantiate() as Control
	if calendrier_modal == null:
		push_error("[SAISON] CalendrierModal instantiate() a renvoyé null")
		return
	calendrier_modal.set_as_top_level(true)
	calendrier_modal.z_index = 700
	get_node("Overlays").add_child(calendrier_modal)
	calendrier_modal.move_to_front()

	# Connect fermeture
	if calendrier_modal.has_signal("closed"):
		calendrier_modal.closed.connect(_on_calendrier_closed)

	print("[SAISON] calendrier modal ouvert")


func _on_calendrier_closed() -> void:
	calendrier_modal = null

	# Comme Python: fermeture du calendrier => on revient à une zone neutre
	SeasonState.zone_selectionnee_saison = ""
	print("[SAISON] calendrier modal fermé -> zone_selectionnee_saison cleared")

func _render_standings_bbcode() -> String:
	var ss := get_node_or_null("/root/SeasonState") as SeasonState
	if ss == null:
		return "[b]Classement indisponible[/b]"

	var st: Dictionary = ss.standings
	if st.size() == 0:
		return "[b]Classement vide[/b]"

	var teams: Array = st.keys()
	teams.sort_custom(func(a, b):
		var da: Dictionary = st[a]
		var db: Dictionary = st[b]
		var pa: int = int(da.get("PTS", 0))
		var pb: int = int(db.get("PTS", 0))
		if pa != pb:
			return pa > pb
		var diffa: int = int(da.get("DIFF", 0))
		var diffb: int = int(db.get("DIFF", 0))
		if diffa != diffb:
			return diffa > diffb
		var pfa: int = int(da.get("PF", 0))
		var pfb: int = int(db.get("PF", 0))
		return pfa > pfb
	)

	var out := ""
	out += "\n"
	out += "Pos   " + _bm_tr_or_fallback("standings.team_header", "Équipe") + "                        Pts   W   L     PF    PA    Diff\n"
	out += "--------------------------------------------------------------\n"

	var pos: int = 1
	for t in teams:
		var d: Dictionary = st[t]
		var pts: int = int(d.get("PTS", 0))
		var w: int = int(d.get("W", 0))
		var l: int = int(d.get("L", 0))
		var pf: int = int(d.get("PF", 0))
		var pa: int = int(d.get("PA", 0))
		var diff: int = int(d.get("DIFF", pf - pa))
		var raw_name: String = str(t).strip_edges()
		var name: String = raw_name
		if name.length() > 20:
			name = name.substr(0, 20)
		var row := "%2d    %-20s    %3d   %2d  %2d    %4d  %4d    %+4d
" % [pos, name, pts, w, l, pf, pa, diff]
		var my_team_name := ""
		for n in get_tree().root.get_children():
			if my_team_name == "" and n.has_method("get_current_profile"):
				var profile = n.call("get_current_profile")
				if profile is Dictionary:
					my_team_name = str(profile.get("team_name", profile.get("club_name", ""))).strip_edges()
			if my_team_name == "" and n.has_method("get_save"):
				var save_data = n.call("get_save")
				if save_data is Dictionary:
					my_team_name = str(save_data.get("team_name", save_data.get("club_name", ""))).strip_edges()
			if my_team_name == "" and n.has_method("get_club_name"):
				my_team_name = str(n.call("get_club_name")).strip_edges()
		var team_cmp := my_team_name.to_lower()
		var raw_cmp := raw_name.to_lower()
		var short_cmp := name.to_lower()
		print("[CLASSEMENT] raw_name=", raw_name, " | name=", name, " | my_team_name=", my_team_name)
		if team_cmp != "" and (raw_cmp == team_cmp or short_cmp == team_cmp):
			row = "[color=#40C7FF]" + row + "[/color]"
		out += row
		pos += 1

	return out


func _on_btn_classement_show_standings_pressed() -> void:
	if standings_panel == null or lbl_standings == null:
		return
	# BM_STANDINGS_CONTENT_TEXT_PLUS2_DIRECT_V1
	lbl_standings.add_theme_font_size_override("normal_font_size", 28)
	lbl_standings.text = _render_standings_bbcode()
	standings_panel.z_index = 700
	standings_panel.visible = true
	standings_panel.move_to_front()
	_refresh_standings_graph()
	if standings_graph_panel != null:
		standings_graph_panel.z_index = 701
		standings_graph_panel.move_to_front()
	if btn_close_classement != null:
		btn_close_classement.z_index = 702
		_position_close_classement_on_standings_panel()
		btn_close_classement.move_to_front()


func _start_btn_match_pulse() -> void:
	if btn_match == null:
		return

	# Stop tween si déjà en cours
	if _tw_match_pulse != null and is_instance_valid(_tw_match_pulse):
		_tw_match_pulse.kill()
		_tw_match_pulse = null

	# Référence position (si le bouton n'est pas dans un Container, on "bob" en Y)
	_btn_match_base_pos = btn_match.position

	# Pulse scale (toujours safe)
	btn_match.pivot_offset = btn_match.size * 0.5
	if not _bm_saison_is_mobile_layout():
		btn_match.scale = Vector2.ONE

	_tw_match_pulse = create_tween()
	_tw_match_pulse.set_loops() # permanent
	_tw_match_pulse.set_trans(Tween.TRANS_SINE)
	_tw_match_pulse.set_ease(Tween.EASE_IN_OUT)

	# 1) pulse scale
	_tw_match_pulse.tween_property(btn_match, "scale", Vector2(1.06, 1.06), 0.55)
	_tw_match_pulse.tween_property(btn_match, "scale", Vector2(1.00, 1.00), 0.55)

	# 2) bob Y (si position existe / pas gérée par container)
	_tw_match_pulse.parallel().tween_property(btn_match, "position:y", _btn_match_base_pos.y - 6.0, 0.55)
	_tw_match_pulse.parallel().tween_property(btn_match, "position:y", _btn_match_base_pos.y, 0.55)


func _on_btn_close_classement_pressed() -> void:
	# Ferme le tableau Classement -> retour menu Saison
	SeasonState.zone_selectionnee_saison = ""
	if standings_panel != null:
		standings_panel.visible = false
	if standings_graph_panel != null:
		standings_graph_panel.visible = false
	_force_hide_classement_ui()
	print("[SAISON] close classement -> zone_selectionnee_saison cleared")


func _update_close_classement_visibility() -> void:
	if btn_close_classement == null:
		return
	var is_cl := (SeasonState.zone_selectionnee_saison == "classement")
	btn_close_classement.visible = is_cl
	if is_cl:
		_force_show_classement_ui()
		_position_close_classement_on_standings_panel()

func _position_close_classement_on_standings_panel() -> void:
	if btn_close_classement == null or standings_panel == null:
		return
	var panel_rect := standings_panel.get_global_rect()
	var btn_size := btn_close_classement.size
	if btn_size.x <= 0.0 or btn_size.y <= 0.0:
		btn_size = Vector2(50.0, 50.0)
	btn_close_classement.global_position = Vector2(
		panel_rect.position.x + panel_rect.size.x - btn_size.x - 12.0,
		panel_rect.position.y + 12.0
	)
func _process(_delta: float) -> void:
	_update_close_classement_visibility()


func _on_close_x_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_btn_close_classement_pressed()


func _force_hide_classement_ui() -> void:
	# Cache tout ce qui ressemble à l'UI "classement" si jamais un panneau reste visible
	var root: Node = self
	_force_hide_classement_ui_rec(root)

func _force_hide_classement_ui_rec(n: Node) -> void:
	if n == null:
		return

	# ⚠️ IMPORTANT: ne jamais cacher les boutons du menu (Tabs / Btn*)
	var node_name := String(n.name)
	if node_name.begins_with("Btn"):
		# ex: BtnClassement, BtnStatistiques, etc. -> toujours visibles
		return

	# Ne jamais toucher aux contrôles dans UI/Tabs (barre du haut)
	if n is Node:
		var path_str := String(n.get_path())
		if path_str.find("/UI/Tabs/") != -1:
			return

	# Cacher uniquement la zone centrale (panneau/label/overlay), pas les boutons
	if n is Control:
		var nm := node_name.to_lower()
		# On cible les conteneurs/labels typiques du tableau, pas les boutons
		if (nm.find("classement") != -1 or nm.find("standings") != -1) and not (n is Button):
			(n as Control).visible = false

	for c in n.get_children():
		_force_hide_classement_ui_rec(c)


func _force_show_classement_ui() -> void:
	# Ré-affiche l'UI centrale du classement si elle a été masquée
	var root: Node = self
	_force_show_classement_ui_rec(root)

func _force_show_classement_ui_rec(n: Node) -> void:
	if n == null:
		return

	# Ne jamais toucher aux boutons du menu
	var node_name := String(n.name)
	if node_name.begins_with("Btn"):
		return

	# Ne jamais toucher à la barre du haut UI/Tabs
	var path_str := String(n.get_path())
	if path_str.find("/UI/Tabs/") != -1:
		return

	# Ré-afficher uniquement ce qui ressemble à l'UI "classement" (hors boutons)
	if n is Control:
		var nm := node_name.to_lower()
		if (nm.find("classement") != -1 or nm.find("standings") != -1) and not (n is Button):
			(n as Control).visible = true

	for c in n.get_children():
		_force_show_classement_ui_rec(c)

func _btn_match_stop_tween() -> void:
	if _btn_match_tween != null and is_instance_valid(_btn_match_tween):
		_btn_match_tween.kill()
	_btn_match_tween = null

func _bm_add_play_match_halo() -> void:
	if _bm_saison_is_mobile_layout():
		return
	if btn_match == null:
		return
	if _btn_match_halo != null and is_instance_valid(_btn_match_halo):
		return

	_btn_match_halo = Panel.new()
	_btn_match_halo.name = "BtnMatchWhiteHalo"
	_btn_match_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_match_halo.z_index = -1
	_btn_match_halo.z_as_relative = true

	var halo_style := StyleBoxFlat.new()
	halo_style.bg_color = Color(1, 1, 1, 0.00)
	halo_style.border_width_left = 5
	halo_style.border_width_top = 5
	halo_style.border_width_right = 5
	halo_style.border_width_bottom = 5
	halo_style.border_color = Color(1, 1, 1, 0.82)
	halo_style.corner_radius_top_left = 18
	halo_style.corner_radius_top_right = 18
	halo_style.corner_radius_bottom_left = 18
	halo_style.corner_radius_bottom_right = 18
	halo_style.shadow_color = Color(1, 1, 1, 0.86)
	halo_style.shadow_size = 42
	halo_style.shadow_offset = Vector2(0, 0)
	_btn_match_halo.add_theme_stylebox_override("panel", halo_style)

	var ui := get_node_or_null("UI") as Control
	if ui != null:
		ui.add_child(_btn_match_halo)
		ui.move_child(_btn_match_halo, max(0, btn_match.get_index()))
	else:
		add_child(_btn_match_halo)
	if btn_match != null:
		btn_match.z_index = max(btn_match.z_index, 1)

	_update_play_match_halo_position()

	_btn_match_halo_tween = create_tween()
	_btn_match_halo_tween.set_loops()
	_btn_match_halo_tween.tween_property(_btn_match_halo, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_match_halo_tween.parallel().tween_property(_btn_match_halo, "scale", Vector2(1.10, 1.16), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_match_halo_tween.tween_property(_btn_match_halo, "modulate:a", 0.55, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_match_halo_tween.parallel().tween_property(_btn_match_halo, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_play_match_halo_position() -> void:
	if _btn_match_halo == null or btn_match == null:
		return
	if not is_instance_valid(_btn_match_halo):
		return
	var rect := btn_match.get_global_rect()
	_btn_match_halo.set_as_top_level(true)
	_btn_match_halo.global_position = rect.position - Vector2(22, 22)
	_btn_match_halo.size = rect.size + Vector2(44, 44)
	_btn_match_halo.pivot_offset = _btn_match_halo.size * 0.5


func _on_btn_match_mouse_entered() -> void:
	if btn_match == null:
		return
	_btn_match_stop_tween()
	# Micro pulse + micro nudge (léger, OK HTML5)
	_btn_match_tween = create_tween()
	_btn_match_tween.set_parallel(true)
	_btn_match_tween.tween_property(btn_match, "scale", _btn_match_base_scale * 1.035, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_btn_match_tween.tween_property(btn_match, "position", _btn_match_base_pos + Vector2(0, 2), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_btn_match_tween.set_parallel(false)
	_btn_match_tween.tween_property(btn_match, "scale", _btn_match_base_scale * 1.02, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_match_tween.tween_property(btn_match, "position", _btn_match_base_pos, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_btn_match_mouse_exited() -> void:
	if btn_match == null:
		return
	_btn_match_stop_tween()
	_btn_match_tween = create_tween()
	_btn_match_tween.set_parallel(true)
	_btn_match_tween.tween_property(btn_match, "scale", _btn_match_base_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_btn_match_tween.tween_property(btn_match, "position", _btn_match_base_pos, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_btn_retour_pressed() -> void:
	# Retour vers écran Management (fallbacks)
	var candidates := [
		"res://scenes/Management.tscn",
		"res://scenes/Gestion.tscn",
		"res://scenes/MenuGestion.tscn",
		"res://scenes/Menu.tscn",
		"res://scenes/Main.tscn",
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			get_tree().change_scene_to_file(p)
			return
	push_warning("[MenuSaison] Aucun écran Management trouvé (candidates).")

func _ensure_saison_buttons_active() -> void:
	# Force l'interactivité (utile après retour depuis Management)
	var paths := [
		"UI/BtnMatch",
		"UI/Tabs/BtnClassement",
		"UI/Tabs/BtnStatistiques",
		"UI/Tabs/BtnCalendrier",
		"UI/Tabs/BtnMissions",
		"UI/Tabs/BtnTournois",
		"UI/BtnRetour",
	]
	for npath in paths:
		var n := get_node_or_null(npath)
		if n != null and n is Button:
			var b := n as Button
			b.disabled = false
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			# Focus OK clavier/web
			b.focus_mode = Control.FOCUS_ALL

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_i18n_tabs()
		return
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_bm_saison_apply_mobile_bg_and_halo_layout")
		call_deferred("_bm_saison_apply_mobile_hud_layout")
		call_deferred("_bm_saison_apply_mobile_top_left_buttons_plus20_text_plus2")
		call_deferred("_bm_saison_apply_mobile_play_button_plus20_text_plus2")
		call_deferred("_bm_saison_apply_mobile_day_and_popularity_texts")
		call_deferred("_bm_saison_align_mobile_play_and_day")
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_VISIBILITY_CHANGED:
		_ensure_saison_buttons_active()

func _apply_i18n() -> void:
	if btn_classement != null:
		btn_classement.text = tr("saison.tab.standings")
	if btn_statistiques != null:
		btn_statistiques.text = tr("saison.tab.stats")
	if btn_calendrier != null:
		btn_calendrier.text = tr("saison.tab.calendar")


func _missions_apply_button_styles() -> void:
	if btn_close_missions != null:
		btn_close_missions.set_meta("i18n_key", "BTN_BACK")
		btn_close_missions.text = "BTN_BACK"
		I18nSvc.apply_node(btn_close_missions)
		var sbn := StyleBoxFlat.new()
		sbn.bg_color = Color(0.74, 0.10, 0.16, 1.0)
		sbn.corner_radius_top_left = 12
		sbn.corner_radius_top_right = 12
		sbn.corner_radius_bottom_left = 12
		sbn.corner_radius_bottom_right = 12
		sbn.border_width_left = 2
		sbn.border_width_top = 2
		sbn.border_width_right = 2
		sbn.border_width_bottom = 2
		sbn.border_color = Color(0.20, 0.75, 1.00, 0.95)
		var sbh := sbn.duplicate()
		sbh.bg_color = Color(0.82, 0.14, 0.20, 1.0)
		var sbp := sbn.duplicate()
		sbp.bg_color = Color(0.58, 0.08, 0.12, 1.0)
		btn_close_missions.add_theme_stylebox_override("normal", sbn)
		btn_close_missions.add_theme_stylebox_override("hover", sbh)
		btn_close_missions.add_theme_stylebox_override("pressed", sbp)
		btn_close_missions.add_theme_font_size_override("font_size", 22)
	if btn_claim_mission != null:
		var cbn := StyleBoxFlat.new()
		cbn.bg_color = Color(0.95, 0.62, 0.12, 1.0)
		cbn.corner_radius_top_left = 12
		cbn.corner_radius_top_right = 12
		cbn.corner_radius_bottom_left = 12
		cbn.corner_radius_bottom_right = 12
		cbn.border_width_left = 2
		cbn.border_width_top = 2
		cbn.border_width_right = 2
		cbn.border_width_bottom = 2
		cbn.border_color = Color(1, 1, 1, 0.35)
		var cbh := cbn.duplicate()
		cbh.bg_color = Color(1.0, 0.70, 0.20, 1.0)
		var cbp := cbn.duplicate()
		cbp.bg_color = Color(0.82, 0.52, 0.08, 1.0)
		btn_claim_mission.add_theme_stylebox_override("normal", cbn)
		btn_claim_mission.add_theme_stylebox_override("hover", cbh)
		btn_claim_mission.add_theme_stylebox_override("pressed", cbp)
		btn_claim_mission.add_theme_font_size_override("font_size", 22)


func _missions_tr(key: String, fallback: String = "") -> String:
	var v := tr(key)
	if v != key and v.strip_edges() != "":
		return v
	match key:
		"missions.ui.level":
			return "Lv"
		"missions.ui.active":
			return "Mission active"
		"missions.ui.progress":
			return "Progression"
		"missions.ui.reward":
			return "Gain"
		"missions.ui.claim":
			return "Réclamer"
		"missions.ui.in_progress":
			return "Mission en cours"
		"missions.ui.done":
			return "Terminé"
		"popup.tokens.first_reward.line2":
			return "You just earned {amount} tokens."
		"popup.tokens.first_reward.line3":
			return "Tokens unlock premium upgrades and special content."
		"popup.tokens.first_reward.fallback_mission":
			return "Mission completed."
		"missions.ui.all_done":
			return "Toutes les missions du niveau sont terminées."
		"missions.lv1.win_1":
			return "Gagner 3 matchs"
		"missions.lv1.pts_75_1":
			return "Marquer 75 points 2 fois"
		"missions.lv1.price_1":
			return "Ajuster un prix"
		"missions.lv1.stadium_1":
			return "Débloquer un niveau de stade"
		"missions.lv2.win_3":
			return "Gagner 3 matchs"
		"missions.lv2.pts_75_2":
			return "Marquer 75 points 2 fois"
		"missions.lv2.price_2":
			return "Ajuster des prix 2 fois"
		"missions.lv2.streak_2":
			return "Gagner 2 matchs d'affilée"
	if fallback.strip_edges() != "":
		return fallback
	return key

func _missions_label_text(mission: Dictionary) -> String:
	var key := str(mission.get("label_key", "")).strip_edges()
	if key != "":
		return _missions_tr(key, key)
	return str(mission.get("label", ""))

func _missions_get_save() -> Dictionary:
	return PL.load_savegame()

func _missions_get_level() -> int:
	var save: Dictionary = _missions_get_save()
	if save.has("club") and typeof(save["club"]) == TYPE_DICTIONARY:
		return maxi(1, int((save["club"] as Dictionary).get("level", 1)))
	return 1

# BM_MISSIONS_PRICE_ADJUST_OFF_V1
# Mission "Adjust prices" temporairement désactivée sans supprimer sa définition.
# Elle est sortie de l'affichage, des tokens, des compteurs Missions et de l'auto-claim.
func _missions_filter_off(level_missions: Array) -> Array:
	var filtered: Array = []
	for mission_any in level_missions:
		if typeof(mission_any) != TYPE_DICTIONARY:
			continue
		var mission: Dictionary = mission_any as Dictionary
		if str(mission.get("check_counter", "")).strip_edges() == "price_adjust_done":
			continue
		filtered.append(mission)
	return filtered


func _missions_get_level_data(level: int) -> Array:
	if TuningData.MISSIONS_BY_LEVEL.has(level):
		return _missions_filter_off(TuningData.MISSIONS_BY_LEVEL[level])
	if TuningData.MISSIONS_BY_LEVEL.has(1):
		return _missions_filter_off(TuningData.MISSIONS_BY_LEVEL[1])
	return []

func _missions_get_completed(save: Dictionary) -> Array:
	if not save.has("missions_progress") or typeof(save["missions_progress"]) != TYPE_DICTIONARY:
		return []
	var mp: Dictionary = save["missions_progress"] as Dictionary
	if not mp.has("completed") or typeof(mp["completed"]) != TYPE_ARRAY:
		return []
	return mp["completed"] as Array

func _missions_get_counters(save: Dictionary) -> Dictionary:
	if not save.has("missions_state") or typeof(save["missions_state"]) != TYPE_DICTIONARY:
		return {}
	var ms: Dictionary = save["missions_state"] as Dictionary
	if not ms.has("counters") or typeof(ms["counters"]) != TYPE_DICTIONARY:
		return {}
	var counters: Dictionary = ms["counters"] as Dictionary
	if int(counters.get("price_adjust_done", 0)) < 1:
		var has_price_adjust := false
		if save.has("ticketing") and typeof(save["ticketing"]) == TYPE_DICTIONARY:
			var ticketing_root: Dictionary = save["ticketing"] as Dictionary
			has_price_adjust = int(ticketing_root.get("price_a", 0)) > 0 or int(ticketing_root.get("price_b", 0)) > 0 or int(ticketing_root.get("price_c", 0)) > 0
		if not has_price_adjust and save.has("stadium") and typeof(save["stadium"]) == TYPE_DICTIONARY:
			var stadium_data: Dictionary = save["stadium"] as Dictionary
			if stadium_data.has("ticketing") and typeof(stadium_data["ticketing"]) == TYPE_DICTIONARY:
				var ticketing_stadium: Dictionary = stadium_data["ticketing"] as Dictionary
				has_price_adjust = int(ticketing_stadium.get("price_a", 0)) > 0 or int(ticketing_stadium.get("price_b", 0)) > 0 or int(ticketing_stadium.get("price_c", 0)) > 0
		if not has_price_adjust and save.has("shop") and typeof(save["shop"]) == TYPE_DICTIONARY:
			var shop_data: Dictionary = save["shop"] as Dictionary
			var items_any: Variant = shop_data.get("items", {})
			if typeof(items_any) == TYPE_DICTIONARY:
				var items: Dictionary = items_any as Dictionary
				for pid in items.keys():
					var row_any: Variant = items[pid]
					if typeof(row_any) == TYPE_DICTIONARY and int((row_any as Dictionary).get("price", 0)) > 0:
						has_price_adjust = true
						break
		if has_price_adjust:
			counters["price_adjust_done"] = 1
	return counters

func _missions_current_index(level_missions: Array, completed: Array) -> int:
	for i in range(level_missions.size()):
		var mid := str((level_missions[i] as Dictionary).get("id", ""))
		if not completed.has(mid):
			return i
	return level_missions.size()

func _missions_is_done(mission: Dictionary, counters: Dictionary) -> bool:
	var key := str(mission.get("check_counter", ""))
	var target := int(mission.get("target", 0))
	return int(counters.get(key, 0)) >= target

func _missions_clear_canvas() -> void:
	if metro_canvas == null:
		return
	for c in metro_canvas.get_children():
		c.queue_free()

func _missions_tokens_total_for_level(level_missions: Array) -> int:
	var total := 0
	for mission_any in level_missions:
		if typeof(mission_any) != TYPE_DICTIONARY:
			continue
		var mission: Dictionary = mission_any as Dictionary
		total += int(mission.get("reward_tokens", 0))
	return total


func _missions_tokens_earned_for_level(level_missions: Array, save: Dictionary) -> int:
	if typeof(save) != TYPE_DICTIONARY:
		return 0
	if not save.has("missions_progress") or typeof(save["missions_progress"]) != TYPE_DICTIONARY:
		return 0
	var mp: Dictionary = save["missions_progress"] as Dictionary
	if not mp.has("rewards_awarded") or typeof(mp["rewards_awarded"]) != TYPE_ARRAY:
		return 0
	var rewards_awarded: Array = mp["rewards_awarded"] as Array
	var earned := 0
	for mission_any in level_missions:
		if typeof(mission_any) != TYPE_DICTIONARY:
			continue
		var mission: Dictionary = mission_any as Dictionary
		var mid := str(mission.get("id", "")).strip_edges()
		if mid != "" and rewards_awarded.has(mid):
			earned += int(mission.get("reward_tokens", 0))
	return earned


func _missions_update_tokens_counter(level_missions: Array, save: Dictionary) -> void:
	if missions_card == null:
		return
	var counter := missions_card.get_node_or_null("MissionsTokensCounter") as HBoxContainer
	if counter == null:
		counter = HBoxContainer.new()
		counter.name = "MissionsTokensCounter"
		counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.alignment = BoxContainer.ALIGNMENT_END
		counter.add_theme_constant_override("separation", 8)
		counter.anchor_left = 1.0
		counter.anchor_right = 1.0
		counter.anchor_top = 0.0
		counter.anchor_bottom = 0.0
		counter.offset_left = -230
		counter.offset_right = -34
		counter.offset_top = 28
		counter.offset_bottom = 70
		missions_card.add_child(counter)

		var lbl := Label.new()
		lbl.name = "LblMissionsTokensCounter"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.18, 0.30, 0.95))
		lbl.add_theme_constant_override("outline_size", 5)
		counter.add_child(lbl)

		var icon := TextureRect.new()
		icon.name = "ImgMissionsTokensCounter"
		icon.texture = TOKEN_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(41.4, 41.4)
		icon.size = Vector2(41.4, 41.4)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.add_child(icon)

	var lbl_counter := counter.get_node_or_null("LblMissionsTokensCounter") as Label
	if lbl_counter != null:
		lbl_counter.add_theme_font_size_override("font_size", 30)
		lbl_counter.text = str(_missions_tokens_earned_for_level(level_missions, save)) + "/" + str(_missions_tokens_total_for_level(level_missions))
	var token_icon := counter.get_node_or_null("ImgMissionsTokensCounter") as TextureRect
	if token_icon != null:
		token_icon.custom_minimum_size = Vector2(41.4, 41.4)
		token_icon.size = Vector2(41.4, 41.4)


func _missions_make_station(parent: Control, pos: Vector2, mission: Dictionary, state: String, idx: int) -> void:
	var halo := ColorRect.new()
	halo.position = pos - Vector2(22, 22)
	halo.size = Vector2(44, 44)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match state:
		"done":
			halo.color = Color(0.16, 0.78, 0.35, 0.22)
		"active":
			halo.color = Color(0.95, 0.62, 0.12, 0.28)
		_:
			halo.color = Color(0.55, 0.58, 0.62, 0.14)
	parent.add_child(halo)

	var tex := load("res://assets/images/ballon.png")
	if tex != null:
		var ball := TextureRect.new()
		ball.texture = tex
		ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ball.position = pos - Vector2(28.57, 28.57)
		ball.size = Vector2(57.13, 57.13)
		ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match state:
			"done":
				ball.modulate = Color(0.92, 1.00, 0.92, 1.0)
			"active":
				ball.modulate = Color(1.0, 0.96, 0.88, 1.0)
			_:
				ball.modulate = Color(0.72, 0.72, 0.72, 0.95)
		parent.add_child(ball)
	else:
		var dot := ColorRect.new()
		dot.position = pos - Vector2(12, 12)
		dot.size = Vector2(24, 24)
		match state:
			"done":
				dot.color = Color(0.16, 0.78, 0.35, 1.0)
			"active":
				dot.color = Color(0.95, 0.62, 0.12, 1.0)
			_:
				dot.color = Color(0.48, 0.50, 0.55, 1.0)
		parent.add_child(dot)

	var label := Label.new()
	label.position = pos + Vector2(-10, -66)
	label.size = Vector2(250, 76)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _missions_label_text(mission)
	label.add_theme_font_size_override("font_size", 24)
	match state:
		"done":
			label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92, 1))
			label.add_theme_color_override("font_outline_color", Color(0.16, 0.78, 0.35, 0.98))
		"locked":
			label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.84, 1))
			label.add_theme_color_override("font_outline_color", Color(1.00, 0.82, 0.18, 0.98))
		_:
			label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1))
			label.add_theme_color_override("font_outline_color", Color(0.10, 0.18, 0.30, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0.00, 0.00, 0.00, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

	var reward_lbl := Label.new()
	reward_lbl.text = "+" + str(int(mission.get("reward_tokens", 0)))
	reward_lbl.position = pos + Vector2(-58, 30)
	reward_lbl.size = Vector2(40, 24)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 28)
	reward_lbl.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1))
	reward_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.18, 0.30, 0.95))
	reward_lbl.add_theme_constant_override("outline_size", 5)
	reward_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(reward_lbl)

	var token_tex := load("res://assets/images/token.png")
	if token_tex != null:
		var token_icon := TextureRect.new()
		token_icon.texture = token_tex
		token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		token_icon.size = Vector2(40, 40)
		token_icon.position = pos + Vector2(-15, 28)
		token_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(token_icon)

func _missions_build_points(count: int) -> Array:
	var pts: Array = []
	var y := 70.0
	for i in range(count):
		var x := 140.0
		if i % 6 == 1:
			x = 330.0
		elif i % 6 == 2:
			x = 610.0
		elif i % 6 == 3:
			x = 800.0
		elif i % 6 == 4:
			x = 560.0
		elif i % 6 == 5:
			x = 250.0
		pts.append(Vector2(x, y))
		y += 74.0
	return pts

func _missions_build_curve_points(stations: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if stations.is_empty():
		return out
	out.append(stations[0] as Vector2)
	for i in range(stations.size() - 1):
		var a: Vector2 = stations[i] as Vector2
		var b: Vector2 = stations[i + 1] as Vector2
		var bend: float = 90.0 if b.x > a.x else -90.0
		var mid_y: float = lerp(a.y, b.y, 0.5)
		var c1: Vector2 = Vector2(a.x + bend, mid_y - 20.0)
		var c2: Vector2 = Vector2(b.x - bend, mid_y + 20.0)
		out.append(c1)
		out.append(c2)
		out.append(b)
	return out


func _missions_auto_claim_reached(save: Dictionary, level_missions: Array, counters: Dictionary) -> int:
	if typeof(save) != TYPE_DICTIONARY:
		return 0
	if not save.has("missions_progress") or typeof(save["missions_progress"]) != TYPE_DICTIONARY:
		save["missions_progress"] = {"completed": [], "in_progress": [], "selected": []}

	var mp: Dictionary = save["missions_progress"] as Dictionary
	if not mp.has("completed") or typeof(mp["completed"]) != TYPE_ARRAY:
		mp["completed"] = []

	var completed: Array = mp["completed"] as Array
	if not mp.has("rewards_awarded") or typeof(mp["rewards_awarded"]) != TYPE_ARRAY:
		mp["rewards_awarded"] = []
	var rewards_awarded: Array = mp["rewards_awarded"] as Array

	var tokens_gain := 0
	var pending_labels: Array = []
	var changed := false

	for mission_any in level_missions:
		if typeof(mission_any) != TYPE_DICTIONARY:
			continue
		var mission: Dictionary = mission_any as Dictionary
		var mid := str(mission.get("id", "")).strip_edges()
		if mid == "":
			continue

		if completed.has(mid):
			if not rewards_awarded.has(mid):
				tokens_gain += int(mission.get("reward_tokens", 0))
				pending_labels.append(_missions_label_text(mission))
				rewards_awarded.append(mid)
				changed = true
			continue

		if not _missions_is_done(mission, counters):
			continue

		completed.append(mid)
		if not rewards_awarded.has(mid):
			tokens_gain += int(mission.get("reward_tokens", 0))
			pending_labels.append(_missions_label_text(mission))
			rewards_awarded.append(mid)
		changed = true

	if changed:
		mp["completed"] = completed
		mp["rewards_awarded"] = rewards_awarded
		save["missions_progress"] = mp
		if tokens_gain > 0:
			save = PL.add_tokens(save, tokens_gain, "missions_auto_claim")
			_mission_tokens_popup_pending += tokens_gain
			for label_pending in pending_labels:
				_mission_tokens_popup_pending_labels.append(label_pending)
		PL.write_savegame(save)

	return tokens_gain


func _refresh_missions_panel() -> void:
	if missions_panel == null or metro_canvas == null:
		return
	var save: Dictionary = _missions_get_save()
	var level := _missions_get_level()
	var level_missions: Array = _missions_get_level_data(level)
	var completed: Array = _missions_get_completed(save)
	var counters: Dictionary = _missions_get_counters(save)

	# BM_MISSIONS_AUTO_CLAIM_V1
	# Missions validées automatiquement dès que le compteur atteint l'objectif.
	var auto_tokens_gain := _missions_auto_claim_reached(save, level_missions, counters)
	if auto_tokens_gain > 0:
		save = _missions_get_save()
		completed = _missions_get_completed(save)
		counters = _missions_get_counters(save)
		_bm_refresh_progress_hud(false)

	var current_idx := _missions_current_index(level_missions, completed)

	if lbl_missions_title != null:
		lbl_missions_title.text = _bm_tr_or_fallback("saison.tab.missions", "Missions")
	if lbl_missions_level != null:
		lbl_missions_level.text = _missions_tr("missions.ui.level", "Lv") + " " + str(level)
	_missions_update_tokens_counter(level_missions, save)

	_missions_clear_canvas()
	var holder := Control.new()
	holder.layout_mode = 1
	holder.anchors_preset = 15
	metro_canvas.add_child(holder)

	var pts: Array = _missions_build_points(level_missions.size())
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color(0.20, 0.75, 1.00, 0.96)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	line.round_precision = 12
	var curve_pts := _missions_build_curve_points(pts)
	for p in curve_pts:
		line.add_point(p)
	holder.add_child(line)

	for i in range(level_missions.size()):
		var mission: Dictionary = level_missions[i]
		var state := "locked"
		var mid := str(mission.get("id", ""))
		var reached := _missions_is_done(mission, counters)
		if completed.has(mid) or reached:
			state = "done"
		elif i == current_idx:
			state = "active"
		_missions_make_station(holder, pts[i], mission, state, i)

	if current_idx >= level_missions.size():
		if lbl_missions_status != null:
			lbl_missions_status.text = _missions_tr("missions.ui.all_done", "Toutes les missions du niveau sont terminées.")
		if lbl_missions_reward != null:
			lbl_missions_reward.text = ""
		if btn_claim_mission != null:
			btn_claim_mission.visible = false
			btn_claim_mission.disabled = true
			btn_claim_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var cur: Dictionary = level_missions[current_idx]
	var cur_key := str(cur.get("check_counter", ""))
	var cur_target := int(cur.get("target", 0))
	var cur_val := int(counters.get(cur_key, 0))
	var done := _missions_is_done(cur, counters)

	if lbl_missions_status != null:
		lbl_missions_status.text = _missions_tr("missions.ui.active", "Mission active") + " : " + _missions_label_text(cur) + " | " + _missions_tr("missions.ui.progress", "Progression") + " : " + str(cur_val) + " / " + str(cur_target)
	if lbl_missions_reward != null:
		lbl_missions_reward.text = _missions_tr("missions.ui.reward", "Gain") + " : " + str(int(cur.get("reward_tokens", 0)))
	if btn_claim_mission != null:
		btn_claim_mission.visible = false
		btn_claim_mission.disabled = true
		btn_claim_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_missions_panel() -> void:
	if missions_panel != null:
		# BM_MISSIONS_HIDE_PLAY_BUTTON_V1
		# L'écran Missions est un écran plein : le bouton Play game ne doit pas rester visible.
		if btn_match != null:
			btn_match.visible = false
		if lbl_season_day != null and is_instance_valid(lbl_season_day):
			lbl_season_day.visible = false
		if _btn_match_halo != null and is_instance_valid(_btn_match_halo):
			_btn_match_halo.visible = false

		missions_panel.visible = true
		missions_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_refresh_missions_panel()

func _hide_missions_panel() -> void:
	if missions_panel != null:
		missions_panel.visible = false
		missions_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# BM_MISSIONS_HIDE_PLAY_BUTTON_V1
	# Restaure uniquement l'UI Saison masquée par l'écran Missions.
	if btn_match != null:
		btn_match.visible = true
	if lbl_season_day != null and is_instance_valid(lbl_season_day):
		lbl_season_day.visible = true
	if _btn_match_halo != null and is_instance_valid(_btn_match_halo):
		_btn_match_halo.visible = true

func _on_close_missions_pressed() -> void:
	_hide_missions_panel()
	call_deferred("_bm_flush_pending_mission_tokens_popup")

func _on_claim_mission_pressed() -> void:
	var save: Dictionary = _missions_get_save()
	var level := _missions_get_level()
	var level_missions: Array = _missions_get_level_data(level)
	var completed: Array = _missions_get_completed(save)
	var counters: Dictionary = _missions_get_counters(save)
	var current_idx := _missions_current_index(level_missions, completed)
	if current_idx >= level_missions.size():
		return
	var cur: Dictionary = level_missions[current_idx]
	if not _missions_is_done(cur, counters):
		return
	if not save.has("missions_progress") or typeof(save["missions_progress"]) != TYPE_DICTIONARY:
		save["missions_progress"] = {"completed": [], "in_progress": [], "selected": []}
	var mp: Dictionary = save["missions_progress"] as Dictionary
	if not mp.has("completed") or typeof(mp["completed"]) != TYPE_ARRAY:
		mp["completed"] = []
	if not mp.has("rewards_awarded") or typeof(mp["rewards_awarded"]) != TYPE_ARRAY:
		mp["rewards_awarded"] = []
	var arr: Array = mp["completed"] as Array
	var rewards_awarded: Array = mp["rewards_awarded"] as Array
	var mid := str(cur.get("id", ""))
	if not arr.has(mid):
		arr.append(mid)
	mp["completed"] = arr
	var reward_tokens := 0
	if not rewards_awarded.has(mid):
		reward_tokens = int(cur.get("reward_tokens", 0))
		rewards_awarded.append(mid)
	mp["rewards_awarded"] = rewards_awarded
	save["missions_progress"] = mp
	if reward_tokens > 0:
		save = PL.add_tokens(save, reward_tokens, "mission_" + mid)
	PL.write_savegame(save)
	if reward_tokens > 0:
		_mission_tokens_popup_pending += reward_tokens
		_mission_tokens_popup_pending_labels.append(_missions_label_text(cur))
	_bm_refresh_progress_hud(false)
	_refresh_missions_panel()

func _bm_open_mercato_from_saison() -> void:
	if _bm_is_mercato_open_now():
		get_tree().change_scene_to_file("res://scenes/Mercato.tscn")
	else:
		_bm_show_mercato_closed_popup()


func _bm_is_mercato_open_now() -> bool:
	if BM_TEST_FORCE_MERCATO_OPEN:
		return true
	var save: Dictionary = {}
	var PL = load("res://scripts/PlayerLife.gd")
	if PL != null and PL.has_method("load_savegame"):
		save = PL.load_savegame()

	var season_round: int = int(save.get("season_round", 0))
	var season_number: int = int(save.get("season_number", 1))
	print("[MERCATO][SAISON] season_number=", season_number, " season_round=", season_round)

	if season_number <= 1:
		return false

	if season_round <= 1:
		return true

	if season_round >= 9 and season_round <= 11:
		return true

	return false


func _bm_get_mercato_current_journee() -> int:
	var PL = load("res://scripts/PlayerLife.gd")
	if PL == null:
		return 0

	var save: Dictionary = {}
	if PL.has_method("load_savegame"):
		save = PL.load_savegame()

	if save.has("progress") and save["progress"] is Dictionary:
		var progress: Dictionary = save["progress"]
		return max(0, int(progress.get("journee", 0)))

	return 0


func _bm_should_open_match_compo_popup_on_play() -> bool:
	var save: Dictionary = PL.load_savegame()
	if typeof(save) != TYPE_DICTIONARY:
		return false


	var season_round: int = int(save.get("season_round", 0))
	var season_number: int = int(save.get("season_number", 1))

	if season_number <= 1:
		if season_round < 5:
			return false
	else:
		if season_round < 0:
			return false

	if not save.has("roster") or typeof(save["roster"]) != TYPE_DICTIONARY:
		return false

	var roster: Dictionary = save["roster"] as Dictionary
	if not roster.has("match_selected_ids") or typeof(roster["match_selected_ids"]) != TYPE_ARRAY:
		return true

	var match_ids: Array = roster["match_selected_ids"] as Array
	return match_ids.size() != 8


func _bm_show_match_compo_popup_on_play() -> void:
	var already := get_node_or_null("MatchCompoPlayPopup")
	if already != null:
		return

	var popup := Control.new()
	popup.name = "MatchCompoPlayPopup"
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 260
	add_child(popup)

	var dark := ColorRect.new()
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0, 0, 0, 0.55)
	dark.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dark)

	var popup_w: float = mini(634.0, get_viewport_rect().size.x * 0.66)
	var popup_h: float = 520.0

	var card := Panel.new()
	card.custom_minimum_size = Vector2(popup_w, popup_h)
	card.size = Vector2(popup_w, popup_h)
	card.position = Vector2(
		(get_viewport_rect().size.x - popup_w) * 0.5,
		(get_viewport_rect().size.y - popup_h) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.96)
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

	var title := Label.new()
	title.text = _bm_tr_or_fallback("popup.match_compo.title", "Compose ton équipe de joueurs pour le match")
	title.position = Vector2(28, 26)
	title.size = Vector2(popup_w - 56, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	card.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.scroll_active = false
	body.fit_content = false
	body.position = Vector2(34, 140)
	body.size = Vector2(popup_w - 68, 260)
	body.text = _bm_tr_or_fallback(
		"popup.match_compo.body",
		"Avant les matchs, tu dois composer ton équipe de 8 joueurs parmi les meilleurs. Prends en compte leur état de fatigue et leur motivation pour mettre toutes les chances de ton équipe de remporter le match. Bonne chance !"
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("normal_font_size", 22)
	body.add_theme_color_override("default_color", Color(0.92, 0.95, 1.0, 0.96))
	card.add_child(body)

	var btn := Button.new()
	btn.text = _bm_tr_or_fallback("popup.match_compo.cta", "Faire la compo")
	btn.custom_minimum_size = Vector2(250, 54)
	btn.size = Vector2(250, 54)
	btn.position = Vector2((popup_w - 250.0) * 0.5, popup_h - 88.0)
	btn.add_theme_font_size_override("font_size", 20)

	var sb_ok := StyleBoxFlat.new()
	sb_ok.bg_color = Color(0.20, 0.55, 0.95, 1.0)
	sb_ok.corner_radius_top_left = 12
	sb_ok.corner_radius_top_right = 12
	sb_ok.corner_radius_bottom_left = 12
	sb_ok.corner_radius_bottom_right = 12
	sb_ok.content_margin_left = 16
	sb_ok.content_margin_right = 16
	sb_ok.content_margin_top = 8
	sb_ok.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb_ok)

	var sb_ok_hover := sb_ok.duplicate()
	sb_ok_hover.bg_color = Color(0.25, 0.62, 1.0, 1.0)
	btn.add_theme_stylebox_override("hover", sb_ok_hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.pressed.connect(func():
		popup.queue_free()
		var tree := get_tree()
		if tree != null and ResourceLoader.exists("res://scenes/MyTeam.tscn"):
			tree.call_deferred("change_scene_to_file", "res://scenes/MyTeam.tscn")
	)

	var ball := TextureRect.new()
	ball.texture = TOKEN_ICON if TOKEN_ICON != null else null
	var ball_path := "res://assets/images/ballon.png"
	if ResourceLoader.exists(ball_path):
		ball.texture = load(ball_path)
	ball.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ball.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ball.custom_minimum_size = Vector2(44, 44)
	ball.size = Vector2(44, 44)
	ball.position = Vector2((popup_w - 44.0) * 0.5, btn.position.y - 52.0)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ball)

	var tw_ball := create_tween()
	tw_ball.set_loops()
	tw_ball.tween_property(ball, "position:y", btn.position.y - 62.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_ball.tween_property(ball, "position:y", btn.position.y - 52.0, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	tw_ball.tween_interval(0.10)

	card.add_child(btn)

func _bm_show_mercato_closed_popup() -> void:
	var popup := AcceptDialog.new()
	popup.title = _bm_tr_or_fallback("mercato.closed.title", "Mercato fermé")
	popup.dialog_text = _bm_tr_or_fallback("mercato.closed.body", "Mercato fermé. Ouverture : avant la saison jusqu'au match 2 inclus, puis pendant les matchs 10, 11 et 12.")
	popup.ok_button_text = "OK"
	popup.min_size = Vector2i(760, 0)
	add_child(popup)
	await get_tree().process_frame
	if popup.get_label() != null:
		popup.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		popup.get_label().add_theme_font_size_override("font_size", 20)
		popup.get_label().custom_minimum_size = Vector2(680, 0)
	popup.confirmed.connect(func(): popup.queue_free())
	popup.canceled.connect(func(): popup.queue_free())
	popup.popup_centered()


func _bm_saison_is_mobile_layout() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(((navigator.maxTouchPoints || 0) > 0) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent))", true)
		if bool(js_mobile):
			return true
	if minf(vp.x, float(win.x)) < 900.0:
		return true
	return false


func _bm_saison_is_mobile_landscape() -> bool:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= vp.y:
		return false
	if OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		var js_mobile_landscape: Variant = JavaScriptBridge.eval("((window.innerWidth > window.innerHeight) && ((navigator.maxTouchPoints || 0) > 0 || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)))", true)
		return bool(js_mobile_landscape)
	return false


func _bm_saison_apply_mobile_bg_and_halo_layout() -> void:
	if not _bm_saison_is_mobile_layout():
		return

	if bg != null:
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0.0
		bg.offset_top = 0.0
		bg.offset_right = 0.0
		bg.offset_bottom = 0.0
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	await get_tree().process_frame
	if _bm_saison_is_mobile_layout() and _btn_match_halo != null and is_instance_valid(_btn_match_halo):
		_btn_match_halo.queue_free()
		_btn_match_halo = null
	else:
		_update_play_match_halo_position()


func _bm_saison_apply_mobile_hud_layout() -> void:
	if not _bm_saison_is_mobile_layout():
		return

	var hud := get_node_or_null("UI/HudProgressPanel") as Control
	if hud == null:
		return

	if not hud.has_meta("bm_saison_mobile_hud_scaled_done"):
		hud.set_meta("bm_saison_mobile_hud_scaled_done", true)
		hud.scale = Vector2(1.15, 1.15)
		hud.custom_minimum_size = Vector2(maxf(1.0, hud.custom_minimum_size.x * 0.72), hud.custom_minimum_size.y * 1.15)

	if not hud.has_meta("bm_saison_mobile_hud_text_plus2_done"):
		hud.set_meta("bm_saison_mobile_hud_text_plus2_done", true)
		for lbl in [lbl_hud_level, lbl_hud_xp, lbl_hud_tokens]:
			if lbl != null:
				var fs: int = int(lbl.get_theme_font_size("font_size"))
				if fs > 0:
					lbl.add_theme_font_size_override("font_size", fs + 2)

	var vp: Vector2 = get_viewport_rect().size
	var margin_right: float = 40.0
	var hud_w: float = maxf(hud.size.x, hud.custom_minimum_size.x)
	hud.anchor_left = 1.0
	hud.anchor_right = 1.0
	hud.offset_left = -hud_w - margin_right
	hud.offset_right = -margin_right
	hud.position.x = vp.x - (hud_w * hud.scale.x) - margin_right


func _bm_saison_apply_mobile_top_left_buttons_plus20_text_plus2() -> void:
	if not _bm_saison_is_mobile_landscape():
		return

	var tabs := get_node_or_null("UI/Tabs") as HBoxContainer
	if tabs != null:
		tabs.offset_top = 10.0
		tabs.offset_bottom = 88.0
		tabs.custom_minimum_size.y = maxf(tabs.custom_minimum_size.y, 78.0)
		tabs.add_theme_constant_override("separation", 34)

	for btn in [btn_classement, btn_statistiques, btn_calendrier, btn_mercato, btn_missions, btn_tournois]:
		if btn == null:
			continue

		btn.scale = Vector2.ONE
		btn.add_theme_font_size_override("font_size", 28)
		btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 170.0), 78.0)
		btn.size = btn.custom_minimum_size
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.min_size_changed()


func _bm_saison_apply_mobile_play_button_plus20_text_plus2() -> void:
	if not _bm_saison_is_mobile_landscape():
		return
	if btn_match == null:
		return

	if not btn_match.has_meta("bm_saison_mobile_play_plus20_done"):
		btn_match.set_meta("bm_saison_mobile_play_plus20_done", true)
		btn_match.scale *= 1.20

	btn_match.add_theme_font_size_override("font_size", 28)


func _bm_saison_apply_mobile_day_and_popularity_texts() -> void:
	if not _bm_saison_is_mobile_layout():
		return

	if lbl_season_day != null and is_instance_valid(lbl_season_day):
		if not lbl_season_day.has_meta("bm_saison_mobile_day_plus20_done"):
			lbl_season_day.set_meta("bm_saison_mobile_day_plus20_done", true)
			lbl_season_day.scale = Vector2(1.20, 1.20)
		if not lbl_season_day.has_meta("bm_saison_mobile_day_text_plus2_done"):
			lbl_season_day.set_meta("bm_saison_mobile_day_text_plus2_done", true)
			var day_fs: int = int(lbl_season_day.get_theme_font_size("font_size"))
			if day_fs > 0:
				lbl_season_day.add_theme_font_size_override("font_size", day_fs + 2)
		_bm_saison_align_mobile_play_and_day()

	for node_path in ["PopularityBadge", "PopularityBadge2", "UI/PopularityBadge", "UI/PopularityBadge2"]:
		var lbl := get_node_or_null(node_path) as Label
		if lbl == null:
			continue
		if lbl.has_meta("bm_saison_mobile_popularity_text_plus2_done"):
			continue
		lbl.set_meta("bm_saison_mobile_popularity_text_plus2_done", true)
		var fs: int = int(lbl.get_theme_font_size("font_size"))
		if fs > 0:
			lbl.add_theme_font_size_override("font_size", fs + 2)

func _bm_saison_align_mobile_play_and_day() -> void:
	if not _bm_saison_is_mobile_layout():
		return
	if btn_match == null:
		return
	if lbl_season_day == null or not is_instance_valid(lbl_season_day):
		return

	await get_tree().process_frame

	var match_size: Vector2 = btn_match.size
	if match_size.x <= 1.0 or match_size.y <= 1.0:
		match_size = btn_match.get_combined_minimum_size()

	lbl_season_day.size = Vector2(match_size.x, lbl_season_day.size.y)
	lbl_season_day.position = Vector2(
		btn_match.position.x,
		btn_match.position.y - lbl_season_day.size.y - 20.0
	)
	lbl_season_day.pivot_offset = lbl_season_day.size * 0.5
	btn_match.pivot_offset = btn_match.size * 0.5
