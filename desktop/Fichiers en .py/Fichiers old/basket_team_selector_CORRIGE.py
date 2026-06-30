


import pygame
import sys
import os
import random
import math

pygame.init()

class Confetti:
    def __init__(self, largeur, hauteur):
        self.largeur = largeur
        self.hauteur = hauteur
        self.x = random.randint(0, largeur)
        self.y = random.randint(-100, 0)
        self.size = random.randint(5, 10)
        self.color = (random.randint(150, 255), random.randint(50, 255), random.randint(50, 255))
        self.speed = random.uniform(1, 4)

    def update(self):
        self.y += self.speed
        if self.y > self.hauteur:
            self.x = random.randint(0, self.largeur)
            self.y = random.randint(-100, 0)

    def draw(self, surface):
        rect = pygame.Rect(self.x, self.y, self.size, self.size)
        pygame.draw.rect(surface, self.color, rect)

# --- Fenêtre & couleurs ---
LARGEUR, HAUTEUR = 1000, 700
FENETRE = pygame.display.set_mode((LARGEUR, HAUTEUR))
pygame.display.set_caption("Mon jeu de basket")

FONT = pygame.font.SysFont("comicsansms", 24)
POLICE_TITRE = pygame.font.SysFont("comicsansms", 36, bold=True)
POLICE_GRANDE = pygame.font.SysFont("comicsansms", 28, bold=True)
POLICE_MOYENNE = pygame.font.SysFont("comicsansms", 22)
POLICE_MOYENNE_BOLD = pygame.font.SysFont("comicsansms", 22, bold=True)
POLICE_PETITE = pygame.font.SysFont("comicsansms", 18)
POLICE_CLASSEMENT = pygame.font.SysFont("comicsansms", 20)

FONT_STATS = pygame.font.SysFont("comicsansms", 20)
POLICE_TITRE_STATS = pygame.font.SysFont("comicsansms", 24, bold=True)



NOIR = (0, 0, 0)
BLANC = (255, 255, 255)
BLEU = (0, 102, 204)
ROUGE = (200, 0, 0)
ORANGE_CLAIR = (255, 220, 180)
VERT_CLAIR = (180, 255, 180)

font_bold_italic = pygame.font.SysFont("arial", 24, bold=True, italic=True) # pour Classification
FONT_FICHE = pygame.font.SysFont("comicsansms", 18)  # par exemple taille 16 au lieu de 24
FONT_NOM = pygame.font.SysFont("comicsansms", 20, bold=True) # pour le nom dans la composition de l'équipe
COULEUR_NOM = (0, 51, 102)  # un bleu foncé par exemple


equipe_sauvegardee = set()
statistiques_saison = []
saison_actuelle = 1
total_matchs_saison = 22
saison_actuelle = 1
total_matchs_saison = 22  # 11 équipes adverses × 2 (aller-retour)
AGE_RETRAITE = 36  # Tu peux changer cette valeur facilement
mercato_ouvert = False
mercato_matchs_restants = 0
message_blocage = ""
temps_blocage = 0
# Valeur popularité de l'équipe de 0 à 100 (ex: commence à 50)
popularite = 50

total_recettes = 0






COUT_ENTRETIEN_ANNUEL_NIVEAU1 = 75500
valeur_formatee = f"{COUT_ENTRETIEN_ANNUEL_NIVEAU1:,}".replace(",", ".") + " €"



noms_equipes_possibles = [
    "Tigres", "Aigles", "Panthères", "Lynx", "Guépards", "Faucons", "Lions", "Grizzlis", "Ours", "Dauphins", "Toros"
]


saisies_billet = ["", "", ""]  # Pour Catégorie A, B, C
saisies_places = ["", "", ""]  # Nouveau : pour le nombre de places

champs_billet_rects = []       # Rectangles cliquables pour les prix
champs_places_rects = []       # Rectangles cliquables pour les places

champ_actif_billet = None      # Champ actif pour les prix
champ_actif_places = None      # Champ actif pour les places

saisies_prix_boutique = ["", "", "", ""]  # Pour les 4 produits
champs_prix_boutique = []
champ_actif_prix_boutique = None
total_billetterie = 0
total_boutique = 0

decalage_scroll = 0

import time
clignotement_vitesse = 700  # en millisecondes (réglable facilement)

sponsor_selectionne = None
bouton_confirmer_sponsor = pygame.Rect(700, 630, 180, 40)
sponsors_boutons = []
recettes_sponsors = 0
joueurs_mercato = []
resultats_matchs_complets = []



sponsors_montants = {
    "Gatorade": 860000,
    "Nike": 900000,
    "Red Bull": 860000,
    "Adidas": 770000
}
sponsors_signes = []  # Pour journaliser les sponsors signés



stock_boutique = {
    "Casquettes": 1200,
    "Écharpes": 1200,
    "T-shirts": 1200,
    "Drapeaux": 1200
}



ballon_rect = None
ballon_y = HAUTEUR // 2
ballon_vitesse = -3  # vitesse verticale initiale (vers le haut)
ballon_hauteur_min = HAUTEUR // 2 - 30  # limite haute du rebond
ballon_hauteur_max = HAUTEUR // 2 + 30  # limite basse du rebond




# --- Images & boutons ---
ballon_img = pygame.Surface((100, 100), pygame.SRCALPHA)
pygame.draw.circle(ballon_img, (255, 165, 0), (25, 25), 25)


