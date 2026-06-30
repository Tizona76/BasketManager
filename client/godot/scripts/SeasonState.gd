extends Node

var standings: Dictionary = {}
var ranking_history: Array[int] = []
var season_results_by_round: Dictionary = {}

# Équivalent des variables globales Python (menu_saison)

var zone_selectionnee_saison: String = ""  # "", "classement", "statistiques", "calendrier", "mercato", "missions"

var popup_bienvenue_saison_deja_vu: bool = false
var popup_bienvenue_club_deja_vu: bool = false
var early_flow_post_selection_hide_menu_buttons: bool = false
var early_flow_post_selection_dimmed: bool = false

var decalage_scroll_calendrier: int = 0
var hauteur_contenu_calendrier: int = 0

var matchs_joues: int = 0
var total_matchs_saison: int = 22

var club_level: int = 1


# --- Opponents (noms affichage) ---
# 11 adversaires (si championnat à 12 équipes avec ton équipe)
const OPPONENT_NAMES: Array[String] = [
	"Panthères",
	"Toros",
	"Wolves",
	"Falcons",
	"Sharks",
	"Dragons",
	"Titans",
	"Raptors",
	"Kings",
	"Comets",
	"Storm"
]

var opponent_name: String = ""

const SEASON_TOTAL_ROUNDS: int = 22

func compute_next_opponent_name(my_team_name: String) -> String:
	# Déterministe : dépend de matchs_joues (donc stable)
	var names: Array[String] = []
	for n in OPPONENT_NAMES:
		if n != my_team_name:
			names.append(n)
	if names.is_empty():
		return "Adversaire"
	var idx := int(matchs_joues) % names.size()
	return names[idx]

func _ensure_standings_initialized(user_team_name: String) -> void:
	# Initialise 12 équipes si vide (ou si clé manquante)
	if standings.size() > 0:
		return

	# Liste de base : ton équipe + 11 adversaires (si tu as déjà une liste officielle ailleurs, on l’utilisera ensuite)
	var teams: Array[String] = []
	if user_team_name.strip_edges() != "":
		teams.append(user_team_name.strip_edges())

	# Fallback générique : on garde les noms connus si tu les as déjà dans ta logique opponent
	# IMPORTANT: on ne casse rien, on peut remplacer cette liste plus tard par ta vraie liste SeasonState.
	var default_opps: Array[String] = [
		"Panthères","Toros","Hawks","Wolves","Kings","Bulls","Sharks","Rockets","Eagles","Giants","Lions"
	]

	for t in default_opps:
		if t not in teams:
			teams.append(t)

	# Si moins de 12, on complète
	var i := 1
	while teams.size() < 12:
		var name := "Team " + str(i)
		if name not in teams:
			teams.append(name)
		i += 1

	# Format d’une ligne de classement
	for t in teams:
		standings[t] = {
			"W": 0, "L": 0,
			"PF": 0, "PA": 0,
			"DIFF": 0
		}

func register_match_result(dom_team: String, ext_team: String, score_dom: int, score_ext: int, user_team_name: String) -> void:
	var round_index: int = int(matchs_joues)
	var result_key := str(dom_team) + "||" + str(ext_team)
	var round_results_mem: Dictionary = {}
	if season_results_by_round.has(round_index) and typeof(season_results_by_round[round_index]) == TYPE_DICTIONARY:
		round_results_mem = season_results_by_round[round_index] as Dictionary
	round_results_mem[result_key] = {
		"score_dom": int(score_dom),
		"score_ext": int(score_ext)
	}
	season_results_by_round[round_index] = round_results_mem

	_ensure_standings_initialized(user_team_name)

	if not standings.has(dom_team):
		standings[dom_team] = {"PTS":0,"W":0,"L":0,"PF":0,"PA":0,"DIFF":0}
	if not standings.has(ext_team):
		standings[ext_team] = {"PTS":0,"W":0,"L":0,"PF":0,"PA":0,"DIFF":0}

	# Ensure PTS exists (retro-compat)
	if not standings[dom_team].has("PTS"): standings[dom_team]["PTS"] = 0
	if not standings[ext_team].has("PTS"): standings[ext_team]["PTS"] = 0

	# Update PF/PA
	standings[dom_team]["PF"] += int(score_dom)
	standings[dom_team]["PA"] += int(score_ext)

	standings[ext_team]["PF"] += int(score_ext)
	standings[ext_team]["PA"] += int(score_dom)

	# Update PTS + W/L (3/1/0)
	if score_dom > score_ext:
		standings[dom_team]["PTS"] += 3
		standings[dom_team]["W"] += 1
		standings[ext_team]["L"] += 1
	elif score_dom < score_ext:
		standings[ext_team]["PTS"] += 3
		standings[ext_team]["W"] += 1
		standings[dom_team]["L"] += 1
	else:
		# draw
		standings[dom_team]["PTS"] += 1
		standings[ext_team]["PTS"] += 1

	# Diff recalculée
	standings[dom_team]["DIFF"] = int(standings[dom_team]["PF"]) - int(standings[dom_team]["PA"])
	standings[ext_team]["DIFF"] = int(standings[ext_team]["PF"]) - int(standings[ext_team]["PA"])

