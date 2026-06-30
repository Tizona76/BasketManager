import pygame
import random
import math

# ---------------- CONFIG ----------------
WIDTH, HEIGHT = 1000, 600
FPS = 60
TIME_SCALE = 30   # 1 real second = 30 game seconds

RIM_RIGHT = (940, 300)
COURT_RECT = pygame.Rect(40, 40, 920, 520)

OFFENSE_SPOTS_RIGHT = {
    "PG": (720, 300),
    "SG": (780, 200),
    "SF": (780, 400),
    "PF": (930, 140),
    "C":  (880, 330),
}

# ----------------------------------------

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Basketball Highlight Simulation")
clock = pygame.time.Clock()
font = pygame.font.SysFont(None, 28)

# ---------------- UTIL ----------------
def clamp(v, a, b): return max(a, min(v, b))
def dist(a, b): return math.hypot(a[0]-b[0], a[1]-b[1])
def normalize(v):
    l = math.hypot(v[0], v[1])
    return (v[0]/l, v[1]/l) if l else (0,0)

# ---------------- CLASSES ----------------
class Player:
    def __init__(self, team, role, x, y):
        self.team = team
        self.role = role
        self.x, self.y = x, y
        self.target = (x, y)
        self.speed = 140
        self.stamina = 1.0

    def update(self, dt):
        dx, dy = self.target[0]-self.x, self.target[1]-self.y
        d = math.hypot(dx, dy)
        if d > 2:
            vx, vy = dx/d, dy/d
            self.x += vx * self.speed * self.stamina * dt
            self.y += vy * self.speed * self.stamina * dt
        self.x = clamp(self.x, COURT_RECT.left, COURT_RECT.right)
        self.y = clamp(self.y, COURT_RECT.top, COURT_RECT.bottom)

    def draw(self):
        color = (50,120,255) if self.team=="A" else (220,80,80)
        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), 12)

class Ball:
    def __init__(self):
        self.owner = None
        self.x, self.y = 0,0
        self.vx, self.vy = 0,0

    def update(self, dt):
        if self.owner:
            self.x = self.owner.x + 10
            self.y = self.owner.y
        else:
            self.x += self.vx * dt
            self.y += self.vy * dt
            self.vx *= 0.98
            self.vy *= 0.98

    def draw(self):
        pygame.draw.circle(screen, (255,150,0), (int(self.x), int(self.y)), 6)

# ---------------- SETUP ----------------
players = []
for role, pos in OFFENSE_SPOTS_RIGHT.items():
    players.append(Player("A", role, pos[0]+random.randint(-10,10), pos[1]+random.randint(-10,10)))
    players.append(Player("B", role, pos[0]-120, pos[1]))

ball = Ball()
offense_team = "A"
state = "INBOUND"
state_timer = 0

game_clock = 12 * 60
shot_clock = 24

# ---------------- STATE LOGIC ----------------
def reset_possession():
    global offense_team
    for p in players:
        if p.team == offense_team:
            base = OFFENSE_SPOTS_RIGHT[p.role]
            p.x, p.y = base
            p.target = base
    ball.owner = next(p for p in players if p.team==offense_team and p.role=="PG")

def assign_defense():
    attackers = [p for p in players if p.team==offense_team]
    defenders = [p for p in players if p.team!=offense_team]
    for a,d in zip(attackers, defenders):
        v = normalize((RIM_RIGHT[0]-a.x, RIM_RIGHT[1]-a.y))
        d.target = (a.x + v[0]*35, a.y + v[1]*35)

# ---------------- MAIN LOOP ----------------
running = True
reset_possession()

while running:
    dt_real = clock.tick(FPS)/1000
    dt_game = dt_real * TIME_SCALE

    for e in pygame.event.get():
        if e.type == pygame.QUIT:
            running = False

    game_clock -= dt_game
    shot_clock -= dt_game
    state_timer += dt_game

    if state == "INBOUND":
        reset_possession()
        state = "BRING_UP"
        state_timer = 0

    elif state == "BRING_UP" and state_timer > 2:
        state = "ACTION"
        state_timer = 0

    elif state == "ACTION":
        assign_defense()
        if state_timer > random.uniform(2,3):
            shooter = ball.owner
            d = dist((shooter.x, shooter.y), RIM_RIGHT)
            contest = min(1, dist((shooter.x, shooter.y), (players[1].x, players[1].y))/80)
            make = random.random() < clamp((1-d/400)*contest, 0.05, 0.6)
            ball.owner = None
            ball.vx = (RIM_RIGHT[0]-shooter.x)*2
            ball.vy = (RIM_RIGHT[1]-shooter.y)*2
            state = "REBOUND"
            state_timer = 0

    elif state == "REBOUND" and state_timer > 1:
        rebounder = random.choice(players)
        ball.owner = rebounder
        offense_team = rebounder.team
        state = "INBOUND"
        state_timer = 0

    for p in players:
        p.update(dt_real)
    ball.update(dt_real)

    # ---------------- DRAW ----------------
    screen.fill((120,170,255))
    pygame.draw.circle(screen, (255,80,80), RIM_RIGHT, 8)
    for p in players: p.draw()
    ball.draw()

    ui = font.render(f"Clock {int(game_clock)}  Shot {int(shot_clock)}  State {state}", True, (0,0,0))
    screen.blit(ui, (20,10))
    pygame.display.flip()

pygame.quit()
