import pygame
import sys
import os

pygame.init()

# --- Fenêtre ---
LARGEUR, HAUTEUR = 1280, 720
FENETRE = pygame.display.set_mode((LARGEUR, HAUTEUR))
pygame.display.set_caption("Demo popup Blasons débloqués")

# --- Couleurs ---
BLANC = (255, 255, 255)
NOIR = (0, 0, 0)
JAUNE = (240, 200, 40)
GRIS_FOND = (20, 25, 35)

# --- Polices ---
pygame.font.init()
FONT = pygame.font.SysFont("arial", 22)
POLICE_MOYENNE_BOLD = pygame.font.SysFont("arial", 26, bold=True)
POLICE_PETITE = pygame.font.SysFont("arial", 20)

clock = pygame.time.Clock()

# Flag comme dans le vrai jeu
popup_blasons_debloques = True

# --- Chargement de l'image blason_or ---
# Adapte ce chemin / extension si besoin (ex: "images/blason_or.png")
BLASON_OR_PATH = os.path.join("images", "blasons", "blason_or.png")
blason_or_img = None
try:
    img = pygame.image.load(BLASON_OR_PATH).convert_alpha()
    # On le scale pour qu'il reste petit dans le popup
    blason_or_img = pygame.transform.smoothscale(img, (44, 44))
    print(f"[OK] blason_or chargé : {BLASON_OR_PATH}")
except Exception as e:
    print(f"[WARN] Impossible de charger {BLASON_OR_PATH} : {e}")
    blason_or_img = None


def dessiner_popup_blasons(surface):
    """Reproduction du bloc popup_blasons_debloques dans un contexte minimal."""
    L, H = surface.get_size()

    # Fond sombre semi-transparent
    overlay = pygame.Surface((L, H), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 160))
    surface.blit(overlay, (0, 0))

    # Carte centrale
    popup_w, popup_h = 520, 230
    popup_rect = pygame.Rect(0, 0, popup_w, popup_h)
    popup_rect.center = (L // 2, H // 2)

    pygame.draw.rect(surface, BLANC, popup_rect, border_radius=18)
    pygame.draw.rect(surface, NOIR, popup_rect, 2, border_radius=18)

    # Petit "blason" doré : image si dispo, sinon cercle
    centre_x = popup_rect.x + 48
    centre_y = popup_rect.y + 40

    if blason_or_img is not None:
        img_rect = blason_or_img.get_rect(center=(centre_x, centre_y))
        surface.blit(blason_or_img, img_rect.topleft)
    else:
        pygame.draw.circle(surface, JAUNE, (centre_x, centre_y), 22)
        pygame.draw.circle(surface, NOIR, (centre_x, centre_y), 22, 2)

    # Titre
    titre = POLICE_MOYENNE_BOLD.render("NOUVEAU : Blasons débloqués !", True, NOIR)
    surface.blit(titre, (popup_rect.x + 80, popup_rect.y + 26))

    # Texte explicatif
    ligne1 = POLICE_PETITE.render(
        "Tu peux maintenant choisir un blason pour ton club.", True, NOIR
    )
    ligne2 = POLICE_PETITE.render(
        "Va dans Équipe > Blason du club pour le personnaliser.", True, NOIR
    )

    surface.blit(ligne1, (popup_rect.x + 40, popup_rect.y + 90))
    surface.blit(ligne2, (popup_rect.x + 40, popup_rect.y + 120))


def main():
    global popup_blasons_debloques

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

            # clic gauche n'importe où pour fermer le popup
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if popup_blasons_debloques:
                    popup_blasons_debloques = False

        # Fond de l'écran (simule un écran du jeu)
        FENETRE.fill(GRIS_FOND)

        # Texte de fond pour se repérer
        titre_fond = FONT.render("Ecran de jeu (fond) - Demo popup Blasons", True, BLANC)
        FENETRE.blit(titre_fond, (20, 20))

        if popup_blasons_debloques:
            dessiner_popup_blasons(FENETRE)

        pygame.display.flip()
        clock.tick(60)


if __name__ == "__main__":
    main()