func simulate_other_games_for_round(dom_team: String, ext_team: String, round_index: int, user_team_name: String) -> void:
	# Simule les autres matchs de la journée (calendrier fixe 22 rounds), sans historique.
	_ensure_standings_initialized(user_team_name)

	var r := int(round_index) % SEASON_TOTAL_ROUNDS
	var games := _rr_games_for_round(user_team_name, r)

	# On ne simule PAS le match déjà joué (dom_team/ext_team tel qu’affiché)
	for g in games:
		var d := str(g["dom"])
		var e := str(g["ext"])

		# skip le match user (peu importe l'ordre)
		var same := (d == dom_team and e == ext_team) or (d == ext_team and e == dom_team)
		if same:
			continue

		# Score cohérent (simple). On raffinera plus tard avec pondérations.
		var base_score: int = randi_range(70, 90)
		var score_dom_sim := clampi(base_score + randi_range(-10, 10), 55, 125)
		var score_ext_sim := clampi(base_score + randi_range(-10, 10), 55, 125)

		register_match_result(d, e, score_dom_sim, score_ext_sim, user_team_name)


func _rr_build_teams(user_team_name: String) -> Array[String]:
	# 12 équipes fixes: user + 11 adversaires (mêmes noms que standings init)
	_ensure_standings_initialized(user_team_name)
	var teams: Array[String] = []
	for t in standings.keys():
		teams.append(str(t))
	teams.sort() # ordre stable

	# forcer user en tête (stabilité)
	var u := user_team_name.strip_edges()
	if u != "" and u in teams:
		teams.erase(u)
	teams.insert(0, u if u != "" else teams[0])

	# s'assurer de 12
	while teams.size() > 12:
		teams.pop_back()
	while teams.size() < 12:
		teams.append("Team " + str(teams.size() + 1))
	return teams

func _rr_pairs_for_round_first_leg(teams: Array[String], r: int) -> Array:
	# Circle method (12 équipes => 6 matchs). On fixe teams[0], on rotate les autres.
	var n := teams.size()
	if n % 2 != 0:
		return []

	var fixed := teams[0]
	var rot: Array = []
	for i in range(1, n):
		rot.append(teams[i])

	# rotation r fois
	for _i in range(r % (n - 1)):
		var last = rot.pop_back()
		rot.insert(0, last)

	var all: Array = [fixed] + rot

	var games: Array = []
	var half := n / 2
	for i in range(half):
		var a := str(all[i])
		var b := str(all[n - 1 - i])
		games.append([a, b]) # pairing non orienté (home/away assigné après)
	return games

func _rr_games_for_round(user_team_name: String, round_index: int) -> Array:
	# Retour: Array de Dictionary {dom, ext}
	var teams := _rr_build_teams(user_team_name)
	if teams.size() < 4:
		return []

	var r := int(round_index) % SEASON_TOTAL_ROUNDS
	var first_leg := (r < 11)
	var base_r := r if first_leg else (r - 11)

	var pairs := _rr_pairs_for_round_first_leg(teams, base_r)

	# home/away initial (stable), puis on force alternance pour user
	var games: Array = []
	for i in range(pairs.size()):
		var a := str(pairs[i][0])
		var b := str(pairs[i][1])

		# Assign home/away stable
		var a_home := ((base_r + i) % 2 == 0)
		var dom := a if a_home else b
		var ext := b if a_home else a

		# Retour = swap home/away
		if not first_leg:
			var tmp := dom
			dom = ext
			ext = tmp

		games.append({"dom": dom, "ext": ext})

	# Forcer alternance home/away pour l'équipe user (jour pair = domicile)
	var user_home_target := (r % 2 == 0)
	for g in games:
		if g["dom"] == user_team_name or g["ext"] == user_team_name:
			var is_home: bool = (str(g["dom"]) == user_team_name)
			if is_home != user_home_target:
				var tmp2: String = str(g["dom"])
				g["dom"] = str(g["ext"])
				g["ext"] = tmp2
			break

	return games