bouton_retour = pygame.Rect(20, 630, 100, 40)
bouton_evolution_stade = pygame.Rect(LARGEUR // 2 + 130, 560, 180, 50)

bouton_demarrer_match = pygame.Rect(LARGEUR // 2 - 100, 500, 200, 50)

animation_terrain_debut = None
temps_debut_animation_terrain = None
ANIMATION_TERRAIN_DURATION = 7000  # en millisecondes = 7 secondes

casquette_img = pygame.image.load("images/casquette.png").convert_alpha()
casquette_img = pygame.transform.scale(casquette_img, (80, 80))  # Adapter la taille selon le besoin

echarpe_img = pygame.image.load("images/echarpe.png").convert_alpha()
echarpe_img = pygame.transform.scale(echarpe_img, (80, 80))  # Adapter la taille selon le besoin

drapeau_img = pygame.image.load("images/drapeau.png").convert_alpha()
drapeau_img = pygame.transform.scale(drapeau_img, (80, 80))  # Adapter la taille selon le besoin
tshirt_img = pygame.image.load("images/tshirt.png").convert_alpha()
tshirt_img = pygame.transform.scale(tshirt_img, (80, 90))  # Adapter la taille selon le besoin

demi_terrain_img = pygame.image.load("images/demi_terrain.png").convert_alpha()
demi_terrain_img = pygame.transform.scale(demi_terrain_img, (500, 575))

homme_affaire_img = pygame.image.load("images/homme_affaire.png").convert_alpha()
homme_affaire_img = pygame.transform.scale(homme_affaire_img, (75, 75))  # ajuste si besoin

image_stade_img = pygame.image.load("images/stade.png").convert_alpha()
image_stade_img = pygame.transform.scale(image_stade_img, (LARGEUR, HAUTEUR))

image_finance = pygame.image.load("images/finance.png").convert_alpha()
image_finance = pygame.transform.scale(image_finance, (88, 88))  # ajuste la taille si besoin

image_sponsors = pygame.image.load("images/sponsors.png").convert_alpha()
image_sponsors = pygame.transform.scale(image_sponsors, (84, 84))  # ajuste la taille si besoin

image_stadebasket = pygame.image.load("images/stadebasket.png").convert_alpha()
image_stadebasket = pygame.transform.scale(image_stadebasket, (70, 70))  # ajuste la taille si besoin

image_calendrier_gestion = pygame.image.load("images/calendrier_gestion.png").convert_alpha()
image_calendrier_gestion = pygame.transform.scale(image_calendrier_gestion, (77, 77))  # ajuste la taille si besoin

fond_sponsors_img = pygame.image.load("images/fond_sponsors.png").convert_alpha()
fond_sponsors_img = pygame.transform.scale(fond_sponsors_img, (LARGEUR, HAUTEUR))
fond_sponsors_img.set_alpha(90)  # 🔆 très pâle

image_joueurs = pygame.image.load("images/joueurs.png").convert_alpha()
image_joueurs = pygame.transform.scale(image_joueurs, (LARGEUR, HAUTEUR))

joueurs2_img = pygame.image.load("images/joueurs2.png").convert_alpha()
joueurs2_img = pygame.transform.scale(joueurs2_img, (70, 70))  

staff_img = pygame.image.load("images/staff.png").convert_alpha()
staff_img = pygame.transform.scale(staff_img, (71, 71))  

fond_saison_img = pygame.image.load("images/fond_saison.png").convert_alpha()
fond_saison_img = pygame.transform.scale(fond_saison_img, (LARGEUR, HAUTEUR))

fleche_img = pygame.image.load("images/fleche.png").convert_alpha()
fleche_img = pygame.transform.scale(fleche_img, (60, 60))
fleche_base_y = HAUTEUR // 2 - 70  # hauteur base
fleche_decalage = 0


fond_fond_compositionequipe_img = pygame.image.load("images/fond_compositionequipe.png").convert_alpha()
fond_fond_compositionequipe_img = pygame.transform.scale(fond_fond_compositionequipe_img, (LARGEUR, HAUTEUR))

fond_fiche_img = pygame.image.load("images/fiche.png").convert_alpha()
fond_fiche_img = pygame.transform.scale(fond_fiche_img, (200, 250))  # même taille que fiche_largeur/hauteur

terrain3 = pygame.image.load("images/terrain3.png").convert_alpha()
terrain3 = pygame.transform.scale(terrain3, (LARGEUR, HAUTEUR))

fond_resultat = pygame.image.load("images/fond_resultat.png").convert_alpha()
fond_resultat = pygame.transform.scale(fond_resultat, (600, 150))  








# ------------------ Données ------------------

joueurs = [
    {"nom": "Léa", "poste": "Meneur", "age": 22, "salaire": "80 000 €", "precision": 0.85, "vitesse": 90, "force": 60, "defense": 70, "endurance": 80},
    {"nom": "Maxime", "poste": "Ailier", "age": 24, "salaire": "95 000 €", "precision": 0.80, "vitesse": 85, "force": 70, "defense": 65, "endurance": 75},
    {"nom": "Sofiane", "poste": "Pivot", "age": 27, "salaire": "120 000 €", "precision": 0.75, "vitesse": 70, "force": 90, "defense": 80, "endurance": 70},
    {"nom": "Camille", "poste": "Arrière", "age": 23, "salaire": "85 000 €", "precision": 0.78, "vitesse": 80, "force": 65, "defense": 75, "endurance": 85},
    {"nom": "Noah", "poste": "Pivot", "age": 26, "salaire": "115 000 €", "precision": 0.70, "vitesse": 60, "force": 95, "defense": 85, "endurance": 65},
    {"nom": "Emma", "poste": "Meneur", "age": 21, "salaire": "75 000 €", "precision": 0.82, "vitesse": 88, "force": 55, "defense": 72, "endurance": 78},
    {"nom": "Lucas", "poste": "Ailier", "age": 25, "salaire": "90 000 €", "precision": 0.76, "vitesse": 82, "force": 68, "defense": 68, "endurance": 80},
    {"nom": "Jade", "poste": "Arrière", "age": 22, "salaire": "85 000 €", "precision": 0.74, "vitesse": 75, "force": 60, "defense": 70, "endurance": 82},
    {"nom": "Tom", "poste": "Pivot", "age": 28, "salaire": "130 000 €", "precision": 0.72, "vitesse": 65, "force": 92, "defense": 88, "endurance": 60},
    {"nom": "Lina", "poste": "Meneur", "age": 20, "salaire": "70 000 €", "precision": 0.79, "vitesse": 87, "force": 58, "defense": 74, "endurance": 76},
    {"nom": "Julien", "poste": "Ailier", "age": 29, "salaire": "100 000 €", "precision": 0.77, "vitesse": 80, "force": 66, "defense": 69, "endurance": 79},
    {"nom": "Clara", "poste": "Arrière", "age": 30, "salaire": "110 000 €", "precision": 0.73, "vitesse": 72, "force": 64, "defense": 71, "endurance": 81},
]

# Fonction pour calculer la pondération d'un joueur
def calculer_pondération(joueur):
    pondération = (joueur["precision"] * 100) * 0.25 + joueur["vitesse"] * 0.25 + joueur["force"] * 0.2 + joueur["defense"] * 0.15 + joueur["endurance"] * 0.15
    return pondération

def mettre_a_jour_joueurs_equipe():
    global joueurs
    joueurs = [j for j in joueurs if j["age"] < AGE_RETRAITE] 
    
    for joueur in joueurs:
        joueur["age"] += 1

        if joueur["age"] >= 30:
            joueur["pondération"] *= 0.97
        elif joueur["age"] <= 23:
            joueur["pondération"] *= 1.03

        joueur["pondération"] = round(joueur["pondération"], 2)

        salaire = int(70000 + (joueur["pondération"] * 500))
        salaire = max(70000, min(salaire, 130000))
        joueur["salaire"] = f"{salaire:,}".replace(',', '.') + " €"
        

def mettre_a_jour_joueurs_adverses():
    for nom_equipe in list(equipes_adverses.keys()):
         equipe = equipes_adverses[nom_equipe]
         equipe = [j for j in equipe if j["age"] < AGE_RETRAITE]
         if not equipe:
             del equipes_adverses[nom_equipe]
         else:
             equipes_adverses[nom_equipe] = equipe

   
    for equipe in equipes_adverses.values():
        for joueur in equipe:
            joueur["age"] += 1  # Vieillissement

            # Régression naturelle des stats avec l'âge
            if joueur["age"] >= 28:
                joueur["vitesse"] = max(50, joueur["vitesse"] - random.randint(1, 3))
                joueur["endurance"] = max(50, joueur["endurance"] - random.randint(1, 2))
                joueur["precision"] = round(max(0.60, joueur["precision"] - random.uniform(0.01, 0.03)), 2)

            # Mise à jour de la pondération et salaire
            joueur["pondération"] = calculer_pondération(joueur)
            salaire = int(70000 + joueur["pondération"] * 500)
            salaire = max(70000, min(salaire, 130000))
            joueur["salaire"] = f"{salaire:,}".replace(",", ".") + " €"



    
# Fonction pour afficher la pondération de tous les joueurs
def afficher_pondérations():
    for joueur in joueurs:
        pondération = calculer_pondération(joueur)
        print(f"{joueur['nom']} (Poste: {joueur['poste']}) - Pondération: {pondération:.2f}")
# Afficher les pondérations après ajout
afficher_pondérations()

def salaire_str_vers_int(s):
    return int(s.replace(' €', '').replace('.', '').replace(' ', ''))
def int_vers_salaire_str(val):
    return f"{val:,}".replace(',', '.') + " €"




SELECTIONS_MAX = 12
equipe = set()
poste_filtre = "Tous"
zone_selectionnee = ""
CAPACITE_STADE_NIVEAU1 = 5000  # valeur actuelle affichée dans l'onglet Terrain



# --- Zones interactives pour le stade & saison ---
titres_stade = ["Terrain", "Billetterie", "Boutique", "Parkings"]
rects_stade = [pygame.Rect(100 + i * 200, 50, 160, 40) for i in range(4)]

titres_saison = ["Classement", "Statistiques", "Calendrier", "Récompenses", "Mercato"]
rects_saison = [pygame.Rect(67 + i * 170, 50, 160, 39) for i in range(len(titres_saison))]
zone_selectionnee_saison = ""


for joueur in joueurs:
    pond = calculer_pondération(joueur)
    joueur["pondération"] = pond
    salaire_int = int(70000 + (pond * 500))
    salaire_int = max(70000, min(salaire_int, 130000))  # Limiter entre 70k et 130k
    joueur['salaire'] = f"{salaire_int:,}".replace(',', '.') + " €"


def estimer_valeur_joueur(joueur):
    age = joueur["age"]
    pond = joueur["pondération"]

    if age < 23:
        facteur_age = 0.85
    elif age <= 29:
        facteur_age = 1.2
    else:
        facteur_age = 0.75

    valeur = int(pond * 10000 * facteur_age)
    return max(50000, min(valeur, 300000))  # Valeur marchande bornée



def generer_equipe_adverse():
    nom_equipe = random.choice(noms_equipes_possibles)
    postes = ["Meneur", "Ailier", "Pivot", "Arrière"]
    equipe = []
    for i in range(8):
        precision = round(random.uniform(0.65, 0.90), 2)
        vitesse = random.randint(60, 90)
        force = random.randint(55, 95)
        defense = random.randint(60, 90)
        endurance = random.randint(65, 90)

        # Calcul de la pondération avec ces caractéristiques
        joueur_temp = {
            "precision": precision,
            "vitesse": vitesse,
            "force": force,
            "defense": defense,
            "endurance": endurance
        }
        pond = calculer_pondération(joueur_temp)

        # Calcul du salaire basé sur la pondération
        salaire = int(70000 + (pond * 500))
        salaire = max(70000, min(salaire, 130000))

        joueur = {
            "nom": f"{nom_equipe}_Joueur{i+1}",
            "poste": random.choice(postes),
            "age": random.randint(20, 30),
            "salaire": f"{salaire} €",  # Utilise salaire calculé ici
            "precision": precision,
            "vitesse": vitesse,
            "force": force,
            "defense": defense,
            "endurance": endurance,
            "pondération": pond
        }

        equipe.append(joueur)

    return equipe, nom_equipe


def generer_equipe_adverse_depuis_nom(nom_equipe_adverse):
    postes = ["Meneur", "Ailier", "Pivot", "Arrière"]
    equipe = []
    for i in range(8):
        precision = round(random.uniform(0.65, 0.90), 2)
        vitesse = random.randint(60, 90)
        force = random.randint(55, 95)
        defense = random.randint(60, 90)
        endurance = random.randint(65, 90)

        joueur_temp = {
            "precision": precision,
            "vitesse": vitesse,
            "force": force,
            "defense": defense,
            "endurance": endurance
        }
        pond = calculer_pondération(joueur_temp)

        salaire = int(70000 + (pond * 500))
        salaire = max(70000, min(salaire, 130000))

        joueur = {
            "nom": f"{nom_equipe_adverse}_Joueur{i+1}",
            "poste": random.choice(postes),
            "age": random.randint(20, 30),
            "salaire": f"{salaire} €",
            "precision": precision,
            "vitesse": vitesse,
            "force": force,
            "defense": defense,
            "endurance": endurance,
            "pondération": pond
        }

        equipe.append(joueur)

    return equipe, nom_equipe_adverse


def generer_joueurs_mercato(nb_joueurs=6):
    global joueurs_mercato
    joueurs_mercato = []
    postes = ["Meneur", "Ailier", "Pivot", "Arrière"]

    for _ in range(nb_joueurs):
        age = random.randint(18, 34)
        precision = round(random.uniform(0.65, 0.90), 2)
        vitesse = random.randint(60, 90)
        force = random.randint(55, 95)
        defense = random.randint(60, 90)
        endurance = random.randint(65, 90)

        joueur = {
            "nom": f"Joueur_{random.randint(1000, 9999)}",
            "poste": random.choice(postes),
            "age": age,
            "precision": precision,
            "vitesse": vitesse,
            "force": force,
            "defense": defense,
            "endurance": endurance
        }
        joueur["pondération"] = round(calculer_pondération(joueur), 2)
        salaire = int(70000 + joueur["pondération"] * 500)
        joueur["salaire"] = f"{max(70000, min(salaire, 130000)):,}".replace(",", ".") + " €"
        joueurs_mercato.append(joueur)
        

def dessiner_mercato_tableau():  
    global boutons_achat
    global mercato_ouvert, mercato_matchs_restants


    matchs_joues = len(historique_matchs)

    if not mercato_ouvert:
        matchs_restant = 11 - matchs_joues if matchs_joues < 11 else 0
        largeur_fond, hauteur_fond = 520, 240
        x_fond = LARGEUR // 2 - largeur_fond // 2
        y_fond = 175
        fond_msg = pygame.Rect(x_fond, y_fond, largeur_fond, hauteur_fond)
        pygame.draw.rect(FENETRE, (255, 255, 255), fond_msg)
        pygame.draw.rect(FENETRE, NOIR, fond_msg, 2)
        message1 = f"Mercato fermé. Ouverture dans {matchs_restant} match(s)." if matchs_joues < 11 else "Mercato fermé jusqu'à la fin de saison."
        message2 = "Keep playing !"
        texte1 = FONT.render(message1, True, ROUGE)
        texte2 = FONT.render(message2, True, ROUGE)
        texte1_rect = texte1.get_rect(center=(fond_msg.centerx, fond_msg.centery - 15))
        texte2_rect = texte2.get_rect(center=(fond_msg.centerx, fond_msg.centery + 15))
        FENETRE.blit(texte1, texte1_rect)
        FENETRE.blit(texte2, texte2_rect)
        return

    # Fond blanc du tableau
    hauteur_tableau = len(joueurs_mercato) * 45 + 100
    rect_fond = pygame.Rect(173, 115, 780, hauteur_tableau)
    pygame.draw.rect(FENETRE, BLANC, rect_fond)
    pygame.draw.rect(FENETRE, NOIR, rect_fond, 2)

    titre = POLICE_GRANDE.render("Marché des Transferts", True, NOIR)
    FENETRE.blit(titre, (LARGEUR // 2 - titre.get_width() // 2, 100))

    message1 = "Vous avez 3 matchs pour recruter !" if mercato_matchs_restants > 0 else "Dernière chance de recruter !"
    message2 = "Max. 3 joueurs"

    texte1 = FONT.render(message1, True, NOIR)
    texte2 = FONT.render(message2, True, NOIR)

    FENETRE.blit(texte1, (LARGEUR // 2 - texte1.get_width() // 2, 130))
    FENETRE.blit(texte2, (LARGEUR // 2 - texte2.get_width() // 2, 155))

    entetes = ["Nom", "Poste", "Âge", "Pond.", "Salaire"]
    x_depart, y_depart = 190, 195
    largeur_colonnes = [175, 145, 60, 110, 120]

    # Dessiner les en-têtes centrés
    x = x_depart
    for i, entete in enumerate(entetes):
        texte = POLICE_TITRE_STATS.render(entete, True, NOIR)
        texte_rect = texte.get_rect(center=(x + largeur_colonnes[i] // 2, y_depart + 10))
        FENETRE.blit(texte, texte_rect)
        x += largeur_colonnes[i]

    boutons_achat = []
    y = y_depart + 40

    for joueur in joueurs_mercato:
        x = x_depart
        infos = [
            joueur["nom"], joueur["poste"], str(joueur["age"]),
            f"{joueur['pondération']:.2f}", joueur["salaire"]
        ]
        for i, info in enumerate(infos):
            texte = FONT.render(info, True, NOIR)
            FENETRE.blit(texte, (x + 8, y))
            x += largeur_colonnes[i]

        bouton = pygame.Rect(x + 30, y, 105, 30)
        pygame.draw.rect(FENETRE, (0, 128, 0), bouton)
        pygame.draw.rect(FENETRE, NOIR, bouton, 2)
        texte_acheter = FONT.render("Acheter", True, BLANC)
        texte_rect = texte_acheter.get_rect(center=bouton.center)
        FENETRE.blit(texte_acheter, texte_rect)
        boutons_achat.append((bouton, joueur))

        y += 40


def simuler_match():
    global equipe, nom_equipe, prochain_adversaire
    global total_billetterie, total_boutique

    if not equipe:
        print("⚠️ Aucune équipe sélectionnée. Impossible de simuler le match.")
        return {
            "score_equipe": 0,
            "score_adverse": 0,
            "resultat": "Erreur : pas d'équipe",
            "mvp_equipe": {"nom": "N/A"},
            "mvp_match": {"nom": "N/A"},
            "adversaire": "???"
        }

    equipe_adverse, nom_adverse = generer_equipe_adverse_depuis_nom(prochain_adversaire)

    pondere_joueurs = [joueurs[i]["pondération"] for i in equipe if "pondération" in joueurs[i]]
    moyenne_pond_equipe = sum(pondere_joueurs) / len(pondere_joueurs) if pondere_joueurs else 70
    moyenne_pond_adverse = sum(j["pondération"] for j in equipe_adverse) / len(equipe_adverse)

    base_score = random.randint(70, 90)
    diff_pond = moyenne_pond_equipe - moyenne_pond_adverse
    score_equipe = max(50, min(int(base_score + diff_pond * 25 + random.randint(-5, 5)), 120))
    score_adverse = max(50, min(int(base_score - diff_pond * 25 + random.randint(-5, 5)), 120))

    score_joueur_equipe = [(joueurs[i], calculer_pondération(joueurs[i]) + random.uniform(-10, 10)) for i in equipe]
    score_joueur_adverse = [(j, calculer_pondération(j) + random.uniform(-10, 10)) for j in equipe_adverse]

    total_equipe = sum(s for _, s in score_joueur_equipe)
    total_adverse = sum(s for _, s in score_joueur_adverse)
    score_final_equipe = int(total_equipe // 10)
    score_final_adverse = int(total_adverse // 10)

    meilleur_joueur_equipe, _ = max(score_joueur_equipe, key=lambda x: x[1])
    meilleur_joueur_match, _ = max(score_joueur_equipe + score_joueur_adverse, key=lambda x: x[1])

    resultat = "Victoire" if score_final_equipe > score_final_adverse else "Défaite" if score_final_equipe < score_final_adverse else "Match Nul"

    mettre_a_jour_popularite(resultat)

    global popularite
    if resultat == "Victoire":
        popularite = min(popularite + 5, 100)
    elif resultat == "Défaite":
        popularite = max(popularite - 5, 0)

    est_domicile = len(historique_matchs) % 2 == 0

    if est_domicile:
        taux_pop = max(0.3, min(popularite / 100, 1))

        try:
            prix_a = int(saisies_billet[0])
            prix_b = int(saisies_billet[1])
            prix_c = int(saisies_billet[2])
        except:
            prix_a = prix_b = prix_c = 0
        places_par_cat = CAPACITE_STADE_NIVEAU1 // 3
        total_previsionnel_billetterie = (prix_a + prix_b + prix_c) * places_par_cat
        recettes_billetterie = int(total_previsionnel_billetterie * taux_pop)

        try:
            prix_casquette = int(saisies_prix_boutique[0])
            prix_echarpe   = int(saisies_prix_boutique[1])
            prix_tshirt    = int(saisies_prix_boutique[2])
            prix_drapeau   = int(saisies_prix_boutique[3])
        except:
            prix_casquette = prix_echarpe = prix_tshirt = prix_drapeau = 0
        stock_total = sum(stock_boutique.values())
        produits_par_type = stock_total // 4
        total_previsionnel_boutique = produits_par_type * (prix_casquette + prix_echarpe + prix_tshirt + prix_drapeau)
        recettes_boutique = int(total_previsionnel_boutique * taux_pop)

        total_billetterie += recettes_billetterie
        total_boutique += recettes_boutique
    else:
        recettes_billetterie = 0
        recettes_boutique = 0

    mettre_a_jour_classement(nom_equipe, nom_adverse, score_final_equipe, score_final_adverse)

    match_info = {
        "texte": f"{nom_equipe} {score_final_equipe} - {score_final_adverse} {nom_adverse}|{resultat}",
        "domicile": est_domicile,
        "recette_billetterie": recettes_billetterie,
        "recette_boutique": recettes_boutique
    }
    historique_matchs.append(match_info)

    candidats = [e for e in noms_equipes_possibles if e != nom_adverse and e != nom_equipe]
    prochain_adversaire = random.choice(candidats) if candidats else nom_adverse

    statistiques_saison.append({
        "tirs_2_pts": [random.randint(55, 70), random.randint(55, 70)],
        "tirs_3_pts": [random.randint(30, 45), random.randint(30, 45)],
        "passes": [random.randint(10, 18), random.randint(10, 18)],
        "fautes": [random.randint(10, 20), random.randint(10, 20)],
        "mvp_equipe": {
            "nom": meilleur_joueur_equipe["nom"],
            "points": random.randint(12, 28),
            "passes": random.randint(4, 10),
            "tirs_2_pts": [random.randint(20, 35), random.randint(30, 50)],
            "tirs_3_pts": [random.randint(10, 25), random.randint(20, 35)]
        },
        "mvp_match": {
            "nom": meilleur_joueur_match["nom"],
            "points": random.randint(20, 35),
            "passes": random.randint(5, 12),
            "tirs_2_pts": [random.randint(25, 40), random.randint(35, 55)],
            "tirs_3_pts": [random.randint(15, 30), random.randint(25, 40)]
        }
    })

    resultats_matchs_complets.append({
        "score": f"{nom_equipe} {score_final_equipe} - {score_final_adverse} {nom_adverse}",
        "resultat": resultat,
        "mvp_match": {
            "nom": meilleur_joueur_match["nom"]
        }
    })

    global mercato_ouvert, mercato_matchs_restants
    if len(historique_matchs) == 11:
        mercato_ouvert = True
        mercato_matchs_restants = 3
    elif mercato_ouvert and mercato_matchs_restants > 0:
        mercato_matchs_restants -= 1
        if mercato_matchs_restants == 0:
            mercato_ouvert = False

    return {
        "score_equipe": score_final_equipe,
        "score_adverse": score_final_adverse,
        "mvp_equipe": meilleur_joueur_equipe,
        "mvp_match": meilleur_joueur_match,
        "resultat": resultat,
        "adversaire": nom_adverse,
        "stats": statistiques_saison[-1]
    }


def mettre_a_jour_popularite(resultat):
    global popularite

    if resultat == "Victoire":
        popularite += 3
    elif resultat == "Défaite":
        popularite -= 2
    elif resultat == "Match Nul":
        popularite += 1

    # Bornes de sécurité
    popularite = max(0, min(popularite, 100))


        

def saison_terminee():
    global saison_actuelle, historique_matchs, statistiques_saison, prochain_adversaire

    saison_actuelle += 1
    historique_matchs.clear()
    statistiques_saison.clear()

    # Réinitialise les classements
    reinitialiser_statistiques()

    # Tirer un nouvel adversaire pour démarrer la nouvelle saison
    candidats = [e for e in noms_equipes_possibles if e != nom_equipe]
    prochain_adversaire = random.choice(candidats)

    mettre_a_jour_joueurs_equipe()  # ← Ajout ici

    print(f"🆕 Début de la saison {saison_actuelle}")



def initialiser_classement():
    global classement, nom_equipe  # Assure-toi que nom_equipe est global ici
    classement = [
        {"nom": nom_equipe if nom_equipe.strip() else "Votre équipe", "victoires": 0, "defaites": 0, "matchs_nuls": 0, "points": 0}
    ]
    for nom in noms_equipes_possibles:
       if nom != nom_equipe:
           classement.append({
               "nom": nom,
               "victoires": 0,
               "defaites": 0,
               "matchs_nuls": 0,
               "points": 0
        })

    # Tri du classement
    classement.sort(key=lambda x: (-x["points"], -x["victoires"]))



def mettre_a_jour_classement(equipe1, equipe2, score1, score2):
    global classement

    # Ajoute les équipes si elles ne sont pas déjà dans le classement
    for nom in [equipe1, equipe2]:
        if not any(e["nom"] == nom for e in classement):
            classement.append({"nom": nom, "victoires": 0, "defaites": 0, "matchs_nuls": 0, "points": 0})

    e1 = next(e for e in classement if e["nom"] == equipe1)
    e2 = next(e for e in classement if e["nom"] == equipe2)

    # Mise à jour des résultats
    if score1 > score2:
        e1["victoires"] += 1
        e1["points"] += 3
        e2["defaites"] += 1
    elif score1 < score2:
        e2["victoires"] += 1
        e2["points"] += 3
        e1["defaites"] += 1
    else:
        e1["matchs_nuls"] += 1
        e2["matchs_nuls"] += 1
        e1["points"] += 1
        e2["points"] += 1

    autres_equipes = [e for e in classement if e["nom"] != equipe1 and e["nom"] != equipe2]
    
    for i in range(0, len(autres_equipes), 2):  # On prend les adversaires deux par deux
        if i + 1 < len(autres_equipes):  # Vérifie qu'il y a bien deux équipes à comparer
            e1_adversaire = autres_equipes[i]
            e2_adversaire = autres_equipes[i + 1]

            # Décider du type de match (victoire/défaite ou match nul)
            match_resultat = random.choice(['victoire', 'nul'])

            if match_resultat == 'victoire':
                # Choisir l'équipe gagnante de manière aléatoire
                score1_adversaire = random.randint(50, 100)
                score2_adversaire = random.randint(50, 100)

                if score1_adversaire > score2_adversaire:
                    e1_adversaire["victoires"] += 1
                    e1_adversaire["points"] += 3
                    e2_adversaire["defaites"] += 1
                else:
                    e2_adversaire["victoires"] += 1
                    e2_adversaire["points"] += 3
                    e1_adversaire["defaites"] += 1
            else:
                # En cas de match nul, les deux équipes obtiennent un point
                e1_adversaire["matchs_nuls"] += 1
                e2_adversaire["matchs_nuls"] += 1
                e1_adversaire["points"] += 1
                e2_adversaire["points"] += 1

    classement.sort(key=lambda x: (-x["points"], -x["victoires"]))

# --- Dessin de la billeterie ---
def dessiner_billetterie():
    global champs_billet_rects, champs_places_rects
    categories = ["Catégorie A", "Catégorie B", "Catégorie C"]
    champs_billet_rects.clear()
    champs_places_rects.clear()

    x_cat = LARGEUR // 2 - 180
    x_prix = LARGEUR // 2
    x_places = LARGEUR // 2 + 110
    
    # 🔳 Encadré pour la capacité actuelle
    ORANGE_CLAIR = (255, 220, 180)
    rect_capacite = pygame.Rect(x_cat, 185, 320, 35)
    pygame.draw.rect(FENETRE, ORANGE_CLAIR, rect_capacite)
    pygame.draw.rect(FENETRE, NOIR, rect_capacite, 2)
    texte_capacite = FONT.render(f"Capacité max : {CAPACITE_STADE_NIVEAU1} places", True, NOIR)
    FENETRE.blit(texte_capacite, (rect_capacite.x + 10, rect_capacite.y + 0))



    # 🧾 Titres des colonnes
    titre_prix = FONT.render("Prix (€)", True, NOIR)
    titre_places = FONT.render("Nbr places", True, NOIR)
    FENETRE.blit(titre_prix, (x_prix + 10, 230))
    FENETRE.blit(titre_places, (x_places + 5, 230))

    total_recette = 0
    total_places = 0

    for i, cat in enumerate(categories):
        y = 260 + i * 70

        # Catégorie
        rect_cat = pygame.Rect(x_cat, y, 160, 50)
        pygame.draw.rect(FENETRE, BLEU, rect_cat)
        pygame.draw.rect(FENETRE, NOIR, rect_cat, 2)
        txt = FONT.render(cat, True, BLANC)
        FENETRE.blit(txt, txt.get_rect(center=rect_cat.center))

        # Prix
        rect_prix = pygame.Rect(x_prix, y, 80, 50)
        pygame.draw.rect(FENETRE, BLANC, rect_prix)
        pygame.draw.rect(FENETRE, NOIR, rect_prix, 2)
        texte_prix = saisies_billet[i] + ("|" if champ_actif_billet == i else "")
        FENETRE.blit(FONT.render(texte_prix, True, NOIR), (rect_prix.x + 5, rect_prix.y + 10))
        champs_billet_rects.append(rect_prix)

        # Places
        rect_places = pygame.Rect(x_places, y, 95, 50)
        pygame.draw.rect(FENETRE, BLANC, rect_places)
        pygame.draw.rect(FENETRE, NOIR, rect_places, 2)
        texte_places = saisies_places[i] + ("|" if champ_actif_places == i else "")
        FENETRE.blit(FONT.render(texte_places, True, NOIR), (rect_places.x + 5, rect_places.y + 10))
        champs_places_rects.append(rect_places)

        # ➕ Calculs
        if est_nombre(saisies_billet[i]) and est_nombre(saisies_places[i]):
            total_recette += int(saisies_billet[i]) * int(saisies_places[i])
            total_places += int(saisies_places[i])

    # 🟧 Total recette
    rect_total_recette = pygame.Rect(x_prix - 140, 560, 365, 42)
    pygame.draw.rect(FENETRE, (255, 220, 180), rect_total_recette)
    pygame.draw.rect(FENETRE, NOIR, rect_total_recette, 2)
    texte_total = FONT.render(f"Total prévisionnel : {total_recette:,}".replace(",", ".") + " €", True, NOIR)
    FENETRE.blit(texte_total, (rect_total_recette.x + 5, rect_total_recette.y + 5))

    global total_billetterie
    total_billetterie = total_recette

    

    # 🧮 Total places
    texte_total_places = FONT.render(f"Total {total_places} places", True, NOIR)
    FENETRE.blit(texte_total_places, (x_places - 50, 465))

    # ❗ On ne dessine plus l'alerte ici mais on retourne total_places
    return total_places

        

def dessiner_boutique():
    global champs_prix_boutique
    produits = ["Drapeaux", "Casquettes", "Écharpes", "T-shirts"]
    prix_fixes = [5, 10, 8, 12]  # Valeurs si besoin pour affichage
    champs_prix_boutique.clear()

    x_nom = LARGEUR // 2 - 250
    x_stock = LARGEUR // 2 - 20
    x_prix = LARGEUR // 2 + 140
    y_debut = 220

    ORANGE_CLAIR = (255, 220, 180)

    # Titres des colonnes
    FENETRE.blit(FONT.render("Article", True, NOIR), (x_nom + 20, y_debut - 40))
    FENETRE.blit(FONT.render("Stock", True, NOIR), (x_stock + 20, y_debut - 40))
    FENETRE.blit(FONT.render("Prix (€)", True, NOIR), (x_prix + 20, y_debut - 40))

    total_recettes = 0

    for i, produit in enumerate(produits):
        y = y_debut + i * 70

        # Nom de l'article
        rect_nom = pygame.Rect(x_nom, y, 160, 60)
        pygame.draw.rect(FENETRE, BLEU, rect_nom)
        pygame.draw.rect(FENETRE, NOIR, rect_nom, 2)
        if produit == "Casquettes":
            img_rect = casquette_img.get_rect(center=rect_nom.center)
            FENETRE.blit(casquette_img, img_rect)
        elif produit == "Écharpes":
            img_rect = echarpe_img.get_rect(center=rect_nom.center)
            FENETRE.blit(echarpe_img, img_rect)
        elif produit == "Drapeaux":
            img_rect = drapeau_img.get_rect(center=rect_nom.center)
            FENETRE.blit(drapeau_img, img_rect)
        elif produit == "T-shirts":
            img_rect = tshirt_img.get_rect(center=rect_nom.center)
            FENETRE.blit(tshirt_img, img_rect)
        else:
            FENETRE.blit(FONT.render(produit, True, BLANC), rect_nom.move(10, 10))



        # Stock (fixe)
        rect_stock = pygame.Rect(x_stock, y, 100, 50)
        pygame.draw.rect(FENETRE, ORANGE_CLAIR, rect_stock)
        pygame.draw.rect(FENETRE, NOIR, rect_stock, 2)
        stock_article = stock_boutique[produit]
        FENETRE.blit(FONT.render(str(stock_article), True, NOIR), rect_stock.move(30, 10))


        # Champ de saisie Prix
        rect_prix = pygame.Rect(x_prix, y, 80, 50)
        pygame.draw.rect(FENETRE, BLANC, rect_prix)
        pygame.draw.rect(FENETRE, NOIR, rect_prix, 2)
        texte = saisies_prix_boutique[i] + ("|" if champ_actif_prix_boutique == i else "")
        FENETRE.blit(FONT.render(texte, True, NOIR), (rect_prix.x + 5, rect_prix.y + 10))
        champs_prix_boutique.append(rect_prix)

        # Calcul total recettes
        if est_nombre(saisies_prix_boutique[i]):
            total_recettes += int(saisies_prix_boutique[i]) * 100  # 100 unités par article

    # Affichage du total recettes avec encadré
        rect_total_boutique = pygame.Rect(x_prix - 290, 560, 360, 42)
        pygame.draw.rect(FENETRE, (255, 220, 180), rect_total_boutique)
        pygame.draw.rect(FENETRE, NOIR, rect_total_boutique, 2)

        texte_total = FONT.render(f"Total prévisionnel : {total_recettes:,}".replace(",", ".") + " €", True, NOIR)
        FENETRE.blit(texte_total, (rect_total_boutique.x + 10, rect_total_boutique.y + 8))

        global total_boutique
        total_boutique = total_recettes




# --- Fonction utilitaire pour vérifier si une chaîne est un nombre ---
def est_nombre(s):
    try:
        int(s)
        return True
    except:
        return False


def dessiner_interface_stade():
    FENETRE.fill((230, 230, 230))  # Nettoie l'écran
    global message_blocage, temps_blocage

    # 1. 🏟️ Affichage du fond (image du stade)
    try:
        stade_image = pygame.image.load("images/stade.png").convert_alpha()
        stade_image = pygame.transform.scale(stade_image, (LARGEUR, HAUTEUR))
        stade_image.set_alpha(160)  # transparence OK
        FENETRE.blit(stade_image, (0, 0))  # ✅ FOND affiché d’abord
        if message_blocage:
            texte = FONT.render(message_blocage, True, ROUGE)
            rect = texte.get_rect(center=(LARGEUR // 2, 115))
            FENETRE.blit(texte, rect)
        
    except Exception as e:
        print("❌ Erreur image stade :", e)
        erreur = FONT.render("[Image du stade manquante]", True, ROUGE)
        FENETRE.blit(erreur, (100, 360))

    # 2. 🧭 Boutons onglets
    index_match = len(historique_matchs)  # Pour savoir si match extérieur

    for i, t in enumerate(titres_stade):
        rect = rects_stade[i]
        zone = t.lower()

    # Détermine la couleur selon l'état
        if index_match % 2 == 1 and zone in ["billetterie", "boutique"]:
            couleur = (150, 150, 150)  # gris si bloqué
        elif zone_selectionnee == zone:
            couleur = (0, 70, 140)     # bleu foncé si sélectionné
        else:
            couleur = BLEU            # bleu normal

        pygame.draw.rect(FENETRE, couleur, rect)
        pygame.draw.rect(FENETRE, NOIR, rect, 2)

        txt = FONT.render(t, True, NOIR)
        txt_rect = txt.get_rect(center=rect.center)
        FENETRE.blit(txt, txt_rect)

    # 3. 📄 Contenu de l’onglet sélectionné
    if zone_selectionnee == "billetterie":
        titre_niveau = POLICE_TITRE.render("Niveau 1", True, NOIR)
        FENETRE.blit(titre_niveau, (425, 120))
        total_places = dessiner_billetterie()

        if total_places > CAPACITE_STADE_NIVEAU1:
            alerte = FONT.render("(!) Capacité de places dépassée !", True, ROUGE)
            FENETRE.blit(alerte, (LARGEUR // 2 - alerte.get_width() // 2, 500))


    elif zone_selectionnee == "terrain":
        titre_niveau = POLICE_TITRE.render("Niveau 1", True, NOIR)
        FENETRE.blit(titre_niveau, (425, 120))
            
        # ✅ Rectangle texte à gauche
        valeur_formatee = f"{COUT_ENTRETIEN_ANNUEL_NIVEAU1:,}".replace(",", ".") + " €"
        infos = [
            ("Capacité actuelle", f"{CAPACITE_STADE_NIVEAU1}"),
            ("Entretien", "Bon"),
            ("Coût d'entretien ", valeur_formatee),

            
        ]
        for j, (label, valeur) in enumerate(infos):
            box_label = pygame.Rect(LARGEUR // 2 - 375, 275 + j * 60, 220, 50)
            box_val = pygame.Rect(LARGEUR // 2 - 145, 275 + j * 60, 120, 50)
            pygame.draw.rect(FENETRE, NOIR, box_label, 2)
            pygame.draw.rect(FENETRE, BLANC, box_val)
            pygame.draw.rect(FENETRE, NOIR, box_val, 2)
            txt_label = FONT.render(label, True, NOIR)
            txt_val = FONT.render(valeur, True, NOIR)
            FENETRE.blit(txt_label, (box_label.left + 10, box_label.centery - txt_label.get_height() // 2))
            FENETRE.blit(txt_val, (box_val.centerx - txt_val.get_width() // 2, box_val.centery - txt_val.get_height() // 2))

                # --- Bouton Évolution du stade ---
            pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_evolution_stade)
            pygame.draw.rect(FENETRE, NOIR, bouton_evolution_stade, 2)
            texte_evo = FONT.render("Faire évoluer", True, BLANC)
            texte_rect = texte_evo.get_rect(center=bouton_evolution_stade.center)
            FENETRE.blit(texte_evo, texte_rect)


        # 🖼️ Image terrain à droite
        try:
            img_terrain = pygame.image.load("images/terrain_niveau1.png").convert_alpha()

           # Dimensions de base
            largeur_base = 300
            hauteur_base = 180

    # ➕ Effet de bascule (largeur oscillante)
            scale = 1 + 0.10 * math.sin(pygame.time.get_ticks() / 700)
            nouvelle_largeur = int(largeur_base * scale)

            image_scaled = pygame.transform.scale(img_terrain, (nouvelle_largeur, hauteur_base))



    # ➕ Position centrée
            rect = image_scaled.get_rect(center=(LARGEUR // 2 + 250, 400))
            FENETRE.blit(image_scaled, rect)

        except Exception as e:
            print("❌ Erreur image terrain :", e)
            msg = FONT.render("[Image terrain manquante]", True, ROUGE)
            FENETRE.blit(msg, (100, 360))

            #Exemple de coût d'entretien annuel fixe
            
        cout_entretien_annuel_niveau1 = 45500  # valeur en dur, à modifier si besoin

        rect_entretien = pygame.Rect(LARGEUR // 2 - 250, 500, 450, 50)
        pygame.draw.rect(FENETRE, (255, 220, 180), rect_entretien)  # fond clair
        pygame.draw.rect(FENETRE, NOIR, rect_entretien, 2)

        texte_label = FONT.render("Coût d'entretien annuel", True, NOIR)
        FENETRE.blit(texte_label, (rect_entretien.x + 10, rect_entretien.y + 5))

        texte_valeur = FONT.render(f"{cout_entretien_annuel_niveau1:,} €".replace(",", "."), True, NOIR)
        val_rect = texte_valeur.get_rect()
        val_rect.topright = (rect_entretien.right - 10, rect_entretien.y + 5)
        FENETRE.blit(texte_valeur, val_rect)

    elif zone_selectionnee == "boutique":
        titre_niveau = POLICE_TITRE.render("Niveau 1", True, NOIR)
        FENETRE.blit(titre_niveau, (425, 120))
        dessiner_boutique()

    elif zone_selectionnee == "parkings":
        titre_niveau = POLICE_TITRE.render("Niveau 1", True, NOIR)
        FENETRE.blit(titre_niveau, (425, 120))
        texte = FONT.render("A partir du Niveau 2...", True, NOIR)
        FENETRE.blit(texte, (LARGEUR // 2 - texte.get_width() // 2, 300))


    # 4. 🔙 Bouton retour
    pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
    FENETRE.blit(FONT.render("Menu", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))

    pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_confirmer_stade)
    pygame.draw.rect(FENETRE, NOIR, bouton_confirmer_stade, 2)
    texte_confirmer = FONT.render("Confirmer", True, BLANC)
    texte_rect = texte_confirmer.get_rect(center=bouton_confirmer_stade.center)
    FENETRE.blit(texte_confirmer, texte_rect)


def dessiner_tableau_classement_sans_fond(
    classement, nom_equipe,
    x_depart=100, y_depart=98,
    largeur_colonne=105, hauteur_ligne=32,
    police=POLICE_CLASSEMENT
):
    titres = ["Pos.", "Équipe", "Points", "Vict.", "Déf.", "Nuls"]

    # Titres de colonnes
    for i, titre in enumerate(titres):
        rect = pygame.Rect(x_depart + i * largeur_colonne, y_depart, largeur_colonne, hauteur_ligne)
        pygame.draw.rect(FENETRE, BLEU_FONCE, rect)
        pygame.draw.rect(FENETRE, NOIR, rect, 2)
        texte = police.render(titre, True, BLANC)
        texte_rect = texte.get_rect(center=rect.center)
        FENETRE.blit(texte, texte_rect)

    # Contenu du tableau
    for idx, equipe_data in enumerate(classement):
        y = y_depart + (idx + 1) * hauteur_ligne

        if idx < 2:
            couleur_fond = (100, 255, 100)
        elif idx >= len(classement) - 2:
            couleur_fond = (255, 150, 150)
        else:
            couleur_fond = BLANC

        if equipe_data['nom'] == nom_equipe:
            police_utilisee = pygame.font.SysFont("comicsansms", 18, bold=True)
        else:
            police_utilisee = police


        for col_idx, key in enumerate(["position", "nom", "points", "victoires", "defaites", "matchs_nuls"]):
            rect = pygame.Rect(x_depart + col_idx * largeur_colonne, y, largeur_colonne, hauteur_ligne)
            pygame.draw.rect(FENETRE, couleur_fond, rect)
            pygame.draw.rect(FENETRE, NOIR, rect, 1)

            texte_val = str(idx + 1) if key == "position" else str(equipe_data.get(key, ""))
            texte = police_utilisee.render(texte_val, True, NOIR)
            texte_rect = texte.get_rect(center=rect.center)
            FENETRE.blit(texte, texte_rect)



def dessiner_menu_saison():
    global titres_saison, rects_saison, zone_selectionnee_saison, ballon_rect
    global ballon_rect, fleche_decalage, fleche_base_y, etat
    global resultats_matchs_complets

    
    if zone_selectionnee_saison != "mercato":
        FENETRE.blit(fond_saison_img, (0, 0))

       
    for i, titre in enumerate(titres_saison):
        rect = rects_saison[i]
        couleur = ORANGE_CLAIR if titre.lower() == zone_selectionnee_saison else BLEU_CIEL
        pygame.draw.rect(FENETRE, couleur, rect)
        pygame.draw.rect(FENETRE, NOIR, rect, 2)
        txt = FONT.render(titre, True, NOIR)
        txt_rect = txt.get_rect(center=rect.center)
        FENETRE.blit(txt, txt_rect)
    
    if etat not in ["menu_saison", "match"]:
        return  # ne pas afficher en dehors de ces deux états

    if etat == "menu_saison":
        ballon_pos = (LARGEUR // 2, HAUTEUR // 2)
    else:
        ballon_pos = (LARGEUR // 2, HAUTEUR // 2)  # Toujours centré, même dans l'état match
    ballon_rect = ballon_img.get_rect(center=ballon_pos)


    fleche_base_y = ballon_rect.top - (10 if etat == "match" else 70)
    
    temps = pygame.time.get_ticks() / 500
    amplitude = 10

    fleche_decalage = amplitude * math.sin(temps)
    fleche_pos = (ballon_rect.centerx, int(fleche_base_y + fleche_decalage))


    dessiner_halo_autour_du_ballon(ballon_rect.center)
    FENETRE.blit(fleche_img, fleche_img.get_rect(center=fleche_pos))

    # Texte au-dessus de la flèche qui suit le même mouvement vertical
    if len(historique_matchs) >= total_matchs_saison:
        texte_texte = "Fin de saison"
        bouton_actif = False
    else:
        texte_texte = "Démarrer MATCH !"
        bouton_actif = True

    texte_match = FONT.render(texte_texte, True, NOIR)


    texte_rect = texte_match.get_rect(center=(fleche_pos[0], fleche_pos[1] - 40))
    padding_x, padding_y = 10, 5
    rect_encadre = pygame.Rect(
        texte_rect.left - padding_x,
        texte_rect.top - padding_y,
        texte_rect.width + 2 * padding_x,
        texte_rect.height + 2 * padding_y
    )
    fond_encadre = pygame.Surface((rect_encadre.width, rect_encadre.height), pygame.SRCALPHA)
    fond_encadre.fill((255, 255, 255, 200))
    FENETRE.blit(fond_encadre, (rect_encadre.left, rect_encadre.top))
    pygame.draw.rect(FENETRE, NOIR, rect_encadre, 2)
    FENETRE.blit(texte_match, texte_rect)
    
    FENETRE.blit(ballon_img, ballon_rect)

    if etat == "match":
        # Zone autour des informations du match (ajuster la taille de la zone si nécessaire)
        zone_match = pygame.Rect(80, 100, 840, 500)  # Ajuste la zone selon où tu affiches les infos du match

        # Vérifie si un clic a eu lieu
        if pygame.mouse.get_pressed()[0]:  # Si un clic gauche a eu lieu
            pos = pygame.mouse.get_pos()
            if bouton_retour.collidepoint(pos):  # Si le clic est sur le bouton "Retour"
                etat = "gestion"  # Rediriger vers l'écran de gestion
            elif etat == "match" and not zone_match.collidepoint(pos):  # Si le clic est en dehors de la zone de l'affichage du match
                etat = "menu_saison"  # Revenir au menu saison

    

    # Bouton retour
    pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
    pygame.draw.rect(FENETRE, NOIR, bouton_retour, 2)
    FENETRE.blit(FONT.render("Retour", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))
    
    
        # Affichage du tableau de classement sous le menu si l'onglet sélectionné est "classement"
    if zone_selectionnee_saison == "classement":
        dessiner_tableau_classement_sans_fond(classement, nom_equipe)
    elif zone_selectionnee_saison == "statistiques":
        dessiner_statistiques()
    elif zone_selectionnee_saison == "mercato":
        if not joueurs_mercato:
            generer_joueurs_mercato()
        dessiner_mercato_tableau()
    elif zone_selectionnee_saison == "calendrier":
        global prochain_adversaire
    
        derniers_matchs = historique_matchs[-22:]
        max_height_fond = 365  # Hauteur maximale du fond blanc pour les derniers matchs
        hauteur_matchs = len(derniers_matchs) * 30
        hauteur_fond_matchs = min(hauteur_matchs, max_height_fond)

        fond_rect = pygame.Rect(180, 95, 700, hauteur_fond_matchs + 150)
        pygame.draw.rect(FENETRE, BLANC, fond_rect)
        pygame.draw.rect(FENETRE, NOIR, fond_rect, 2)

        texte_saison = POLICE_MOYENNE.render(f"Saison {saison_actuelle}  —  Matchs joués : {len(historique_matchs)} / {total_matchs_saison}", True, NOIR)
        FENETRE.blit(texte_saison, (fond_rect.x + 280, fond_rect.y + 16))

        titre = POLICE_MOYENNE_BOLD.render("Derniers matchs", True, NOIR)
        FENETRE.blit(titre, (fond_rect.x + 20, fond_rect.y + 30))

        y_offset = fond_rect.y + 85

        total = len(historique_matchs)
        nb_matchs_affiches = len(derniers_matchs)

        for i, ligne_brute in enumerate(reversed(derniers_matchs)):
            if "|" in ligne_brute:
                score_txt, resultat = ligne_brute.split("|")
            else:
                score_txt, resultat = ligne_brute, "Match Nul"

            try:
                parts = score_txt.split()
                equipe_a = parts[0]
                score1 = parts[1]
                score2 = parts[3]
                equipe_b = parts[4]
            except:
                equipe_a = equipe_b = nom_equipe
                score1 = score2 = "?"

            index = len(historique_matchs) - 1 - i  # Index du match réel
            if index % 2 == 0:
                texte = f"{nom_equipe} {score1} - {score2} {equipe_b}"
            else:
                texte = f"{equipe_b} {score2} - {score1} {nom_equipe}"


            couleur = (50, 160, 50) if resultat == "Victoire" else (200, 50, 50) if resultat == "Défaite" else (120, 120, 120)

            # ✅ Correction de l’index lié au vrai match
            if len(resultats_matchs_complets) > i:
               mvp = resultats_matchs_complets[-1 - i].get("mvp_match", {}).get("nom")
               if mvp:
                   texte += f" ({mvp})"



            txt = POLICE_CLASSEMENT.render(texte, True, couleur)
            FENETRE.blit(txt, (fond_rect.x + 20, y_offset))
            y_offset += 30


        if prochain_adversaire:
            titre_next = POLICE_MOYENNE.render("(MVP)              Prochain match :", True, NOIR)
            FENETRE.blit(titre_next, (fond_rect.x + 305, fond_rect.y + 60))

            temps_actuel = pygame.time.get_ticks()
            afficher = (temps_actuel // 1000) % 2 == 0

            if afficher:
                if len(historique_matchs) >= total_matchs_saison:
                    texte_match = "Fin de saison"
                else:
                    index = len(historique_matchs)
                    if index % 2 == 0:
                        texte_match = f"{nom_equipe} vs. {prochain_adversaire}"
                    else:
                        texte_match = f"{prochain_adversaire} vs. {nom_equipe}"

                txt_next = POLICE_MOYENNE_BOLD.render(texte_match, True, NOIR)
                FENETRE.blit(txt_next, (fond_rect.x + 450, fond_rect.y + 90))
                
    texte_pop = pygame.font.SysFont("comicsansms", 22, bold=True).render(f"Popularité : {popularite} / 100", True, NOIR)
    FENETRE.blit(texte_pop, (LARGEUR - 260, HAUTEUR - 615))



    return ballon_rect




def dessiner_statistiques():
    global nom_equipe

    if not resultat_simulation:
        texte = FONT.render("Aucune statistique disponible.", True, NOIR)
        FENETRE.blit(texte, (LARGEUR // 2 - texte.get_width() // 2, HAUTEUR // 2))
        return

    total = len(statistiques_saison)
    if total == 0:
        stats_moyennes = {
            "tirs_2_pts": [0, 0],
            "tirs_3_pts": [0, 0],
            "passes": [0, 0],
            "fautes": [0, 0]
        }
    else:
        stats_moyennes = {
            "tirs_2_pts": [0, 0],
            "tirs_3_pts": [0, 0],
            "passes": [0, 0],
            "fautes": [0, 0]
        }
        for match in statistiques_saison:
            for k in stats_moyennes:
                stats_moyennes[k][0] += match[k][0]
                stats_moyennes[k][1] += match[k][1]

        for k in ["passes", "fautes"]:
            stats_moyennes[k][0] = round(stats_moyennes[k][0] / total)
            stats_moyennes[k][1] = round(stats_moyennes[k][1] / total)

        for k in ["tirs_2_pts", "tirs_3_pts"]:
            total_points = stats_moyennes[k][0]
            total_tirs = stats_moyennes[k][1]

            if k == "tirs_2_pts":
                points_par_tir = 2
            else:
                points_par_tir = 3

            tirs_reussis = total_points / points_par_tir if points_par_tir > 0 else 0
            taux = (tirs_reussis / total_tirs) * 100 if total_tirs > 0 else 0
            
            stats_moyennes[k][0] = round(taux)

    # === Tableau 1 : Équipe ===
    marge_x1 = 200
    top_depart = 100
    largeur_tableau1 = 660
    hauteur_tableau1 = 75
    ecart_x1 = 175
    ligne_y_gap1 = 30

    titre1 = POLICE_TITRE_STATS.render(f"{nom_equipe}", True, NOIR)
    FENETRE.blit(titre1, (marge_x1, top_depart))

    rect1 = pygame.Rect(marge_x1, top_depart + 40, largeur_tableau1, hauteur_tableau1)
    pygame.draw.rect(FENETRE, (240, 240, 240), rect1)
    pygame.draw.rect(FENETRE, NOIR, rect1, 2)

    stats_equipe = [
        ("Tirs à 2 pts", f"{stats_moyennes['tirs_2_pts'][0]} %"),
        ("Tirs à 3 pts", f"{stats_moyennes['tirs_3_pts'][0]} %"),
        ("Passes perdues", str(stats_moyennes['passes'][0])),
        ("Fautes", str(stats_moyennes['fautes'][0]))
    ]

    for i, (libelle, valeur) in enumerate(stats_equipe):
        x = marge_x1 + i * ecart_x1
        y = top_depart + 60
        texte_lib = FONT_STATS.render(libelle, True, NOIR)
        texte_lib_rect = texte_lib.get_rect(center=(x + ecart_x1 // 2, y))
        FENETRE.blit(texte_lib, texte_lib_rect)

        texte_val = FONT_STATS.render(valeur, True, NOIR)
        texte_val_rect = texte_val.get_rect(center=(x + ecart_x1 // 2, y + ligne_y_gap1))
        FENETRE.blit(texte_val, texte_val_rect)

    # === Tableau 2 : Joueurs (MVP) ===
    marge_x2 = 200
    top2 = top_depart + hauteur_tableau1 + 80
    largeur_tableau2 = 660
    hauteur_tableau2 = 110
    colonne_largeur = 115
    colonne_depart_x = marge_x2 + 200
    ligne_y_gap2 = 40

    titre2 = POLICE_TITRE_STATS.render("MVP", True, NOIR)
    FENETRE.blit(titre2, (marge_x2, top2))

    rect2 = pygame.Rect(marge_x2, top2 + 40, largeur_tableau2, hauteur_tableau2)
    pygame.draw.rect(FENETRE, (240, 240, 240), rect2)
    pygame.draw.rect(FENETRE, NOIR, rect2, 2)

    entetes = ["Points", "Passes déc.", "2 pts", "3 pts"]
    for j, entete in enumerate(entetes):
        x = colonne_depart_x + j * colonne_largeur
        entete_surface = FONT_STATS.render(entete, True, NOIR)
        entete_rect = entete_surface.get_rect(center=(x + colonne_largeur // 2, top2 + 50))
        FENETRE.blit(entete_surface, entete_rect)

     # 🔍 Détermination du nom du MVP de ton équipe
    if statistiques_saison and 'mvp_equipe' in statistiques_saison[-1]:
        dernier_mvp_eq = statistiques_saison[-1]['mvp_equipe'].get('nom', "N/A")
    else:
        dernier_mvp_eq = "N/A"

     # 🏷️ Titres des deux lignes du tableau MVP
    noms_joueurs = [f"MVP équipe: {dernier_mvp_eq}", "MVP de la saison"]



    # --- Calculs des deux MVP (même logique) ---
    mvp_eq_points = []
    mvp_eq_passes = []
    pts2_eq = tirs2_eq = 0
    pts3_eq = tirs3_eq = 0

    mvp_saison_points = []
    mvp_saison_passes = []
    pts2_saison = tirs2_saison = 0
    pts3_saison = tirs3_saison = 0
    
    for m in statistiques_saison:
        mvp = m.get("mvp_equipe", None)
        if mvp:
            points = mvp.get("points", 0)
            passes = mvp.get("passes", 0)
            tirs_2 = mvp.get("tirs_2_pts", [0, 0])
            tirs_3 = mvp.get("tirs_3_pts", [0, 0])

            if points > 0 or passes > 0 or sum(tirs_2) > 0 or sum(tirs_3) > 0:
                mvp_eq_points.append(points)
                mvp_eq_passes.append(passes)
                pts2_eq += tirs_2[0]
                tirs2_eq += tirs_2[1]
                pts3_eq += tirs_3[0]
                tirs3_eq += tirs_3[1]

    nb_mvp_valides = len(mvp_eq_points)

    if nb_mvp_valides > 0:
        points_moy_eq = sum(mvp_eq_points) / nb_mvp_valides
        passes_moy_eq = sum(mvp_eq_passes) / nb_mvp_valides
        taux2_eq = round((pts2_eq / 2) / tirs2_eq * 100) if tirs2_eq else 0
        taux3_eq = round((pts3_eq / 3) / tirs3_eq * 100) if tirs3_eq else 0

        stats_joueur_equipe = [
            str(round(points_moy_eq, 1)),
            str(round(passes_moy_eq, 1)),
            f"{taux2_eq} %",
            f"{taux3_eq} %"
        ]
    else:
        stats_joueur_equipe = ["0", "0", "0 %", "0 %"]

    for m in statistiques_saison:
        mvp = m.get("mvp_match", None)
        if mvp:
            points = mvp.get("points", 0)
            passes = mvp.get("passes", 0)
            tirs_2 = mvp.get("tirs_2_pts", [0, 0])
            tirs_3 = mvp.get("tirs_3_pts", [0, 0])

            if points > 0 or passes > 0 or sum(tirs_2) > 0 or sum(tirs_3) > 0:
                mvp_saison_points.append(points)
                mvp_saison_passes.append(passes)
                pts2_saison += tirs_2[0]
                tirs2_saison += tirs_2[1]
                pts3_saison += tirs_3[0]
                tirs3_saison += tirs_3[1]

    nb_matchs_valides = len(mvp_saison_points)

    if nb_matchs_valides > 0:
        points_moy_saison = sum(mvp_saison_points) / nb_matchs_valides
        passes_moy_saison = sum(mvp_saison_passes) / nb_matchs_valides
        taux2_saison = round((pts2_saison / 2) / tirs2_saison * 100) if tirs2_saison else 0
        taux3_saison = round((pts3_saison / 3) / tirs3_saison * 100) if tirs3_saison else 0

        stats_joueur_saison = [
            str(round(points_moy_saison, 1)),
            str(round(passes_moy_saison, 1)),
            f"{taux2_saison} %",
            f"{taux3_saison} %"
        ]
    else:
        stats_joueur_saison = ["0", "0", "0 %", "0 %"]


    stats = [stats_joueur_equipe, stats_joueur_saison]

    dernier_mvp_eq = statistiques_saison[-1]['mvp_equipe']['nom'] if statistiques_saison else ""


    for i, nom in enumerate(noms_joueurs):
        y = top2 + 80 + i * ligne_y_gap2
        nom_surface = FONT_STATS.render(nom, True, NOIR)
        nom_rect = nom_surface.get_rect(midleft=(marge_x2 + 10, y))
        FENETRE.blit(nom_surface, nom_rect)

        for j, valeur in enumerate(stats[i]):
            x = colonne_depart_x + j * colonne_largeur
            val_surface = FONT_STATS.render(valeur, True, NOIR)
            val_rect = val_surface.get_rect(center=(x + colonne_largeur // 2, y))
            FENETRE.blit(val_surface, val_rect)

            

def dessiner_halo_autour_du_ballon(position):
    halo_surface = pygame.Surface((120, 120), pygame.SRCALPHA)
    centre = (60, 60)
    for rayon, alpha in [(60, 20), (50, 40), (40, 80), (30, 120)]:
        pygame.draw.circle(halo_surface, (255, 165, 0, alpha), centre, rayon)
    FENETRE.blit(halo_surface, (position[0] - 60, position[1] - 60))


def dessiner_match():
    global resultat_simulation

    if resultat_simulation:
        cadre_resultat = pygame.Rect(180, 100, 675, 410)

        # Redimensionner et afficher le fond_resultat
        fond_resultat_redim = pygame.transform.scale(fond_resultat, (cadre_resultat.width, cadre_resultat.height))
        FENETRE.blit(fond_resultat_redim, (cadre_resultat.x, cadre_resultat.y))

        # Décalage à partir du haut du cadre
        x_centre = cadre_resultat.x + cadre_resultat.width // 2
        y_courant = cadre_resultat.y + 20

        # --- Score avec alternance visuelle domicile/extérieur ---
        index = len(historique_matchs) - 1
        if index % 2 == 0:
            texte_score = POLICE_TITRE.render(
                f"{nom_equipe} {resultat_simulation['score_equipe']} - {resultat_simulation['score_adverse']} {resultat_simulation['adversaire']}", True, NOIR
            )
        else:
            texte_score = POLICE_TITRE.render(
                f"{resultat_simulation['adversaire']} {resultat_simulation['score_adverse']} - {resultat_simulation['score_equipe']} {nom_equipe}", True, NOIR
            )
        FENETRE.blit(texte_score, (x_centre - texte_score.get_width() // 2, y_courant))
        y_courant += 40


        # --- Résultat (Victoire/Défaite/Égalité) ---
        resultat = resultat_simulation['resultat']
        res_color = (50, 160, 50) if resultat == "Victoire" else (200, 50, 50) if resultat == "Défaite" else (120, 120, 120)
        texte_resultat = POLICE_GRANDE.render(resultat, True, res_color)
        FENETRE.blit(texte_resultat, (x_centre - texte_resultat.get_width() // 2, y_courant))
        y_courant += 40

        # --- MVPs ---
        mvp_equipe = resultat_simulation['mvp_equipe']['nom']
        mvp_match = resultat_simulation['mvp_match']['nom']

        FENETRE.blit(FONT.render(f"MVP de l'équipe : {mvp_equipe}", True, NOIR), (220, 210))
        FENETRE.blit(FONT.render(f"MVP du match : {mvp_match}", True, NOIR), (220, 250))

        # --- Statistiques ---
        FENETRE.blit(POLICE_TITRE_STATS.render("Statistiques du match :", True, NOIR), (220, 300))

        stats_labels = [
            ("Tirs à 2 pts", "tirs_2_pts"),
            ("Tirs à 3 pts", "tirs_3_pts"),
            ("Passes décisives", "passes"),
            ("Fautes", "fautes")
        ]

        x_label_centre = LARGEUR // 2
        y_depart = 340
        ligne_hauteur = 30

        stats_data = resultat_simulation.get("stats", {})

        for i, (label, key) in enumerate(stats_labels):
            y = y_depart + i * ligne_hauteur
            val1, val2 = stats_data.get(key, [0, 0])

            texte_label = POLICE_MOYENNE.render(label, True, NOIR)
            texte_val1 = POLICE_MOYENNE.render(f"{val1}%" if "tirs" in key else f"{val1}", True, (50, 100, 255))
            texte_val2 = POLICE_MOYENNE.render(f"{val2}%" if "tirs" in key else f"{val2}", True, (255, 50, 50))

            # Position du label centré
            x_label = x_label_centre - texte_label.get_width() // 2
            # Ton équipe à gauche (aligné à droite)
            x_val1 = x_label - 20 - texte_val1.get_width()
            # Adversaire à droite (aligné à gauche)
            x_val2 = x_label + texte_label.get_width() + 20

            FENETRE.blit(texte_val1, (x_val1, y))
            FENETRE.blit(texte_label, (x_label, y))
            FENETRE.blit(texte_val2, (x_val2, y))

    else:
        texte = POLICE_TITRE.render("Aucun match simulé", True, NOIR)
        FENETRE.blit(texte, (LARGEUR // 2 - texte.get_width() // 2, HAUTEUR // 2))

    # --- Bouton Retour ---
    pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
    pygame.draw.rect(FENETRE, NOIR, bouton_retour, 2)
    FENETRE.blit(FONT.render("Retour", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))



def verifier_clic_zone_stade(pos):
    global zone_selectionnee, champ_actif_billet, champ_actif_places, champ_actif_prix_boutique

    for i, rect in enumerate(rects_stade):
        if rect.collidepoint(pos):
            zone = titres_stade[i].lower()

            # Bloque les clics sur billetterie et boutique lors des matchs à l'extérieur
            index = len(historique_matchs)
            if index % 2 == 1 and zone in ["billetterie", "boutique"]:
                return  # On bloque le clic

            # Sinon on valide la sélection
            zone_selectionnee = zone
            champ_actif_billet = None
            champ_actif_places = None
            champ_actif_prix_boutique = None
            return

    if zone_selectionnee == "billetterie":
        # D’abord tester les champs de prix
        for i, rect in enumerate(champs_billet_rects):
            if rect.collidepoint(pos):
                champ_actif_billet = i
                champ_actif_places = None
                return
        # Ensuite tester les champs de nombre de places
        for i, rect in enumerate(champs_places_rects):
            if rect.collidepoint(pos):
                champ_actif_places = i
                champ_actif_billet = None
                return

    if zone_selectionnee == "boutique":
        for i, rect in enumerate(champs_prix_boutique):
            if rect.collidepoint(pos):
                champ_actif_prix_boutique = i
                return

    # Si aucun champ cliqué
    champ_actif_billet = None
    champ_actif_places = None
    champ_actif_prix_boutique = None

def verifier_clic_zone_gestion(pos):
    global zone_selectionnee
    for rect, zone in gestion_boutons:
        if rect.collidepoint(pos):
            zone_selectionnee = zone
            print(f"Zone sélectionnée : {zone}")
            if zone == "sponsors":
                dessiner_sponsors()
            return


   

# --- Boucle principale ---


# Et dans les événements MOUSEBUTTONDOWN :
# if etat == "stade":
#     verifier_clic_zone_stade(pos)
#     if bouton_retour.collidepoint(pos):
#         etat = "gestion"

# ------------------ Affichage ------------------
import random

def dessiner_fond_degrade():
    for i in range(HAUTEUR):
        couleur = (
            BLEU_CIEL[0] - i // 10 if BLEU_CIEL[0] - i // 10 > 0 else 0,
            BLEU_CIEL[1] - i // 15 if BLEU_CIEL[1] - i // 15 > 0 else 0,
            BLEU_CIEL[2] - i // 20 if BLEU_CIEL[2] - i // 20 > 0 else 0,
        )
        pygame.draw.line(FENETRE, couleur, (0, i), (LARGEUR, i))

import math

LARGEUR, HAUTEUR = 1000, 700
FENETRE = pygame.display.set_mode((LARGEUR, HAUTEUR))  # agrandi pour tout afficher proprement
pygame.display.set_caption("Menu - Mon jeu de basket")



BLANC = (255, 255, 255)
NOIR = (0, 0, 0)
ballon_img = pygame.transform.scale(pygame.image.load("images/ballon.png").convert_alpha(), (64, 64))


VERT = (50, 200, 50)
BLEU = (100, 150, 255)
GRIS = (220, 220, 220)
ROUGE = (255, 100, 100)
BLEU_CIEL = (200, 145, 90)  # orange légèrement plus claire
BLEU_FONCE = (0, 51, 102)
calendrier_img = pygame.transform.scale(pygame.image.load("images/calendrier.png").convert_alpha(), (72, 72))

etat = "menu"
etat_pre_selection = "nom_equipe"
nom_equipe = ""
message_erreur = ""
resultat_simulation = None
saisie_active = False

historique_matchs = []
prochain_adversaire = ""



bouton_creer = pygame.Rect(250, 250, 300, 80)
bouton_gestion_menu = pygame.Rect(250, 360, 300, 80)
bouton_valider = pygame.Rect(650, 630, 130, 40)
bouton_retour = pygame.Rect(20, 630, 100, 40)
bouton_confirmer_stade = pygame.Rect(850, 630, 120, 40)
champ_texte = pygame.Rect((LARGEUR - 300) // 2, (HAUTEUR - 40) // 2, 300, 40)
bouton_demarrer_saison = pygame.Rect(250, 470, 300, 80)

bouton_confirmer = pygame.Rect(700, 630, 150, 40)


boutons_filtre = {
    "Tous": pygame.Rect(100, 10, 80, 30),
    "Meneur": pygame.Rect(190, 10, 100, 30),
    "Ailier": pygame.Rect(300, 10, 100, 30),
    "Arrière": pygame.Rect(410, 10, 100, 30),
    "Pivot": pygame.Rect(520, 10, 100, 30)
}

def draw_bouton_3D(rect, couleur, texte, texte_color=BLANC):
    ombre = pygame.Rect(rect.x + 3, rect.y + 3, rect.width, rect.height)
    pygame.draw.rect(FENETRE, (50, 50, 50), ombre)
    pygame.draw.rect(FENETRE, couleur, rect)
    txt = FONT.render(texte, True, texte_color)
    txt_rect = txt.get_rect(center=rect.center)
    FENETRE.blit(txt, txt_rect)

def dessiner_menu():
    global confetti_start_time

    if nom_equipe.strip():
        FENETRE.blit(image_joueurs, (0, 0))  
    else:
        dessiner_fond_degrade()  

    titre_principal = "Bienvenue !"
    if nom_equipe.strip():
        titre_principal = f"Emmène {nom_equipe} à la victoire\nBon match !"
    
    angle = pygame.time.get_ticks() / 300
    offset = int(5 * math.sin(angle))
    taille_titre = 36 if nom_equipe.strip() else 48
    police_titre = pygame.font.SysFont("comicsansms", taille_titre, bold=True)
    lignes = titre_principal.split("\n")

    # Déclencher le timer confetti à l’affichage du message félicitations

    if titre_principal.startswith("Félicitations") and confetti_start_time is None:
        confetti_start_time = pygame.time.get_ticks()

    for i, ligne in enumerate(lignes):
        if i == 1 and nom_equipe.strip() in ligne:
            parts = ligne.split(nom_equipe)
            texte_gauche = police_titre.render(parts[0], True, NOIR)
            texte_droite = police_titre.render(nom_equipe, True, BLEU_FONCE)
            gauche_rect = texte_gauche.get_rect()
            gauche_rect.center = (LARGEUR // 2 - texte_droite.get_width() // 2, 80 + offset + i * 45)
            droite_rect = texte_droite.get_rect()
            droite_rect.topleft = (gauche_rect.right, gauche_rect.top)
            FENETRE.blit(texte_gauche, gauche_rect)
            FENETRE.blit(texte_droite, droite_rect)
            continue
        titre = police_titre.render(ligne, True, NOIR)
        titre_rect = titre.get_rect(center=(LARGEUR // 2, 80 + offset + i * 45))
        FENETRE.blit(titre, titre_rect)

    # Affichage des boutons inchangé
    draw_bouton_3D(bouton_creer, BLEU_FONCE, "Revoir son équipe" if nom_equipe.strip() and not equipe else "Composer son équipe")
    if bouton_creer.collidepoint(pygame.mouse.get_pos()):
        y_hover = bouton_creer.y + bouton_creer.height // 2 - 32
        FENETRE.blit(ballon_img, (bouton_creer.right + 10, y_hover))

    draw_bouton_3D(bouton_gestion_menu, BLEU_FONCE, "Management du Club")
    if bouton_gestion_menu.collidepoint(pygame.mouse.get_pos()):
        y_hover = bouton_gestion_menu.y + bouton_gestion_menu.height // 2 - 32
        FENETRE.blit(homme_affaire_img, (bouton_gestion_menu.right + 10, y_hover))

    # Effet confetti pendant 3 secondes
    if confetti_start_time is not None:
        temps_ecoule = pygame.time.get_ticks() - confetti_start_time
        if temps_ecoule < confetti_duration:
            for c in confettis:
                c.update()
                c.draw(FENETRE)
        else:
            confetti_start_time = None

    if message_erreur:
        texte_erreur = FONT.render(message_erreur, True, ROUGE)
        FENETRE.blit(texte_erreur, (250, 560))

    if nom_equipe.strip() and len(equipe) >= 8:
        couleur_bouton = BLEU_FONCE
        texte_match = FONT.render("Démarrer match", True, BLANC)
    else:
        # Ne pas afficher le bouton dans les autres cas
        return

    pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_demarrer_match)
    pygame.draw.rect(FENETRE, NOIR, bouton_demarrer_match, 2)
    texte_match = FONT.render("Démarrer match", True, BLANC)
    texte_rect = texte_match.get_rect(center=bouton_demarrer_match.center)
    FENETRE.blit(texte_match, texte_rect)


def clic_dans_cercle(pos, centre, rayon):
    dx = pos[0] - centre[0]
    dy = pos[1] - centre[1]
    return dx*dx + dy*dy <= rayon*rayon


def dessiner_fond_stade():
    for i in range(HAUTEUR):
        couleur = (
            220 - i // 5 if 220 - i // 5 > 0 else 0,
            180 - i // 7 if 180 - i // 7 > 0 else 0,
            140 - i // 10 if 140 - i // 10 > 0 else 0,
        )
        pygame.draw.line(FENETRE, couleur, (0, i), (LARGEUR, i))

def dessiner_gestion():
    global gestion_boutons
    FENETRE.blit(terrain3, (0, 0))
    global popularite

        # Afficher le nom de l'équipe en haut
    police_titre_gestion = pygame.font.SysFont("comicsansms", 48, bold=True)
    titre_gestion = police_titre_gestion.render("Management du Club :", True, BLANC)
    titre_rect = titre_gestion.get_rect(center=(LARGEUR // 2, 50))
    FENETRE.blit(titre_gestion, titre_rect)

    texte_nom = POLICE_TITRE.render(nom_equipe, True, BLANC)
    x_nom = titre_rect.right + 20   # 20 px de marge
    y_nom = titre_rect.y + (titre_rect.height // 2 - texte_nom.get_height() // 2)  # centré verticalement avec le titre
    FENETRE.blit(texte_nom, (x_nom, y_nom))
    
    zones = [
        ("Sponsors", None, "sponsors"),
        ("Finances", None, "finances"),
        ("Aller au Game", None, "transferts"),
        ("Calendrier", None, "calendrier"),
        ("Stade", None, "stade"),
        ("Equipe", None, "selection"),
        ("Staff", None, "staff"),
    ]

    nb_zones = len(zones)
    angle_entre_zones = 360 / nb_zones  # espacement régulier en degrés

    centre_cercle = (LARGEUR // 2, HAUTEUR // 2 + 50)  # centre du cercle des boutons
    rayon_cercle = 200  # rayon du cercle imaginaire où sont disposés les boutons
    rayon_bouton = 50  # rayon des cercles boutons

    gestion_boutons = []

    images_dict = {
        "transferts": ballon_img,
        "finances": image_finance,
        "sponsors": image_sponsors,
        "stade": image_stadebasket,
        "calendrier": image_calendrier_gestion,
        "selection": joueurs2_img,
        "staff": staff_img,
       
    }
    
    mouse_pos = pygame.mouse.get_pos()

    for i, (texte, _, zone) in enumerate(zones):
        angle_deg = i * angle_entre_zones - 90  # démarre en haut
        angle_rad = math.radians(angle_deg)
        x = int(centre_cercle[0] + rayon_cercle * math.cos(angle_rad))
        y = int(centre_cercle[1] + rayon_cercle * math.sin(angle_rad))
        centre = (x, y)

        # Zoom si souris dessus
        distance_souris = math.hypot(mouse_pos[0] - x, mouse_pos[1] - y)
        zoom_max = 1.3  # facteur d'agrandissement max
        zoom_zone = 100  # zone d'effet autour du bouton en pixels

        if distance_souris < zoom_zone:
            facteur_zoom = 1 + (zoom_max - 1) * (1 - distance_souris / zoom_zone)
            rayon_affiche = int(rayon_bouton * facteur_zoom)
        else:
            facteur_zoom = 1
            rayon_affiche = rayon_bouton

        gestion_boutons.append((centre, rayon_affiche, zone))

        # Ombre avec rayon zoomé
        ombre_offset = 5
        pygame.draw.circle(FENETRE, (180, 180, 180), (x + ombre_offset, y + ombre_offset), rayon_affiche)

        # Cercle blanc du bouton avec rayon zoomé
        pygame.draw.circle(FENETRE, BLANC, centre, rayon_affiche)

        # Contour noir avec rayon zoomé
        pygame.draw.circle(FENETRE, NOIR, centre, rayon_affiche, 3)

        # Image centrée (taille adaptée par zoom)
        if zone in images_dict and images_dict[zone] is not None:
            img = images_dict[zone]
            taille_img_base = img.get_width()
            taille_img_zoom = int(taille_img_base * facteur_zoom)
            img_redim = pygame.transform.smoothscale(img, (taille_img_zoom, taille_img_zoom))
            img_rect = img_redim.get_rect(center=centre)
            FENETRE.blit(img_redim, img_rect)


        # Affichage bulle rectangulaire au survol
        if distance_souris < rayon_affiche:
            # Taille de la bulle en fonction du texte
            padding_x, padding_y = 10, 5
            texte_bulle = FONT.render(texte, True, NOIR)
            bulle_rect = texte_bulle.get_rect()
            bulle_rect.inflate_ip(padding_x*2, padding_y*2)
            bulle_rect.midbottom = (centre[0], centre[1] - rayon_affiche - 10)

            # Calculer le point sur le bord du cercle dans la direction vers la bulle
            bulle_pos = (bulle_rect.centerx, bulle_rect.bottom)
            vect_x = bulle_pos[0] - centre[0]
            vect_y = bulle_pos[1] - centre[1]
            distance_vect = math.hypot(vect_x, vect_y)

            if distance_vect != 0:
                bord_x = centre[0] + (vect_x / distance_vect) * rayon_affiche
                bord_y = centre[1] + (vect_y / distance_vect) * rayon_affiche
            else:
                bord_x, bord_y = centre

            pygame.draw.line(FENETRE, BLANC, (bord_x, bord_y), bulle_pos, 2)
        
            # Fond bulle
            pygame.draw.rect(FENETRE, BLANC, bulle_rect, border_radius=5)
            # Texte bulle
            FENETRE.blit(texte_bulle, (bulle_rect.left + padding_x, bulle_rect.top + padding_y))

    
# Exemple : à la fin de dessiner_gestion()
    texte_pop = pygame.font.SysFont("comicsansms", 22, bold=True).render(f"Popularité : {popularite} / 100", True, BLANC)
    FENETRE.blit(texte_pop, (LARGEUR - 260, HAUTEUR - 615))


    couleur_menu = (200, 50, 50) if bouton_retour.collidepoint(pygame.mouse.get_pos()) else ROUGE
    pygame.draw.rect(FENETRE, couleur_menu, bouton_retour)
    FENETRE.blit(FONT.render("Menu", True, BLANC), (bouton_retour.x + 10, bouton_retour.y - 50))
     


def dessiner_mon_equipe():
    FENETRE.fill(BLANC)
    
    # Chargement et affichage du demi-terrain (gauche)
    try:
        demi_terrain_img = pygame.image.load("images/demi_terrain.png").convert_alpha()
        demi_terrain_img = pygame.transform.scale(demi_terrain_img, (350, 420))
        FENETRE.blit(demi_terrain_img, (0, 80))
    except:
        FENETRE.blit(FONT.render("[Image demi-terrain manquante]", True, ROUGE), (20, 300))

    # Titre (centré mais légèrement décalé à droite)
    titre_font = pygame.font.SysFont("comicsansms", 28)  # Taille réduite pour le titre
    titre = titre_font.render("Compo de l'équipe", True, NOIR)
    FENETRE.blit(titre, (LARGEUR // 2 - titre.get_width() // 2 + 190, 30))

    # --- Placement des 8 joueurs sélectionnés sur le terrain ---
    positions = [
        (175, 84), (105, 126), (245, 126), (70, 197),
        (280, 197), (140, 245), (210, 245), (175, 315)
    ]
    for idx, joueur_id in enumerate(equipe):
        if idx >= len(positions): break  # Sécurité
        joueur = joueurs[joueur_id]
        x, y = positions[idx]

        # Rond
        pygame.draw.circle(FENETRE, BLEU, (x, y), 25)
        pygame.draw.circle(FENETRE, NOIR, (x, y), 25, 2)

        # Nom au centre
        nom_surface = FONT.render(joueur["nom"], True, BLANC)
        nom_rect = nom_surface.get_rect(center=(x, y))
        FENETRE.blit(nom_surface, nom_rect)

    # Total salaires
    total_salaire = sum(int(joueurs[i]['salaire'].replace(' €', '').replace('.', '').replace(' ', '')) for i in equipe)
    total_texte = FONT.render(f"Total salaires : {total_salaire:,} €", True, NOIR)
    FENETRE.blit(total_texte, (550, 550))

    # --- Tableau des joueurs ---
    
    # Définir les titres des colonnes
    titres = ["Nom", "Poste", "Âge", "Vit.", "For.", "Def.", "End.", "Salaire"]
    largeur_colonne = 80
    hauteur_ligne = 30
    x_depart = 350
    y_depart = 160  # Position du tableau sous les informations de l'équipe
    # Dessiner la ligne des titres
    for i, titre in enumerate(titres):
        rect = pygame.Rect(x_depart + i * largeur_colonne, y_depart, largeur_colonne, hauteur_ligne)
        pygame.draw.rect(FENETRE, BLEU_FONCE, rect)  # fond bleu foncé
        pygame.draw.rect(FENETRE, NOIR, rect, 2)     # bordure noire
        texte = FONT.render(titre, True, BLANC)
        texte_rect = texte.get_rect(center=rect.center)
        FENETRE.blit(texte, texte_rect)

     # Définir une police plus petite pour le tableau
    petite_font = pygame.font.SysFont("comicsansms", 18)  # Taille réduite
    
    # Dessiner chaque joueur dans une ligne
    for idx, joueur_id in enumerate(equipe):
        joueur = joueurs[joueur_id]
        y = y_depart + (idx + 1) * hauteur_ligne
        
        # Dessiner la ligne pour chaque joueur
        for col_idx, key in enumerate(["nom", "poste", "age", "vitesse", "force", "defense", "endurance", "salaire"]):
            rect = pygame.Rect(x_depart + col_idx * largeur_colonne, y, largeur_colonne, hauteur_ligne)
            pygame.draw.rect(FENETRE, BLANC, rect)  # fond blanc
            pygame.draw.rect(FENETRE, NOIR, rect, 1)  # bordure noire
            
            # Remplir le rectangle avec les données du joueur
            if key == "salaire":
                valeur = joueur[key].replace(' €', '')  # Afficher le salaire sans le symbole
            else:
                valeur = joueur[key]  # Utiliser la valeur directement
            texte = petite_font.render(str(valeur), True, NOIR)
            texte_rect = texte.get_rect(center=rect.center)
            FENETRE.blit(texte, texte_rect)


    # Bouton retour
    draw_bouton_3D(bouton_retour, ROUGE, "Retour")
    draw_bouton_3D(bouton_confirmer, BLEU_FONCE, "Confirmer")


    global total_charges
    total_charges = sum(int(joueurs[i]['salaire'].replace(' €', '').replace('.', '').replace(' ', '')) for i in equipe)



def dessiner_selection():
    FENETRE.fill(GRIS)

    fiche_largeur = 200
    fiche_hauteur = 250
    espacement = 25
    fiches_par_ligne = 4
    y_depart = 180 + decalage_scroll


    # Titre haut + nom d’équipe
    FENETRE.blit(FONT.render("Joueurs disponibles pour composer l'équipe :", True, NOIR), (50, 75))
    police_sport = pygame.font.SysFont("tahoma", 34, bold=True)
    texte_nom = police_sport.render(nom_equipe, True, NOIR)
    texte_rect = texte_nom.get_rect(topright=(LARGEUR - 10, 20))
    FENETRE.blit(texte_nom, texte_rect)

    if message_erreur and len(equipe) != SELECTIONS_MAX:
        police_alerte = pygame.font.SysFont("comicsansms", 12, bold=True)
        alerte_surface = police_alerte.render(message_erreur, True, ROUGE)
        FENETRE.blit(alerte_surface, (50, 60))

    groupes_poste = [
        ("Meneur", [j for j in joueurs if j["poste"] == "Meneur"]),
        ("Ailier", [j for j in joueurs if j["poste"] == "Ailier"]),
        ("Pivot", [j for j in joueurs if j["poste"] == "Pivot"]),
        ("Arrière", [j for j in joueurs if j["poste"] == "Arrière"])
    ]

    ligne_y = 0
    for nom_poste, joueurs_poste in groupes_poste:
        if poste_filtre != "Tous" and nom_poste != poste_filtre:
            continue

        # Titre du poste
        titre_surface = FONT.render(f"{nom_poste}s :", True, NOIR)
        y_titre = y_depart + ligne_y * (fiche_hauteur + espacement) - 50
        FENETRE.blit(titre_surface, (50, y_titre))

        for idx, joueur in enumerate(joueurs_poste):
            col = idx % fiches_par_ligne
            ligne_locale = idx // fiches_par_ligne
            x = 50 + col * (fiche_largeur + espacement)
            y = y_depart + ligne_y * (fiche_hauteur + espacement) + ligne_locale * (fiche_hauteur + espacement)

            rect = pygame.Rect(x, y, fiche_largeur, fiche_hauteur)

                # Affiche l'image de fond de la fiche (papier)
            FENETRE.blit(fond_fiche_img, (x, y))

                 # Si le joueur est sélectionné, dessine un surlignage vert transparent par-dessus
            if joueurs.index(joueur) in equipe:
                surlignage_vert = pygame.Surface((fiche_largeur, fiche_hauteur), pygame.SRCALPHA)
                surlignage_vert.fill((0, 255, 0, 80))  # Vert clair transparent (alpha=80)
                FENETRE.blit(surlignage_vert, (x, y))
            
            
            pygame.draw.rect(FENETRE, NOIR, rect, 2)
            joueur["rect"] = rect

            FENETRE.blit(FONT_NOM.render(joueur['nom'], True, COULEUR_NOM), (x + 5, y + 5))
            FENETRE.blit(FONT_FICHE.render(joueur['poste'], True, (80, 80, 80)), (x + 115, y + 5))
            FENETRE.blit(FONT_FICHE.render(f"Âge: {joueur['age']}", True, (80, 80, 80)), (x + 5, y + 30))

            salaire_k = joueur['salaire'].replace(' €', '').replace('.', '').replace(' ', '')
            salaire_affiche = f"{int(int(salaire_k) / 1000)}"
            FENETRE.blit(FONT_FICHE.render(f"Salaire: {salaire_affiche}K", True, (80, 80, 80)), (x + 5, y + 60))

            FENETRE.blit(FONT_FICHE.render(f"% Tir: {joueur['precision']:.0%}", True, (80, 80, 80)), (x + 5, y + 90))
            FENETRE.blit(FONT_FICHE.render(f"Vit.: {joueur['vitesse']}", True, (80, 80, 80)), (x + 5, y + 120))
            FENETRE.blit(FONT_FICHE.render(f"For.: {joueur['force']}", True, (80, 80, 80)), (x + 5, y + 150))
            FENETRE.blit(FONT_FICHE.render(f"Def.: {joueur['defense']}", True, (80, 80, 80)), (x + 5, y + 180))
            FENETRE.blit(FONT_FICHE.render(f"End.: {joueur['endurance']}", True, (80, 80, 80)), (x + 5, y + 210))



        lignes_utilisees = (len(joueurs_poste) - 1) // fiches_par_ligne + 1
        ligne_y += lignes_utilisees
        ligne_y += 0.3  # ou 0.5 pour un tout petit espace supplémentaire


    # Bas de l’écran : compteur + boutons
    FENETRE.blit(FONT.render(f"Joueurs sélectionnés : {len(equipe)} / {SELECTIONS_MAX}", True, NOIR), (580, 60))
    bouton_valider.x = 790  # décalage vers la droite (valeur par défaut = 650)
    couleur_valider = BLEU_FONCE if len(equipe) >= 8 else GRIS
    draw_bouton_3D(bouton_valider, couleur_valider, "Valider")
    draw_bouton_3D(bouton_retour, ROUGE, "Menu")


def dessiner_finances():
    global total_billetterie, total_boutique
    if 'total_billetterie' not in globals():
        total_billetterie = 0
    if 'total_boutique' not in globals():
        total_boutique = 0

    largeur_match = 250  # ← largeur du rectangle
    hauteur_match = 60   # ← hauteur du rectangle


    dessiner_fond_finances_degrade()
    titre = pygame.font.SysFont("comicsansms", 32, bold=True).render("Centre Financier", True, BLANC)
    FENETRE.blit(titre, (LARGEUR // 2 - titre.get_width() // 2, 40))

    x_base_1 = 80        # Position du rectangle "Total Recettes"
    x_base_2 = 550        # Position du rectangle "Total Dépenses"
    y_base = 475          # Même Y pour les deux
    largeur_box = 360
    hauteur_box = 60

    x_base_2 = x_base_1 + largeur_box + 180              # Bloc droit placé à droite avec écart

    # Calculs cumulatifs réels sur tous les matchs à domicile
    recettes_billetterie_cumulees = sum(
        match.get("recette_billetterie", 0)
        for match in historique_matchs
        if isinstance(match, dict) and match.get("domicile")
    )

    recettes_boutique_cumulees = sum(
        match.get("recette_boutique", 0)
        for match in historique_matchs
        if isinstance(match, dict) and match.get("domicile")
    )


    # Données financières avec couleur personnalisée
    total_billetterie = total_billetterie if 'total_billetterie' in globals() else 0
    total_boutique = total_boutique if 'total_boutique' in globals() else 0

    total_charges_salaire = sum(int(joueurs[i]['salaire'].replace(' €', '').replace(' ', '').replace('.', '')) for i in equipe)
    total_entretien = 75_500  # fixe pour l’instant

    total_recettes_calcule = recettes_sponsors + recettes_billetterie_cumulees + recettes_boutique_cumulees
    total_depenses_calcule = total_charges_salaire + total_entretien



    categories = [
    ("Total Recettes", total_recettes_calcule, (180, 255, 180)),
    ("Total Dépenses", total_depenses_calcule, (255, 180, 180)),
]

    solde_final = categories[0][1] - categories[1][1]

    
    # Déterminer la couleur selon la valeur du solde
    couleur = (50, 160, 50) if solde_final >= 0 else (200, 50, 50)  # vert ou rouge

    # Texte avec couleur dynamique et effet clignotant si rouge
    texte_police = pygame.font.SysFont("comicsansms", 24, bold=True)
    clignoter = True

    # Si rouge, activer clignotement basé sur le temps
    if solde_final < 0:
        temps_actuel = pygame.time.get_ticks()
        clignoter = (temps_actuel // clignotement_vitesse) % 2 == 0

    if clignoter:
        texte_surface = texte_police.render(f"Solde final : {solde_final:,} €".replace(",", "."), True, couleur)
    else:
        texte_surface = texte_police.render(f"Solde final : ", True, couleur)  # afficher partiel (ou rien si tu veux)


    x_solde = 380   # 🔁 Change cette valeur pour déplacer horizontalement
    y_solde = 580   # 🔁 Change cette valeur pour déplacer verticalement

    # Encadré (bordure uniquement, pas de fond)
    rect_texte = texte_surface.get_rect(topleft=(x_solde, y_solde))
    bordure = rect_texte.inflate(20, 10)
    pygame.draw.rect(FENETRE, couleur, bordure, 2)

    # Affichage du texte
    FENETRE.blit(texte_surface, rect_texte)


    # Affichage horizontal des deux rectangles
    for i, (titre, valeur, couleur) in enumerate(categories):
        x = x_base_1 if i == 0 else x_base_2
        rect = pygame.Rect(x, y_base, largeur_box, hauteur_box)

        pygame.draw.rect(FENETRE, couleur, rect)
        pygame.draw.rect(FENETRE, (0, 0, 0), rect, 2)

        texte = pygame.font.SysFont("comicsansms", 22, bold=True).render(f"{titre} : {valeur:,} €".replace(",", "."), True, (0, 0, 0))
        FENETRE.blit(texte, (rect.x + 10, rect.y + 15))

    
        # Nouveau petit rectangle "Détail recettes"
    
    petite_font = pygame.font.SysFont("comicsansms", 18)
    x_charges = 80
    y_charges = 270
    largeur_charges = 265
    hauteur_charges = 43

    rect_charges = pygame.Rect(x_charges, y_charges, largeur_charges, hauteur_charges)
    pygame.draw.rect(FENETRE, (180, 255, 180), rect_charges)
    pygame.draw.rect(FENETRE, NOIR, rect_charges, 2)

    texte_charges = petite_font.render(
    f"Détail Sponsors : {montant_sponsor_actuel:,} €".replace(",", "."), True, NOIR
)
    FENETRE.blit(texte_charges, (x_charges + 10, y_charges + 10))


    petite_font = pygame.font.SysFont("comicsansms", 18)
    x_charges = 80
    y_charges = 330
    largeur_charges = 265
    hauteur_charges = 43

    rect_charges = pygame.Rect(x_charges, y_charges, largeur_charges, hauteur_charges)
    pygame.draw.rect(FENETRE, (180, 255, 180), rect_charges)
    pygame.draw.rect(FENETRE, NOIR, rect_charges, 2)

    texte_charges = petite_font.render(f"Détail Billetterie : {recettes_billetterie_cumulees:,} €".replace(",", "."), True, NOIR)
    FENETRE.blit(texte_charges, (x_charges + 10, y_charges + 10))

    petite_font = pygame.font.SysFont("comicsansms", 18)
    x_charges = 80
    y_charges = 390
    largeur_charges = 265
    hauteur_charges = 43

    rect_charges = pygame.Rect(x_charges, y_charges, largeur_charges, hauteur_charges)
    pygame.draw.rect(FENETRE, (180, 255, 180), rect_charges)
    pygame.draw.rect(FENETRE, NOIR, rect_charges, 2)

    texte_charges = petite_font.render(f"Détail Boutique : {recettes_boutique_cumulees:,} €".replace(",", "."), True, NOIR)
    FENETRE.blit(texte_charges, (x_charges + 10, y_charges + 10))
    
           
                 # ✅ Rectangle pour les recettes du dernier match (juste en dessous)
   
    y_match = y_charges + hauteur_charges + 115  

    recette_match = total_billetterie + total_boutique

    rect_match = pygame.Rect(x_charges, y_match, largeur_match, hauteur_match)
    pygame.draw.rect(FENETRE, (180, 255, 180), rect_match)
    pygame.draw.rect(FENETRE, NOIR, rect_match, 2)

    petite_font = pygame.font.SysFont("comicsansms", 18)
    titre_match = petite_font.render("Recettes dernier match", True, BLEU_FONCE)
    montant = FONT.render(f"{recette_match:,} €".replace(",", "."), True, BLEU_FONCE)

    if len(historique_matchs) % 2 == 1:
        montant = FONT.render("0 € (ext.)", True, BLEU_FONCE)
    else:
        montant = FONT.render(f"{(total_billetterie + total_boutique):,} €".replace(",", "."), True, BLEU_FONCE)

    FENETRE.blit(titre_match, (x_charges + 20, y_match + 0))
    FENETRE.blit(montant, (x_charges + 100, y_match + 20))
    

          # Nouveau petit rectangle "Détail charges"
       
    petite_font = pygame.font.SysFont("comicsansms", 18)
    x_charges = 590
    y_charges = 330  
    largeur_charges = 265
    hauteur_charges = 43

    rect_charges = pygame.Rect(x_charges, y_charges, largeur_charges, hauteur_charges)
    pygame.draw.rect(FENETRE, (255, 180, 180), rect_charges)
    pygame.draw.rect(FENETRE, NOIR, rect_charges, 2)

    total_charges_salaire = sum(float(joueurs[i]['salaire'].replace(' €', '').replace(' ', '').replace('.', '').replace(',', '.')) for i in equipe)
    texte_charges = petite_font.render(f"Salaires : {total_charges_salaire:,.0f} €".replace(",", "."), True, NOIR)


    FENETRE.blit(texte_charges, (x_charges + 10, y_charges + 10))


    petite_font = pygame.font.SysFont("comicsansms", 18)
    x_charges = 590
    y_charges = 390 
    largeur_charges = 265
    hauteur_charges = 43

    rect_charges = pygame.Rect(x_charges, y_charges, largeur_charges, hauteur_charges)
    pygame.draw.rect(FENETRE, (255, 180, 180), rect_charges)
    pygame.draw.rect(FENETRE, NOIR, rect_charges, 2)

    valeur_formatee = f"{COUT_ENTRETIEN_ANNUEL_NIVEAU1:,}".replace(",", ".") + " €"
    texte_charges = petite_font.render(f"Entretien stade : {valeur_formatee}", True, NOIR)

    FENETRE.blit(texte_charges, (x_charges + 10, y_charges + 10))


         # --- Budget total ---
    x_budget = 525
    y_budget = 120
    largeur_budget = 365
    hauteur_budget = 60

    rect_total = pygame.Rect(x_budget, y_budget, largeur_budget, hauteur_budget)
    pygame.draw.rect(FENETRE, (255, 230, 150), rect_total)
    pygame.draw.rect(FENETRE, (0, 0, 0), rect_total, 2)

    grande_police = pygame.font.SysFont("comicsansms", 24, bold=True)
    texte_total = grande_police.render(f"Budget actuel : {solde_final:,} €".replace(",", "."), True, (0, 0, 0))
    FENETRE.blit(texte_total, (rect_total.x + 15, rect_total.y + 15))

         # --- Bouton retour ---
    draw_bouton_3D(bouton_retour, ROUGE, "Retour")


def dessiner_fond_finances_degrade():
    for y in range(HAUTEUR):
        niveau = max(10, min(100 + y // 5, 200))  # Gris progressif
        couleur = (niveau, niveau, niveau)
        pygame.draw.line(FENETRE, couleur, (0, y), (LARGEUR, y))



def formater_euros(valeur):
    try:
        return f"{int(valeur):,} €".replace(",", ".")
    except:
        return str(valeur)

    
def dessiner_sponsors():
    global sponsors_boutons
    FENETRE.blit(fond_sponsors_img, (0, 0))
    sponsors_boutons = []

    titre = POLICE_TITRE.render("Offres de Sponsors", True, NOIR)
    FENETRE.blit(titre, (LARGEUR // 2 - titre.get_width() // 2, 30))

    # Calcul total salaires actuel de l'équipe sélectionnée
    total_salaires = sum(
        int(joueurs[i]['salaire'].replace(' €', '').replace('.', '').replace(' ', '')) for i in equipe
    )
    cible_sponsoring = int(total_salaires * 0.9)

    sponsors_disponibles = [
        ("Gatorade", 2, "Si Top 3 -> +50k€"),
        ("Nike", 1, "Aucun"),
        ("Red Bull", 3, "Si Champion -> +105k€"),
        ("Adidas", 2, "Si en Finale -> +70k€"),
    ]

    x = 100
    y = 120
    largeur_case = 600
    hauteur_case = 80
    espacement = 30

    sponsor_actif = sponsor_selectionne if sponsor_duree_restante > 0 else None

    for nom, duree, bonus in sponsors_disponibles:
        montant_base = cible_sponsoring

        # Pondération selon durée du contrat, corrigée selon ta logique précise
        if duree == 1:
            montant_total = int(montant_base * 1.15)  # +15% pour 1 an
        elif duree == 2:
            montant_total = montant_base              # 90% du total salaires pour 2 ans
        elif duree == 3:
            montant_total = int(montant_base * 0.9)  # -10% pour 3 ans
        else:
            montant_total = montant_base

        rect = pygame.Rect(x, y, largeur_case, hauteur_case)
        sponsors_boutons.append((rect, nom, duree, montant_total, bonus))

        if sponsor_actif and sponsor_actif != nom:
            couleur = GRIS
        else:
            couleur = VERT_CLAIR if sponsor_selectionne == nom else ORANGE_CLAIR

        pygame.draw.rect(FENETRE, couleur, rect, border_radius=10)
        pygame.draw.rect(FENETRE, NOIR, rect, 2, border_radius=10)

        texte_nom = POLICE_GRANDE.render(nom, True, NOIR)
        texte_duree = POLICE_MOYENNE.render(f"{duree} an(s)", True, NOIR)
        texte_montant = POLICE_MOYENNE.render(formater_euros(montant_total) + "/saison", True, NOIR)
        texte_bonus = POLICE_PETITE.render(f"Bonus : {bonus}", True, (80, 80, 80))

        FENETRE.blit(texte_nom, (x + 20, y + 10))
        FENETRE.blit(texte_duree, (x + 250, y + 10))
        FENETRE.blit(texte_montant, (x + 400, y + 10))
        FENETRE.blit(texte_bonus, (x + 20, y + 45))

        y += hauteur_case + espacement

    # Bouton Retour
    pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
    pygame.draw.rect(FENETRE, NOIR, bouton_retour, 2)
    FENETRE.blit(FONT.render("Retour", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))

    # Bouton Confirmer si un sponsor est sélectionné
    if sponsor_selectionne:
        pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_confirmer_sponsor)
        pygame.draw.rect(FENETRE, NOIR, bouton_confirmer_sponsor, 2)
        txt = FONT.render("Confirmer", True, BLANC)
        FENETRE.blit(txt, txt.get_rect(center=bouton_confirmer_sponsor.center))

def lancer_saison():
    print("🚀 Saison lancée !")  # Pour vérifier que la fonction est bien appelée
    reinitialiser_statistiques()  # Indentation correcte ici

def reinitialiser_statistiques():
    for equipe in classement:
        equipe["victoires"] = 0
        equipe["defaites"] = 0
        equipe["matchs_nuls"] = 0
        equipe["points"] = 0  # Correction de l'indentation ici



def dessiner_mercato():
    global joueurs_mercato, boutons_achat
    FENETRE.blit(fond_resultat, (0, 0))
    titre = POLICE_TITRE.render("Marché des Transferts", True, NOIR)
    FENETRE.blit(titre, (LARGEUR // 2 - titre.get_width() // 2, 30))
    

    boutons_achat = []
    x, y = 100, 100
    for joueur in joueurs_mercato:
        info = f"{joueur['nom']} ({joueur['poste']}, {joueur['age']} ans) - {joueur['pondération']} pts - {joueur['salaire']}"
        texte = FONT.render(info, True, NOIR)
        FENETRE.blit(texte, (x, y))

        valeur = estimer_valeur_joueur(joueur)
        info = f"{joueur['nom']} ({joueur['poste']}, {joueur['age']} ans) - {joueur['pondération']} pts - {joueur['salaire']} - {valeur:,} €"
        info = info.replace(",", ".")

        bouton = pygame.Rect(x + 750, y, 100, 30)
        pygame.draw.rect(FENETRE, (0, 128, 0), bouton)
        FENETRE.blit(FONT.render("Acheter", True, NOIR), (bouton.x + 10, bouton.y + 5))
        boutons_achat.append((bouton, joueur))
        y += 40


def acheter_joueur(joueur):
    global joueurs, equipe, salaires_totaux

    # Crée un nouvel identifiant pour ce joueur
    nouvel_id = max(joueurs.keys(), default=0) + 1

    # Insère le joueur dans le dictionnaire joueurs avec ses données
    joueurs[nouvel_id] = {
        "nom": joueur["nom"],
        "poste": joueur["poste"],
        "age": joueur["age"],
        "vitesse": joueur.get("vitesse", random.randint(60, 80)),
        "tir": joueur.get("tir", random.randint(60, 80)),
        "defense": joueur.get("defense", random.randint(60, 80)),
        "endurance": joueur.get("endurance", random.randint(60, 80)),
        "salaire": joueur["salaire"],
        "pondération": joueur["pondération"]
    }

    # Ajoute ce joueur en haut de la composition d’équipe (index 0)
    equipe.insert(0, nouvel_id)

    # Met à jour le total des salaires
    salaires_totaux += joueur["salaire"]

    print(f"✅ {joueur['nom']} ajouté à l'équipe. Nouveau salaire total : {salaires_totaux}")


confettis = [Confetti(LARGEUR, HAUTEUR) for _ in range(100)]
confetti_start_time = None
confetti_duration = 3000  # Durée en ms


def main():
    global etat, poste_filtre, nom_equipe, message_erreur, saisie_active, zone_selectionnee
    global decalage_scroll
    global recettes_sponsors, sponsor_selectionne, sponsors_signes
    global equipe, champ_actif_billet, champ_actif_places, champ_actif_prix_boutique
    global ballon_rect, zone_selectionnee_saison
    global equipe, animation_terrain_debut
    global equipe_sauvegardee
    global message_blocage, temps_blocage
    global sponsor_duree_restante
    global popularite
    global etat, total_recettes
    global total_billetterie, total_boutique
    global montant_sponsor_actuel
    montant_sponsor_actuel = 0  # Valeur initiale avant signature

    
    if 'sponsor_duree_restante' not in globals():
        sponsor_duree_restante = 0



    message_blocage = ""
    temps_blocage = 0
    recette_match = 0
    recettes_billetterie = 0
    recettes_boutique = 0



    initialiser_classement()
    global prochain_adversaire
    if not prochain_adversaire:
        prochain_adversaire = random.choice([e for e in noms_equipes_possibles if e != nom_equipe])



    clock = pygame.time.Clock()
    en_cours = True
    while en_cours:
        if etat == "menu":
            dessiner_menu()
        elif etat == "nom_equipe":
            FENETRE.blit(fond_fond_compositionequipe_img, (0, 0))
            pygame.draw.rect(FENETRE, ROUGE if message_erreur else BLANC, champ_texte, 2)
            texte_nom = FONT.render(nom_equipe if saisie_active or nom_equipe else "Nom de l'équipe", True, NOIR)
            FENETRE.blit(texte_nom, (champ_texte.x + 10, champ_texte.y + 5))
            pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_valider)
            FENETRE.blit(FONT.render("Valider", True, BLANC), (bouton_valider.x + 30, bouton_valider.y + 5))
            pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
            FENETRE.blit(FONT.render("Menu", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))
        
        elif etat == "selection":
            dessiner_selection()
        elif etat == "mon_equipe":
            dessiner_mon_equipe()
        elif etat == "gestion":
            dessiner_gestion()
        elif etat == "finances":
            dessiner_finances()
        elif etat == "stade":
            dessiner_interface_stade()
        elif etat == "sponsors":
            dessiner_sponsors()
        elif etat == "transferts":
            FENETRE.fill(BLANC)
            texte = FONT.render("Transferts démarrés ! (à développer)", True, NOIR)
            FENETRE.blit(texte, (LARGEUR // 2 - texte.get_width() // 2, HAUTEUR // 2))
            draw_bouton_3D(bouton_retour, ROUGE, "Retour")
        elif etat == "menu_saison":
            dessiner_menu_saison()
        elif etat == "match":
            dessiner_menu_saison() 
            dessiner_match()
        elif etat == "saison":
            FENETRE.blit(fond_saison_img, (0, 0))  # Affiche le fond saison
            texte = FONT.render("Saison démarrée ! (à compléter)", True, NOIR)
            FENETRE.blit(texte, (LARGEUR // 2 - texte.get_width() // 2, HAUTEUR // 2))
            draw_bouton_3D(bouton_retour, ROUGE, "Retour")

        pygame.display.flip()
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                en_cours = False
            
            if event.type == pygame.MOUSEWHEEL and etat == "selection":
                decalage_scroll += event.y * 30  # 30 pixels par cran de molette
                decalage_scroll = max(-990, min(0, decalage_scroll))

            if event.type == pygame.KEYDOWN:
                print(f"Touche pressée : {event.unicode} (clé : {event.key})")
                print("Champ actif billet :", champ_actif_billet, "| Champ actif places :", champ_actif_places)
                print(f"Touche pressée : {event.unicode} | Zone : {zone_selectionnee}")

                # --- Nom de l'équipe ---
                if etat == "nom_equipe":
                    if event.key == pygame.K_RETURN:
                        if nom_equipe.strip():
                            initialiser_classement()
                            etat = "selection"
                            message_erreur = ""
                        else:
                            message_erreur = "Veuillez indiquer un nom d'équipe."
                    elif saisie_active:
                        if event.key == pygame.K_BACKSPACE:
                            nom_equipe = nom_equipe[:-1]
                        elif len(nom_equipe) < 20 and event.unicode.isprintable():
                            nom_equipe += event.unicode
                # --- Billetterie ---
                elif champ_actif_billet is not None:
                    if event.key == pygame.K_BACKSPACE:
                        saisies_billet[champ_actif_billet] = saisies_billet[champ_actif_billet][:-1]
                    elif event.unicode.isdigit() and len(saisies_billet[champ_actif_billet]) < 4:
                        saisies_billet[champ_actif_billet] += event.unicode

                elif champ_actif_places is not None:
                    if event.key == pygame.K_BACKSPACE:
                        saisies_places[champ_actif_places] = saisies_places[champ_actif_places][:-1]
                    elif event.unicode.isdigit() and len(saisies_places[champ_actif_places]) < 4:
                        saisies_places[champ_actif_places] += event.unicode
                # --- Boutique ---
                elif champ_actif_prix_boutique is not None:
                    if event.key == pygame.K_BACKSPACE:
                        saisies_prix_boutique[champ_actif_prix_boutique] = saisies_prix_boutique[champ_actif_prix_boutique][:-1]
                    elif event.unicode.isdigit() and len(saisies_prix_boutique[champ_actif_prix_boutique]) < 4:
                        saisies_prix_boutique[champ_actif_prix_boutique] += event.unicode
                        
                        
            if event.type == pygame.MOUSEBUTTONDOWN:
                pos = event.pos

                if etat == "menu_saison":
                    global resultat_simulation  
                    clic_sur_bouton_saison = False
                    for i, rect in enumerate(rects_saison):
                        if rect.collidepoint(pos):
                            zone_selectionnee_saison = titres_saison[i].lower()
                            clic_sur_bouton_saison = True
                            break

                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"
                        clic_sur_bouton_saison = True

                    elif ballon_rect is not None and ballon_rect.collidepoint(pos):
                        if len(historique_matchs) >= total_matchs_saison:
                            print("🚫 Saison terminée. Le bouton est désactivé.")
                        elif len(equipe) >= 8:
                            resultat_simulation = simuler_match()                           
                            print("🔁 Simulation lancée !", resultat_simulation)
                            etat = "match"
                        else:
                            message_erreur = "⚠️ Sélectionne 8 joueurs avant de simuler un match."
        
                        clic_sur_bouton_saison = True
 
                    if not clic_sur_bouton_saison:
                        zone_selectionnee_saison = ""
                        print("↩️ Retour à menu_saison central (ballon réactivé)")
                        etat = "menu_saison"


                champ_actif_billet = None
                champ_actif_places = None
                champ_actif_prix_boutique = None
                saisie_active = False
    
                if etat == "billetterie":
                    for i, rect in enumerate(champs_billet_rects):
                        if rect.collidepoint(pos):
                            champ_actif_billet = i
                            break
                    else:
                        for i, rect in enumerate(champs_places_rects):
                            if rect.collidepoint(pos):
                                champ_actif_places = i
                                break

                elif etat == "boutique":
                    for i, rect in enumerate(champs_prix_boutique):
                        if rect.collidepoint(pos):
                            champ_actif_prix_boutique = i
                            break

                elif etat == "nom_equipe":
                    if champ_texte.collidepoint(pos):
                        saisie_active = True
                    pygame.draw.rect(FENETRE, ROUGE if message_erreur else NOIR, champ_texte, 2)
                    texte_nom = FONT.render(nom_equipe if saisie_active or nom_equipe else "Nom de l'équipe", True, NOIR)
                    FENETRE.blit(texte_nom, (champ_texte.x + 10, champ_texte.y + 5))
                    pygame.draw.rect(FENETRE, BLEU_FONCE, bouton_valider)
                    FENETRE.blit(FONT.render("Valider", True, BLANC), (bouton_valider.x + 30, bouton_valider.y + 5))
                    pygame.draw.rect(FENETRE, ROUGE, bouton_retour)
                    FENETRE.blit(FONT.render("Menu", True, BLANC), (bouton_retour.x + 10, bouton_retour.y + 5))

                if etat == "menu":
                    if bouton_demarrer_saison.collidepoint(pos):
                        print("Clic sur démarrer saison détecté")
                        if len(equipe) == SELECTIONS_MAX:
                            lancer_saison()
                            etat = "menu_saison"
                            message_erreur = ""
                        else:
                            message_erreur = f"Veuillez sélectionner {SELECTIONS_MAX} joueurs avant de démarrer la saison."
                    elif bouton_creer.collidepoint(pos):
                        if nom_equipe.strip():  # Si un nom d'équipe existe déjà
                            etat = "selection"
                        else:
                            etat = "nom_equipe"
                    elif bouton_demarrer_match.collidepoint(pos):
                        etat = "menu_saison"
                    elif bouton_gestion_menu.collidepoint(pos):
                        etat = "gestion"
                    elif bouton_demarrer_saison.collidepoint(pos):
                        etat = "confrontation"

                elif etat == "gestion":
                    for centre, rayon, zone in gestion_boutons:
                        if clic_dans_cercle(pos, centre, rayon):
                            zone_selectionnee = zone
                            if zone == "stade":
                                etat = "stade"
                                zone_selectionnee = "terrain"
                                animation_terrain_debut = pygame.time.get_ticks()
                                if len(historique_matchs) % 2 == 1:
                                    message_blocage = "Match en extérieur : Billetterie et Boutique inaccessibles"
                                    temps_blocage = pygame.time.get_ticks()
                                else:
                                    message_blocage = ""

                            elif zone == "finances":
                                etat = "finances"
                            elif zone == "calendrier":
                                etat = "menu_saison"
                                zone_selectionnee_saison = "calendrier"
                            elif zone == "entrainements":
                                etat = "entrainements"
                            elif zone == "transferts":
                                etat = "menu_saison"
                            elif zone == "sponsors":
                                etat = "sponsors"
                            elif zone == "selection":
                                if equipe_sauvegardee:
                                    equipe = set(equipe_sauvegardee)  # Recharge équipe sauvegardée
                                else:
                                    equipe = set()
                                etat = "selection"

                                
                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"
                        
                elif etat == "saison":
                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"

                elif etat == "finances":
                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"

                elif etat == "stade":
                    verifier_clic_zone_stade(pos)
                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"
                    elif bouton_confirmer_stade.collidepoint(pos):
                        etat = "menu"
                    if zone_selectionnee == "terrain" and bouton_evolution_stade.collidepoint(pos):
                        print("🚧 Évolution du stade à implémenter ici.")

                if etat == "nom_equipe":
                    if champ_texte.collidepoint(pos):
                        saisie_active = True
                    else:
                        saisie_active = False

                    if bouton_valider.collidepoint(pos):
                        if nom_equipe.strip():
                            initialiser_classement()
                            etat = "selection"
                            message_erreur = ""
                        else:
                            message_erreur = "Veuillez indiquer un nom d'équipe."
                    elif bouton_retour.collidepoint(pos):
                        etat = "menu"

                elif etat == "selection":
                    for poste, rect in boutons_filtre.items():
                        if rect.collidepoint(pos):
                            poste_filtre = poste
                    for i, joueur in enumerate(joueurs):
                        if "rect" in joueur and joueur["rect"].collidepoint(pos):
                            if i not in equipe:
                                if len(equipe) < SELECTIONS_MAX:
                                    equipe.add(i)
                                    message_erreur = ""
                                else:
                                    message_erreur = "Désole ! Maximum 12 joueurs autorisés"
                            elif i in equipe:
                                equipe.remove(i)
                                message_erreur = ""

                    if bouton_valider.collidepoint(pos):
                        if len(equipe) >= 8:
                            equipe_sauvegardee = set(equipe)
                            etat = "mon_equipe"
                            message_erreur = ""
                        else:
                            message_erreur = "Veuillez sélectionner au moins 8 joueurs min."

                    if bouton_retour.collidepoint(pos):
                        equipe.clear()
                        nom_equipe = ""
                        poste_filtre = "Tous"
                        etat = "menu"

                elif etat == "mon_equipe":
                    if bouton_retour.collidepoint(pos):
                        etat = "selection"
                    elif bouton_confirmer.collidepoint(pos):
                        etat = "gestion"
                        
                elif etat == "transferts":
                    if bouton_retour.collidepoint(pos):
                        etat = "gestion"

                elif etat == "sponsors":
                    for rect, nom, duree, montant, bonus in sponsors_boutons:
                        if sponsor_duree_restante == 0 or sponsor_selectionne == nom:
                            if rect.collidepoint(pos):
                                sponsor_selectionne = nom
                                sponsor_duree_restante = duree
                                montant_sponsor_actuel = montant  # ✅ copie exacte du montant affiché
                    if sponsor_selectionne and bouton_confirmer_sponsor.collidepoint(pos):
                        recettes_sponsors += montant_sponsor_actuel  # ✅ utilise la vraie valeur affichée
                        sponsors_signes.append((sponsor_selectionne, montant_sponsor_actuel))
                        print(f"✅ Contrat signé avec {sponsor_selectionne}")
                        sponsor_selectionne = None
                        etat = "gestion"
                    if bouton_retour.collidepoint(pos):
                        sponsor_selectionne = None
                        etat = "gestion"
                        

                elif etat == "match":
                    if bouton_retour.collidepoint(pos):
                        etat = "menu_saison"


                elif etat == "mercato":
                    for bouton, joueur in boutons_achat:
                        if bouton.collidepoint(pos):
                            nouvel_id = max(joueurs.keys()) + 1 if joueurs else 0

                            # Création du joueur acheté
                            nouveau_joueur = {
                                "nom": joueur["nom"],
                                "poste": joueur["poste"],
                                "age": joueur["age"],
                                "pondération": joueur["pondération"],
                                "force": random.randint(50, 100),
                                "defense": random.randint(50, 100),
                                "endurance": random.randint(50, 100),
                                "salaire": joueur["salaire"]
                            }

                            joueurs[nouvel_id] = nouveau_joueur

                           # Ajouter à l'équipe si place disponible
                            if len(equipe) < SELECTIONS_MAX:
                                equipe.add(nouvel_id)
                                print(f"✅ {joueur['nom']} ajouté à l’équipe")
                                print(f"Équipe actuelle : {[joueurs[i]['nom'] for i in equipe]}")
                            else:
                                print("⚠️ Équipe complète (12 joueurs max). Joueur non ajouté à la sélection.")


 
        clock.tick(30)
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()




