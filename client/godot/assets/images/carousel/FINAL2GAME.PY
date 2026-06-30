import pygame
import math
import sys
import os 

pygame.init()

# -------------------------------------------------------
# SCREEN SETUP
# -------------------------------------------------------
WIDTH, HEIGHT = 1280, 720
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("WOW Player Carousel")

clock = pygame.time.Clock()

# -------------------------------------------------------
# LOAD BACKGROUND IMAGE
# -------------------------------------------------------
BASE_DIR = os.path.dirname(__file__)  # dossier où se trouve FINAL2GAME.PY
BACKGROUND_PATH = os.path.join(BASE_DIR, "fond_carousel.jpg")  # adapte le nom si besoin
background = pygame.image.load(BACKGROUND_PATH)
background = pygame.transform.scale(background, (WIDTH, HEIGHT))


# -------------------------------------------------------
# LOAD PLAYER CARD IMAGE
# (You can duplicate this image for 10–20 cards)
# -------------------------------------------------------
PLAYER_IMAGE_PATH = os.path.join(BASE_DIR, "player_card.png") 

# Load multiple players (duplicate same image for demo)
player_images = []
for i in range(12):   # Example: 12 players
    img = pygame.image.load(PLAYER_IMAGE_PATH).convert_alpha()
    img = pygame.transform.scale(img, (220, 320))  # default card size
    player_images.append(img)

num_players = len(player_images)

# Track selected cards (True/False)
selected = [False] * num_players

# -------------------------------------------------------
# CAROUSEL PARAMETERS
# -------------------------------------------------------
angle = 0
radius = 350  # how far left-right cards spread
center_x = WIDTH // 2
center_y = HEIGHT // 2 + 40
rotation_speed = 0
wheel_speed = 0.06  # mouse wheel speed

# Glow for selected cards
GLOW_COLOR = (255, 215, 0)  # gold


# -------------------------------------------------------
# DRAW CAROUSEL FUNCTION
# -------------------------------------------------------
def draw_carousel(angle):
    screen.blit(background, (0, 0))

    depth_order = []

    for i in range(num_players):
        # Circular horizontal rotation
        img_angle = 2 * math.pi * i / num_players + angle

        # Horizontal elliptical path
        x = center_x + radius * math.sin(img_angle)
        y = center_y + radius * math.cos(img_angle) * 0.15  # light vertical tilt

        # Scale based on how "front" the card is
        scale_factor = 1 + 0.6 * (1 - (y - center_y) / radius)
        w = int(220 * scale_factor)
        h = int(320 * scale_factor)

        img_scaled = pygame.transform.scale(player_images[i], (w, h))
        rect = img_scaled.get_rect(center=(x, y))

        # Store for correct draw order (far → near)
        depth_order.append((y, img_scaled, rect, i))

    # Draw back-to-front
    depth_order.sort(key=lambda item: item[0])

    for y, img_scaled, rect, idx in depth_order:
        screen.blit(img_scaled, rect.topleft)

        # Draw glow if selected
        if selected[idx]:
            pygame.draw.rect(screen, GLOW_COLOR, rect, 5)

    pygame.display.update()


# -------------------------------------------------------
# CLICK HANDLER
# Sélectionne la carte la plus "devant" sous la souris
# -------------------------------------------------------
def handle_click(mouse_pos):
    depth_order = []

    # On recalcule la position et l'échelle de CHAQUE carte,
    # exactement comme dans draw_carousel()
    for i in range(num_players):
        img_angle = 2 * math.pi * i / num_players + angle

        # mêmes formules que dans draw_carousel
        x = center_x + radius * math.sin(img_angle)
        y = center_y + radius * math.cos(img_angle) * 0.15

        scale_factor = 1 + 0.6 * (1 - (y - center_y) / radius)
        w = int(220 * scale_factor)
        h = int(320 * scale_factor)

        rect = pygame.Rect(0, 0, w, h)
        rect.center = (x, y)

        # y = profondeur ; plus y est grand, plus la carte est "devant"
        depth_order.append((y, rect, i))

    # On trie du plus loin au plus près
    depth_order.sort(key=lambda item: item[0])

    # On parcourt de la carte la PLUS DEVANT vers la PLUS LOIN
    for y, rect, idx in reversed(depth_order):
        if rect.collidepoint(mouse_pos):
            selected[idx] = not selected[idx]
            break  # on s'arrête à la première carte devant sous la souris


# -------------------------------------------------------
# MAIN LOOP
# -------------------------------------------------------
running = True
while running:
    clock.tick(60)

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

        # Arrow keys
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_LEFT:
                rotation_speed = 0.05
            if event.key == pygame.K_RIGHT:
                rotation_speed = -0.05

        if event.type == pygame.KEYUP:
            if event.key in (pygame.K_LEFT, pygame.K_RIGHT):
                rotation_speed = 0

        # Mouse wheel scroll
        if event.type == pygame.MOUSEWHEEL:
            angle += wheel_speed * event.y

        # Mouse click for selection
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # left click
                handle_click(event.pos)

    angle += rotation_speed
    draw_carousel(angle)

pygame.quit()
sys.exit()