func get_user_fixture_for_round(user_team_name: String, round_index: int) -> Dictionary:
	var games := _rr_games_for_round(user_team_name, round_index)
	for g in games:
		if g["dom"] == user_team_name or g["ext"] == user_team_name:
			var out := {
				"dom": str(g["dom"]),
				"ext": str(g["ext"]),
				"user_is_home": (str(g["dom"]) == user_team_name),
				"opponent": (str(g["ext"]) if str(g["dom"]) == user_team_name else str(g["dom"]))
			}

			var result_key := str(g["dom"]) + "||" + str(g["ext"])
			if season_results_by_round.has(round_index) and typeof(season_results_by_round[round_index]) == TYPE_DICTIONARY:
				var round_results: Dictionary = season_results_by_round[round_index] as Dictionary
				if round_results.has(result_key) and typeof(round_results[result_key]) == TYPE_DICTIONARY:
					var rr: Dictionary = round_results[result_key] as Dictionary
					out["home_score"] = int(rr.get("score_dom", 0))
					out["away_score"] = int(rr.get("score_ext", 0))

			return out
	return {}


func get_current_club_rank(user_team_name: String) -> int:
	_ensure_standings_initialized(user_team_name)

	if standings.size() == 0:
		return 1

	var teams: Array = standings.keys()
	teams.sort_custom(func(a, b):
		var da: Dictionary = standings[a]
		var db: Dictionary = standings[b]

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

	var pos: int = 1
	for t in teams:
		if str(t) == user_team_name:
			return pos
		pos += 1

	return max(1, min(teams.size(), pos))


func push_current_club_rank(user_team_name: String) -> void:
	var rank: int = get_current_club_rank(user_team_name)
	ranking_history.append(rank)


func clear_ranking_history() -> void:
	ranking_history.clear()


func get_ranking_history_as_float_array() -> Array:
	var out: Array = []
	for v in ranking_history:
		out.append(float(v))
	return out


# === BM_TOURNOI_A_V1 ===
var tournoi_actif: String = "printemps"
var niveau_tournoi_selectionne: String = ""
var tournois_disponibles := {
	"printemps": {
		"nom": "Tournoi de Printemps",
		"etat": "en_attente",
		"niveaux": {
			"Débutant": {
				"equipes": [],
				"matchs": [],
				"tour_actuel": 0,
				"resultats": [],
				"etat": "en_attente",
				"vainqueur": "",
				"classement": []
			},
			"Intermédiaire": {
				"equipes": [],
				"matchs": [],
				"tour_actuel": 0,
				"resultats": [],
				"etat": "en_attente",
				"vainqueur": "",
				"classement": []
			},
			"Élite": {
				"equipes": [],
				"matchs": [],
				"tour_actuel": 0,
				"resultats": [],
				"etat": "en_attente",
				"vainqueur": "",
				"classement": []
			}
		}
	}
}

const NB_EQUIPE_TOURNOI := {
	"Débutant": 8,
	"Intermédiaire": 16,
	"Élite": 16
}

const NOMS_EQUIPES_TOURNOI := [
	"Toros", "Dauphins", "Ours", "Grizzlis",
	"Lions", "Faucons", "Guépards", "Lynx",
	"Panthères", "Aigles", "Tigres", "Bulls3",
	"Hawks", "Wolves"
]

func bm_same_team(a: String, b: String) -> bool:
	return String(a).strip_edges().to_lower() == String(b).strip_edges().to_lower()

func bm_get_my_team_name() -> String:
	var fallback := "Mon équipe"

	var PL = load("res://scripts/PlayerLife.gd")
	if PL != null and PL.has_method("load_savegame"):
		var d: Dictionary = PL.load_savegame()
		if typeof(d) == TYPE_DICTIONARY:
			for k in ["team_name", "club_name", "nom_equipe", "team", "name"]:
				var v := String(d.get(k, "")).strip_edges()
				if v != "":
					return v
			if d.has("club") and typeof(d["club"]) == TYPE_DICTIONARY:
				var club_name := String((d["club"] as Dictionary).get("name", "")).strip_edges()
				if club_name != "":
					return club_name

	return fallback

func bm_get_tournoi_courant() -> Dictionary:
	var tg: Dictionary = tournois_disponibles.get(tournoi_actif, {})
	var nivs: Dictionary = tg.get("niveaux", {})
	return nivs.get(niveau_tournoi_selectionne, {})

func bm_init_tournoi_a() -> void:
	tournoi_actif = "printemps"
	niveau_tournoi_selectionne = "Débutant"

	var t_global: Dictionary = tournois_disponibles.get(tournoi_actif, {})
	var niveaux: Dictionary = t_global.get("niveaux", {})
	var t: Dictionary = niveaux.get(niveau_tournoi_selectionne, {})

	if String(t.get("etat", "")).strip_edges().to_lower() == "termine":
		return

	var nb_equipes := int(NB_EQUIPE_TOURNOI.get(niveau_tournoi_selectionne, 8))
	var my_team := bm_get_my_team_name()

	var pool: Array = []
	for e in NOMS_EQUIPES_TOURNOI:
		if not bm_same_team(String(e), my_team):
			pool.append(String(e))

	pool.shuffle()

	var participantes: Array = [my_team]
	for i in range(min(nb_equipes - 1, pool.size())):
		participantes.append(pool[i])

	participantes.shuffle()

	var premier_tour: Array = []
	var i := 0
	while i + 1 < participantes.size():
		premier_tour.append([participantes[i], participantes[i + 1]])
		i += 2

	t["equipes"] = participantes
	t["matchs"] = [premier_tour]
	t["tour_actuel"] = 0
	t["resultats"] = []
	t["vainqueur"] = ""
	t["classement"] = []
	t["etat"] = "en_cours"
	t_global["etat"] = "en_cours"
	niveaux[niveau_tournoi_selectionne] = t
	t_global["niveaux"] = niveaux
	tournois_disponibles[tournoi_actif] = t_global

func bm_simuler_tournoi_courant() -> void:
	var t_global: Dictionary = tournois_disponibles.get(tournoi_actif, {})
	var niveaux: Dictionary = t_global.get("niveaux", {})
	var t: Dictionary = niveaux.get(niveau_tournoi_selectionne, {})

	var tour := int(t.get("tour_actuel", 0))
	var matchs: Array = t.get("matchs", [])

	if tour >= matchs.size():
		return

	var matchs_tour: Array = matchs[tour]
	var resultats_tour: Array = []
	var gagnants: Array = []

	for m in matchs_tour:
		if typeof(m) != TYPE_ARRAY or m.size() < 2:
			continue
		var e1 := String(m[0])
		var e2 := String(m[1])
		var s1 := randi_range(70, 100)
		var s2 := randi_range(70, 100)
		while s1 == s2:
			s2 += 1
		resultats_tour.append({
			"equipe1": e1,
			"equipe2": e2,
			"score1": s1,
			"score2": s2
		})
		gagnants.append(e1 if s1 > s2 else e2)

	var all_res: Array = t.get("resultats", [])
	if all_res.size() <= tour:
		all_res.append(resultats_tour)
	else:
		all_res[tour] = resultats_tour
	t["resultats"] = all_res

	if gagnants.size() == 1:
		t["etat"] = "termine"
		t["vainqueur"] = String(gagnants[0])
		var classement: Array = [String(gagnants[0])]
		for e in t.get("equipes", []):
			if not bm_same_team(String(e), String(gagnants[0])):
				classement.append(String(e))
		t["classement"] = classement
		t_global["etat"] = "termine"
	else:
		var prochain_tour: Array = []
		var i := 0
		while i + 1 < gagnants.size():
			prochain_tour.append([String(gagnants[i]), String(gagnants[i + 1])])
			i += 2
		matchs.append(prochain_tour)
		t["matchs"] = matchs
		t["tour_actuel"] = tour + 1
		t["etat"] = "en_cours"

	niveaux[niveau_tournoi_selectionne] = t
	t_global["niveaux"] = niveaux
	tournois_disponibles[tournoi_actif] = t_global

func bm_tournoi_a_status_text() -> String:
	var t := bm_get_tournoi_courant()
	if t.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("Tournoi A - " + tr("tournois.beginner"))

	var matchs: Array = t.get("matchs", [])
	var resultats: Array = t.get("resultats", [])
	for round_idx in range(matchs.size()):
		lines.append("")
		lines.append(tr("tournois.round") + " " + str(round_idx + 1))
		var round_matches: Array = matchs[round_idx]
		for mi in range(round_matches.size()):
			var m = round_matches[mi]
			if typeof(m) != TYPE_ARRAY or m.size() < 2:
				continue
			var e1 := String(m[0])
			var e2 := String(m[1])
			var line := e1 + " vs " + e2
			if round_idx < resultats.size():
				var rr: Array = resultats[round_idx]
				if mi < rr.size() and typeof(rr[mi]) == TYPE_DICTIONARY:
					var d: Dictionary = rr[mi]
					line += "  |  " + str(d.get("score1", 0)) + " - " + str(d.get("score2", 0))
			lines.append(line)

	if String(t.get("etat", "")).strip_edges().to_lower() == "termine":
		lines.append("")
		lines.append("Vainqueur : " + String(t.get("vainqueur", "")))
	else:
		lines.append("")
		lines.append(tr("tournois.current_round") + " : " + str(int(t.get("tour_actuel", 0)) + 1))

	return "\n".join(lines)
