extends RefCounted
class_name SponsorData

const FAMILY_LOCAL := "LOCAL"
const FAMILY_NATIONAL := "NATIONAL"
const FAMILY_PREMIUM := "PREMIUM"
const FAMILIES := [FAMILY_LOCAL, FAMILY_NATIONAL, FAMILY_PREMIUM]

const PAYMENT_PER_MATCH := "PER_MATCH"
const PAYMENT_PER_SEASON := "PER_SEASON"
const PAYMENT_TYPES := [PAYMENT_PER_MATCH, PAYMENT_PER_SEASON]

const UNLOCK_CLUB_LEVEL_LOCAL := 1
const UNLOCK_CLUB_LEVEL_NATIONAL := 1
const UNLOCK_CLUB_LEVEL_PREMIUM := 5

const BONUS_TOP_10 := "TOP_10"
const BONUS_TOP_5 := "TOP_5"
const BONUS_TOP_3 := "TOP_3"
const BONUS_FINALIST := "FINALIST"
const BONUS_CHAMPION := "CHAMPION"
const BONUS_TOURNAMENT_WINNER := "TOURNAMENT_WINNER"
const BONUS_TYPES := [BONUS_TOP_10, BONUS_TOP_5, BONUS_TOP_3, BONUS_FINALIST, BONUS_CHAMPION, BONUS_TOURNAMENT_WINNER]

const PROFILE_BEGINNER := "BEGINNER"
const PROFILE_INTERMEDIATE := "INTERMEDIATE"
const PROFILE_ADVANCED := "ADVANCED"

const ACTIVE_CONTRACT_SAVE_KEY := "active_sponsor_contract"
const KNOWN_SPONSORS_SAVE_KEY := "known_sponsors"
const LAST_SIGNED_SPONSOR_SAVE_KEY := "last_signed_sponsor_id"
const SPONSORS_UNLOCKED_SAVE_KEY := "sponsors_unlocked"
const SPONSORS_EXPIRED_POPUP_PENDING_SAVE_KEY := "pending_sponsors_expired_popup"
const DEFAULT_SPONSOR_LOGO := "res://assets/images/logos/logo1.jpg"

const FAMILY_I18N := {
	FAMILY_LOCAL: "sponsors.family.local",
	FAMILY_NATIONAL: "sponsors.family.national",
	FAMILY_PREMIUM: "sponsors.family.premium",
}

const PAYMENT_I18N := {
	PAYMENT_PER_MATCH: "sponsors.payment.per_match",
	PAYMENT_PER_SEASON: "sponsors.payment.per_season",
}

const BONUS_I18N := {
	BONUS_TOP_10: "sponsors.bonus.top_10",
	BONUS_TOP_5: "sponsors.bonus.top_5",
	BONUS_TOP_3: "sponsors.bonus.top_3",
	BONUS_FINALIST: "sponsors.bonus.finalist",
	BONUS_CHAMPION: "sponsors.bonus.champion",
	BONUS_TOURNAMENT_WINNER: "sponsors.bonus.tournament_winner",
}

const MARKET_PROGRESSIONS := [
	{"min_level": 1, "max_level": 2, "families": [FAMILY_LOCAL, FAMILY_LOCAL, FAMILY_NATIONAL]},
	{"min_level": 3, "max_level": 4, "families": [FAMILY_LOCAL, FAMILY_NATIONAL, FAMILY_NATIONAL]},
	{"min_level": 5, "max_level": 6, "families": [FAMILY_NATIONAL, FAMILY_NATIONAL, FAMILY_PREMIUM]},
	{"min_level": 7, "max_level": 8, "families": [FAMILY_NATIONAL, FAMILY_PREMIUM, FAMILY_PREMIUM]},
	{"min_level": 9, "max_level": 999, "families": [FAMILY_PREMIUM, FAMILY_PREMIUM, FAMILY_PREMIUM]},
]

