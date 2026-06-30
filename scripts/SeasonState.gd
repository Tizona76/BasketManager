extends Node

# Équivalent des variables globales Python (menu_saison)

var zone_selectionnee_saison: String = ""  # "", "classement", "statistiques", "calendrier", "mercato", "missions"

var popup_bienvenue_saison_deja_vu: bool = false

var decalage_scroll_calendrier: int = 0
var hauteur_contenu_calendrier: int = 0

var matchs_joues: int = 0
var total_matchs_saison: int = 22

var club_level: int = 1
