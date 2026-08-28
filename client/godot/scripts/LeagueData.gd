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

const LEAGUE_CHOICES: Array[Dictionary] = [
	{"id": "challenger", "name": "Challenger League", "image": "res://assets/images/backgrounds/league_challenger.png"},
	{"id": "growth", "name": "Growth League", "image": "res://assets/images/backgrounds/league_growth.png"},
	{"id": "classic", "name": "Classic League", "image": "res://assets/images/backgrounds/league_classic.png"},
	{"id": "premium", "name": "Premium League", "image": "res://assets/images/backgrounds/league_premium.png"},
	{"id": "stars", "name": "Stars League", "image": "res://assets/images/backgrounds/league_stars.png"}
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

static func get_classic_league() -> Dictionary:
	return {
		"id": CLASSIC_LEAGUE_ID,
		"team_count": CLASSIC_TEAM_COUNT,
		"total_rounds": CLASSIC_TOTAL_ROUNDS,
		"opponents": CLASSIC_OPPONENT_NAMES.duplicate()
	}