const SPONSORS := [
	{
		"id": "local_pizzeria",
		"name": "sponsors.name.local_pizzeria",
		"family": FAMILY_LOCAL,
		"logo": "res://assets/images/sponsors/sponsor1.png",
		"payment_type": PAYMENT_PER_SEASON,
		"payment_amount": 40000,
		"duration_type": PAYMENT_PER_SEASON,
		"duration_value": 1,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_LOCAL,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "local_sports_shop",
		"name": "sponsors.name.local_sports_shop",
		"family": FAMILY_LOCAL,
		"logo": "res://assets/images/sponsors/sponsor2.png",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 5500,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 10,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_LOCAL,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "local_cafe",
		"name": "sponsors.name.local_cafe",
		"family": FAMILY_LOCAL,
		"logo": "res://assets/images/sponsors/sponsor3.png",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 3500,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 10,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_LOCAL,
		"bonus_type": BONUS_TOP_10,
		"bonus_amount": 45000,
	},
	{
		"id": "national_bank",
		"name": "sponsors.name.national_bank",
		"family": FAMILY_NATIONAL,
		"logo": "res://assets/images/sponsors/sponsor4.png",
		"payment_type": PAYMENT_PER_SEASON,
		"payment_amount": 120000,
		"duration_type": PAYMENT_PER_SEASON,
		"duration_value": 1,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_NATIONAL,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "national_media",
		"name": "sponsors.name.national_media",
		"family": FAMILY_NATIONAL,
		"logo": "res://assets/images/token.png",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 11000,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 14,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_NATIONAL,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "national_airline",
		"name": "sponsors.name.national_airline",
		"family": FAMILY_NATIONAL,
		"logo": "res://assets/images/coupe.png",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 8000,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 14,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_NATIONAL,
		"bonus_type": BONUS_TOP_5,
		"bonus_amount": 90000,
	},
	{
		"id": "premium_global_tech",
		"name": "sponsors.name.premium_global_tech",
		"family": FAMILY_PREMIUM,
		"logo": "res://assets/images/recompenses/coupe.png",
		"payment_type": PAYMENT_PER_SEASON,
		"payment_amount": 280000,
		"duration_type": PAYMENT_PER_SEASON,
		"duration_value": 1,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_PREMIUM,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "premium_sportswear",
		"name": "sponsors.name.premium_sportswear",
		"family": FAMILY_PREMIUM,
		"logo": "res://assets/images/recompenses/medaille_argent.png",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 22000,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 18,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_PREMIUM,
		"bonus_type": "",
		"bonus_amount": 0,
	},
	{
		"id": "premium_global_motors",
		"name": "sponsors.name.premium_global_motors",
		"family": FAMILY_PREMIUM,
		"logo": "res://assets/images/logos/logo1.jpg",
		"payment_type": PAYMENT_PER_MATCH,
		"payment_amount": 15000,
		"duration_type": PAYMENT_PER_MATCH,
		"duration_value": 18,
		"unlock_club_level": UNLOCK_CLUB_LEVEL_PREMIUM,
		"bonus_type": BONUS_CHAMPION,
		"bonus_amount": 250000,
	},
]


static func get_sponsor_by_id(sponsor_id: String) -> Dictionary:
	for sponsor in SPONSORS:
		if str(sponsor.get("id", "")) == sponsor_id:
			return sponsor.duplicate(true)
	return {}


static func get_offer_mix(_profile: String) -> Array:
	return get_offer_mix_for_club_level(UNLOCK_CLUB_LEVEL_LOCAL)


static func get_offer_mix_for_club_level(club_level: int) -> Array:
	var safe_level := maxi(1, club_level)
	for rule in MARKET_PROGRESSIONS:
		var min_level := int((rule as Dictionary).get("min_level", 1))
		var max_level := int((rule as Dictionary).get("max_level", 999))
		if safe_level >= min_level and safe_level <= max_level:
			return ((rule as Dictionary).get("families", []) as Array).duplicate()
	return [FAMILY_LOCAL, FAMILY_LOCAL, FAMILY_NATIONAL]


static func _is_sponsor_unlocked(sponsor: Dictionary, club_level: int) -> bool:
	return club_level >= int(sponsor.get("unlock_club_level", UNLOCK_CLUB_LEVEL_LOCAL))


static func _add_offer_if_available(offers: Array, used_ids: Array[String], sponsor: Dictionary, club_level: int, require_unlocked: bool = true) -> bool:
	var sponsor_id := str(sponsor.get("id", ""))
	if sponsor_id == "" or used_ids.has(sponsor_id):
		return false
	if require_unlocked and not _is_sponsor_unlocked(sponsor, club_level):
		return false
	offers.append(sponsor.duplicate(true))
	used_ids.append(sponsor_id)
	return true


static func _remove_one_family_slot(families: Array, family: String) -> void:
	for i in range(families.size()):
		if str(families[i]) == family:
			families.remove_at(i)
			return


