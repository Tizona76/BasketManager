
static func clamp_pop(pop: int) -> int:
	return clampi(pop, 0, 100)

static func apply_popularity_after_match(pop: int, resultat: String) -> int:
	if resultat == "Victoire":
		pop += 3
	elif resultat == "Défaite":
		pop -= 2
	elif resultat == "Match Nul":
		pop += 1
	pop = clamp_pop(pop)

	if resultat == "Victoire":
		pop = clamp_pop(pop + 5)
	elif resultat == "Défaite":
		pop = clamp_pop(pop - 5)

	return pop

static func compute_pop_rate(pop: int) -> float:
	return clampf(float(pop) / 100.0, 0.3, 1.0)
