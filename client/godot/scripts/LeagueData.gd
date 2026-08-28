extends RefCounted
class_name LeagueData

const CLASSIC_LEAGUE_ID: String = "classic"
const CLASSIC_TEAM_COUNT: int = 12
const CLASSIC_TOTAL_ROUNDS: int = 22

const CLASSIC_OPPONENT_NAMES: Array[String] = [
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

const COEF_NAMES: Array[String] = [
	"ai_strength",
	"ai_variance",
	"sponsor",
	"ticketing",
	"salary",
	"transfer",
	"staff",
	"stadium",
	"season_reward",
	"top4_reward",
	"title_reward"
]

const LEAGUE_CHOICES: Array[Dictionary] = [
	{
		"id": "challenger",
		"name": "Challenger League",
		"image": "res://assets/images/backgrounds/league_challenger.png",
		"coefs": {
			"ai_strength": 0.78,
			"ai_variance": 1.00,
			"sponsor": 0.70,
			"ticketing": 0.75,
			"salary": 0.70,
			"transfer": 0.72,
			"staff": 0.80,
			"stadium": 0.85,
			"season_reward": 0.80,
			"top4_reward": 0.85,
			"title_reward": 0.95
		}
	},
	{
		"id": "growth",
		"name": "Growth League",
		"image": "res://assets/images/backgrounds/league_growth.png",
		"coefs": {
			"ai_strength": 0.92,
			"ai_variance": 1.00,
			"sponsor": 0.95,
			"ticketing": 1.00,
			"salary": 0.90,
			"transfer": 0.92,
			"staff": 0.95,
			"stadium": 0.95,
			"season_reward": 1.15,
			"top4_reward": 1.30,
			"title_reward": 1.45
		}
	},
	{
		"id": "classic",
		"name": "Classic League",
		"image": "res://assets/images/backgrounds/league_classic.png",
		"coefs": {
			"ai_strength": 1.00,
			"ai_variance": 1.00,
			"sponsor": 1.00,
			"ticketing": 1.00,
			"salary": 1.00,
			"transfer": 1.00,
			"staff": 1.00,
			"stadium": 1.00,
			"season_reward": 1.00,
			"top4_reward": 1.00,
			"title_reward": 1.00
		}
	},
	{
		"id": "premium",
		"name": "Premium League",
		"image": "res://assets/images/backgrounds/league_premium.png",
		"coefs": {
			"ai_strength": 1.12,
			"ai_variance": 1.00,
			"sponsor": 1.45,
			"ticketing": 1.40,
			"salary": 1.35,
			"transfer": 1.30,
			"staff": 1.20,
			"stadium": 1.20,
			"season_reward": 1.35,
			"top4_reward": 1.55,
			"title_reward": 1.75
		}
	},
	{
		"id": "stars",
		"name": "Stars League",
		"image": "res://assets/images/backgrounds/league_stars.png",
		"coefs": {
			"ai_strength": 1.35,
			"ai_variance": 1.00,
			"sponsor": 1.30,
			"ticketing": 1.35,
			"salary": 1.60,
			"transfer": 1.55,
			"staff": 1.35,
			"stadium": 1.25,
			"season_reward": 1.50,
			"top4_reward": 2.10,
			"title_reward": 2.60
		}
	}
]

static func get_league_choices() -> Array[Dictionary]:
	return LEAGUE_CHOICES.duplicate(true)

static func get_default_league_id() -> String:
	return CLASSIC_LEAGUE_ID

static func get_league_name(league_id: String) -> String:
	for league in LEAGUE_CHOICES:
		if str(league.get("id", "")) == league_id:
			return str(league.get("name", "Classic League"))
	return "Classic League"

static func get_league_coefs(league_id: String) -> Dictionary:
	var requested_id := league_id.strip_edges()
	var fallback_coefs: Dictionary = {}
	for league in LEAGUE_CHOICES:
		if str(league.get("id", "")) == CLASSIC_LEAGUE_ID:
			var raw_fallback: Variant = league.get("coefs", {})
			if typeof(raw_fallback) == TYPE_DICTIONARY:
				fallback_coefs = (raw_fallback as Dictionary).duplicate(true)
		if str(league.get("id", "")) == requested_id:
			var raw_coefs: Variant = league.get("coefs", {})
			if typeof(raw_coefs) == TYPE_DICTIONARY:
				return (raw_coefs as Dictionary).duplicate(true)
	return fallback_coefs

static func get_coef(league_id: String, coef_name: String) -> float:
	var key := coef_name.strip_edges()
	if key == "":
		return 1.0
	var coefs := get_league_coefs(league_id)
	if not coefs.has(key):
		return 1.0
	var value: Variant = coefs.get(key, 1.0)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 1.0
	return float(value)

static func get_classic_league() -> Dictionary:
	return {
		"id": CLASSIC_LEAGUE_ID,
		"team_count": CLASSIC_TEAM_COUNT,
		"total_rounds": CLASSIC_TOTAL_ROUNDS,
		"opponents": CLASSIC_OPPONENT_NAMES.duplicate()
	}