static func _add_first_offer_from_family(offers: Array, used_ids: Array[String], family: String, club_level: int, preferred_ids: Array[String] = [], avoid_ids: Array[String] = []) -> bool:
	for preferred_id in preferred_ids:
		if avoid_ids.has(preferred_id):
			continue
		var preferred_sponsor := get_sponsor_by_id(preferred_id)
		if not preferred_sponsor.is_empty() and str(preferred_sponsor.get("family", "")) == family:
			if _add_offer_if_available(offers, used_ids, preferred_sponsor, club_level):
				return true

	for sponsor in SPONSORS:
		var sponsor_dict := sponsor as Dictionary
		var sponsor_id := str(sponsor_dict.get("id", ""))
		if avoid_ids.has(sponsor_id):
			continue
		if str(sponsor_dict.get("family", "")) == family:
			if _add_offer_if_available(offers, used_ids, sponsor_dict, club_level):
				return true

	return false


static func get_known_sponsors(save: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = save.get(KNOWN_SPONSORS_SAVE_KEY, [])
	if typeof(raw) == TYPE_ARRAY:
		for item in raw as Array:
			var sponsor_id := str(item).strip_edges()
			if sponsor_id != "" and not result.has(sponsor_id):
				result.append(sponsor_id)
	return result


static func remember_sponsor_ids(save: Dictionary, sponsor_ids: Array[String]) -> bool:
	var known := get_known_sponsors(save)
	var changed := false
	for sponsor_id in sponsor_ids:
		var clean_id := str(sponsor_id).strip_edges()
		if clean_id != "" and not known.has(clean_id):
			known.append(clean_id)
			changed = true
	if changed or not save.has(KNOWN_SPONSORS_SAVE_KEY):
		save[KNOWN_SPONSORS_SAVE_KEY] = known
	return changed


static func get_last_signed_sponsor_id(save: Dictionary) -> String:
	return str(save.get(LAST_SIGNED_SPONSOR_SAVE_KEY, "")).strip_edges()


static func get_offers(profile: String = PROFILE_BEGINNER, club_level: int = UNLOCK_CLUB_LEVEL_LOCAL, active_sponsor_id: String = "", known_sponsor_ids: Array[String] = []) -> Array:
	var offers: Array = []
	var used_ids: Array[String] = []
	var target_families := get_offer_mix_for_club_level(club_level)

	if active_sponsor_id != "":
		var active_sponsor := get_sponsor_by_id(active_sponsor_id)
		if not active_sponsor.is_empty():
			_add_offer_if_available(offers, used_ids, active_sponsor, club_level, false)
			_remove_one_family_slot(target_families, str(active_sponsor.get("family", "")))

		var unknown_ids: Array[String] = []
		for sponsor in SPONSORS:
			if offers.size() >= 3:
				break
			var sponsor_id := str((sponsor as Dictionary).get("id", ""))
			if not known_sponsor_ids.has(sponsor_id):
				unknown_ids.append(sponsor_id)

		for family in target_families:
			if offers.size() >= 3:
				break
			if _add_first_offer_from_family(offers, used_ids, str(family), club_level, known_sponsor_ids, [active_sponsor_id]):
				continue
			_add_first_offer_from_family(offers, used_ids, str(family), club_level, unknown_ids, [active_sponsor_id])

		if offers.size() < 3:
			for sponsor in SPONSORS:
				if offers.size() >= 3:
					break
				_add_offer_if_available(offers, used_ids, sponsor as Dictionary, club_level)

		return offers.slice(0, 3)

	for family in target_families:
		_add_first_offer_from_family(offers, used_ids, str(family), club_level)
	if offers.size() < 3:
		for sponsor in SPONSORS:
			if offers.size() >= 3:
				break
			_add_offer_if_available(offers, used_ids, sponsor as Dictionary, club_level)
	return offers.slice(0, 3)


static func make_contract_copy(sponsor: Dictionary) -> Dictionary:
	var duration_type := str(sponsor.get("duration_type", ""))
	var duration_value := int(sponsor.get("duration_value", 0))
	return {
		"id": str(sponsor.get("id", "")),
		"name_key": str(sponsor.get("name", sponsor.get("name_key", ""))),
		"family": str(sponsor.get("family", "")),
		"logo": str(sponsor.get("logo", "")),
		"payment_type": str(sponsor.get("payment_type", "")),
		"payment_amount": int(sponsor.get("payment_amount", 0)),
		"duration_type": duration_type,
		"duration_value": duration_value,
		"remaining_matches": duration_value if duration_type == PAYMENT_PER_MATCH else 0,
		"remaining_seasons": duration_value if duration_type == PAYMENT_PER_SEASON else 0,
		"unlock_club_level": int(sponsor.get("unlock_club_level", UNLOCK_CLUB_LEVEL_LOCAL)),
		"bonus_type": str(sponsor.get("bonus_type", "")),
		"bonus_amount": int(sponsor.get("bonus_amount", 0)),
		"season_payment_paid": false,
	}


static func get_active_contract(save: Dictionary) -> Dictionary:
	if save.has(ACTIVE_CONTRACT_SAVE_KEY) and typeof(save[ACTIVE_CONTRACT_SAVE_KEY]) == TYPE_DICTIONARY:
		return (save[ACTIVE_CONTRACT_SAVE_KEY] as Dictionary).duplicate(true)
	return {}


static func _store_last_signed_from_contract(save: Dictionary, contract: Dictionary) -> void:
	var sponsor_id := str(contract.get("id", "")).strip_edges()
	if sponsor_id != "":
		save[LAST_SIGNED_SPONSOR_SAVE_KEY] = sponsor_id
		remember_sponsor_ids(save, [sponsor_id])


static func _is_contract_expired(contract: Dictionary) -> bool:
	var payment_type := str(contract.get("payment_type", ""))
	if payment_type == PAYMENT_PER_MATCH:
		return int(contract.get("remaining_matches", 0)) <= 0
	if payment_type == PAYMENT_PER_SEASON:
		return int(contract.get("remaining_seasons", 0)) <= 0
	return false


static func expire_active_contract_if_needed(save: Dictionary) -> bool:
	var contract := get_active_contract(save)
	if contract.is_empty() or not _is_contract_expired(contract):
		return false
	_store_last_signed_from_contract(save, contract)
	save[SPONSORS_UNLOCKED_SAVE_KEY] = true
	save[SPONSORS_EXPIRED_POPUP_PENDING_SAVE_KEY] = true
	save.erase(ACTIVE_CONTRACT_SAVE_KEY)
	return true


static func apply_sponsor_revenue_to_save(save: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	save["total_sponsors"] = int(save.get("total_sponsors", 0)) + amount
	save["total_recettes"] = int(save.get("total_recettes", 0)) + amount


static func apply_per_match_revenue_to_save(save: Dictionary) -> int:
	var contract := get_active_contract(save)
	if contract.is_empty():
		return 0
	if str(contract.get("payment_type", "")) != PAYMENT_PER_MATCH:
		return 0
	var remaining := int(contract.get("remaining_matches", 0))
	if remaining <= 0:
		expire_active_contract_if_needed(save)
		return 0
	var amount := int(contract.get("payment_amount", 0))
	apply_sponsor_revenue_to_save(save, amount)
	contract["remaining_matches"] = maxi(0, remaining - 1)
	if int(contract.get("remaining_matches", 0)) <= 0:
		_store_last_signed_from_contract(save, contract)
		save[SPONSORS_UNLOCKED_SAVE_KEY] = true
		save[SPONSORS_EXPIRED_POPUP_PENDING_SAVE_KEY] = true
		save.erase(ACTIVE_CONTRACT_SAVE_KEY)
	else:
		save[ACTIVE_CONTRACT_SAVE_KEY] = contract.duplicate(true)
	return maxi(0, amount)


static func advance_season_contract(save: Dictionary) -> bool:
	var contract := get_active_contract(save)
	if contract.is_empty():
		return false
	if str(contract.get("payment_type", "")) != PAYMENT_PER_SEASON:
		return expire_active_contract_if_needed(save)
	var remaining := int(contract.get("remaining_seasons", 0))
	contract["remaining_seasons"] = maxi(0, remaining - 1)
	if int(contract.get("remaining_seasons", 0)) <= 0:
		_store_last_signed_from_contract(save, contract)
		save[SPONSORS_UNLOCKED_SAVE_KEY] = true
		save[SPONSORS_EXPIRED_POPUP_PENDING_SAVE_KEY] = true
		save.erase(ACTIVE_CONTRACT_SAVE_KEY)
	else:
		save[ACTIVE_CONTRACT_SAVE_KEY] = contract.duplicate(true)
	return true
