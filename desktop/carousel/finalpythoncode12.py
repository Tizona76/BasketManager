import pygame
import math
import sys

# ---------------------------
# INITIAL SETUP
# ---------------------------
pygame.init()
WIDTH, HEIGHT = 1000, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("3D Player Selection Carousel")

clock = pygame.time.Clock()

# ---------------------------
# LOAD BACKGROUND
# ---------------------------
background = pygame.image.load("fond_carousel.jpg")  # ton fichier à toi
background = pygame.transform.scale(background, (WIDTH, HEIGHT))

# ---------------------------
# LOAD PLAYER IMAGES
# ---------------------------
player_paths = [
    "player_card1.png",
    "player_card2.png",
    "player_card3.png",
    "player_card4.png",
]
player_images = [pygame.image.load(path) for path in player_paths]

# Resize all images to a uniform size
CARD_W, CARD_H = 180, 260
player_images = [pygame.transform.smoothscale(img, (CARD_W, CARD_H)) for img in player_images]

num_players = len(player_images)

# Tracks which players are selected
selected = [False] * num_players

# ---------------------------
# CAROUSEL PARAMETERS
# ---------------------------
angle = 0
radius = 180
center_x = WIDTH // 2
center_y = HEIGHT // 2
rotation_speed = 0
scroll_speed = 0.03


# ---------------------------
# DRAW CAROUSEL FUNCTION
# ---------------------------
def draw_carousel(angle):
    screen.blit(background, (0, 0))

    depths = []

    for i, img in enumerate(player_images):
        # Position around a vertical circle
        img_angle = 2 * math.pi * i / num_players + angle
        x = center_x
        y = center_y + radius * math.sin(img_angle)

        # Scale by depth (front = bigger)
        scale = 1 + 0.5 * (1 - (y - center_y) / radius)
        new_w, new_h = int(CARD_W * scale), int(CARD_H * scale)
        scaled = pygame.transform.smoothscale(img, (new_w, new_h))

        rect = scaled.get_rect(center=(x, y))

        depths.append((y, scaled, rect, i))

    # Draw back → front
    depths.sort(key=lambda x: x[0])

    for depth in depths:
        _, scaled, rect, idx = depth

        # Highlight if selected
        if selected[idx]:
            pygame.draw.rect(screen, (255, 215, 0), rect, 5)

        screen.blit(scaled, rect.topleft)

    pygame.display.flip()


# ---------------------------
# HANDLE SELECTION
# ---------------------------
def handle_click(mouse_pos):
    for i, img in enumerate(player_images):
        img_angle = 2 * math.pi * i / num_players + angle
        x = center_x
        y = center_y + radius * math.sin(img_angle)

        scale = 1 + 0.5 * (1 - (y - center_y) / radius)
        new_w, new_h = int(CARD_W * scale), int(CARD_H * scale)
        rect = pygame.Rect(x - new_w // 2, y - new_h // 2, new_w, new_h)

        if rect.collidepoint(mouse_pos):
            selected[i] = not selected[i]


# ---------------------------
# MAIN LOOP
# ---------------------------
running = True
while running:
    clock.tick(60)

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

        # Arrow key rotation
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_LEFT:
                rotation_speed = scroll_speed
            elif event.key == pygame.K_RIGHT:
                rotation_speed = -scroll_speed
        if event.type == pygame.KEYUP:
            if event.key in [pygame.K_LEFT, pygame.K_RIGHT]:
                rotation_speed = 0

        # Mouse wheel rotation
        if event.type == pygame.MOUSEWHEEL:
            angle += event.y * scroll_speed

        # Mouse click to lock/unlock
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                handle_click(event.pos)

    angle += rotation_speed
    draw_carousel(angle)

pygame.quit()
sys.exit()
