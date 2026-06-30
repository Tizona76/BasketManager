import pygame
import random
import math

# =========================
# CONFIG
# =========================
WIDTH, HEIGHT = 1000, 600
FPS = 60
TIME_SCALE = 60.0      # 1 game minute per real second
SHOT_CLOCK_MAX = 24.0
GAME_CLOCK_MAX = 5 * 60.0  # 5-minute demo quarter

RIM_RIGHT = (940, 300)
RIM_LEFT = (60, 300)

OFFENSE_SPOTS_RIGHT = {
    "PG": (720, 300),
    "SG": (780, 200),
    "SF": (780, 400),
    "PF": (930, 140),
    "C":  (880, 330),
}

PLAYER_RADIUS = 10
BALL_RADIUS = 6

# =========================
# INIT
# =========================
pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Basketball Match Simulation")
clock = pygame.time.Clock()
font = pygame.font.SysFont(None, 24)

# =========================
# HELPERS
# =========================
def clamp(v, a, b):
    return max(a, min(b, v))

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])

def normalize(dx, dy):
    d = math.hypot(dx, dy)
    if d == 0:
        return 0, 0
    return dx / d, dy / d

def closest_defender(shooter, defenders):
    return min(defenders, key=lambda d: dist((d.x, d.y), (shooter.x, shooter.y)))

# =========================
# CLASSES
# =========================
class Player:
    def __init__(self, team, role, x, y):
        self.team = team
        self.role = role
        self.x, self.y = x, y
        self.tx, self.ty = x, y
        self.speed = 160
        self.stamina = 1.0
        self.matchup = None

    def update(self, dt):
        dx, dy = self.tx - self.x, self.ty - self.y
        d = math.hypot(dx, dy)
        if d > 1:
            nx, ny = dx / d, dy / d
            self.x += nx * self.speed * self.stamina * dt
            self.y += ny * self.speed * self.stamina * dt
        self.x = clamp(self.x, 40, WIDTH - 40)
        self.y = clamp(self.y, 40, HEIGHT - 40)

    def draw(self):
        color = (0, 120, 255) if self.team == 0 else (220, 60, 60)
        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), PLAYER_RADIUS)

class Ball:
    def __init__(self):
        self.owner = None
        self.x = 0
        self.y = 0
        self.state = "HELD"
        self.t = 0
        self.duration = 1
        self.start = (0, 0)
        self.end = (0, 0)

    def update(self, dt):
        if self.owner:
            self.x = self.owner.x + 8
            self.y = self.owner.y
        elif self.state in ("PASS", "SHOT"):
            self.t += dt
            t = clamp(self.t / self.duration, 0, 1)
            x = self.start[0] + (self.end[0] - self.start[0]) * t
            y = self.start[1] + (self.end[1] - self.start[1]) * t
            if self.state == "SHOT":
                arc = -120 * math.sin(math.pi * t)
                y += arc
            self.x, self.y = x, y

    def draw(self):
        pygame.draw.circle(screen, (255, 140, 0), (int(self.x), int(self.y)), BALL_RADIUS)

# =========================
# GAME SETUP
# =========================
players = []
for role, (x, y) in OFFENSE_SPOTS_RIGHT.items():
    players.append(Player(0, role, x + random.randint(-8, 8), y + random.randint(-8, 8)))
    players.append(Player(1, role, WIDTH - x + random.randint(-8, 8), y + random.randint(-8, 8)))

ball = Ball()
ball.owner = players[0]

offense_team = 0
state = "BRING_UP"
state_timer = 0

shot_clock = SHOT_CLOCK_MAX
game_clock = GAME_CLOCK_MAX
score = [0, 0]

# =========================
# DEFENSE
# =========================
def assign_defense():
    offense = [p for p in players if p.team == offense_team]
    defense = [p for p in players if p.team != offense_team]
    d_by_role = {d.role: d for d in defense}

    for o in offense:
        d = d_by_role[o.role]
        dx, dy = RIM_RIGHT[0] - o.x, RIM_RIGHT[1] - o.y
        nx, ny = normalize(dx, dy)
        d.tx = o.x + nx * 50
        d.ty = o.y + ny * 50

# =========================
# MAIN LOOP
# =========================
running = True
while running:
    dt_real = clock.tick(FPS) / 1000.0
    dt_game = dt_real * TIME_SCALE

    for e in pygame.event.get():
        if e.type == pygame.QUIT:
            running = False

    if game_clock <= 0:
        state = "END"

    if state != "END":
        game_clock -= dt_game
        shot_clock -= dt_game
        if shot_clock <= 0:
            offense_team = 1 - offense_team
            ball.owner = random.choice([p for p in players if p.team == offense_team])
            shot_clock = SHOT_CLOCK_MAX
            state = "BRING_UP"

    assign_defense()

    # =========================
    # STATE MACHINE
    # =========================
    state_timer += dt_real

    if state == "BRING_UP" and state_timer > 1.2:
        state = "ACTION"
        state_timer = 0

    elif state == "ACTION" and state_timer > random.uniform(1.5, 2.5):
        r = random.random()
        if r < 0.5:
            state = "PASS"
            receiver = random.choice([p for p in players if p.team == offense_team and p != ball.owner])
            ball.state = "PASS"
            ball.start = (ball.owner.x, ball.owner.y)
            ball.end = (receiver.x, receiver.y)
            ball.duration = random.uniform(0.25, 0.4)
            ball.owner = None
            target_receiver = receiver
        else:
            state = "SHOT"
            shooter = ball.owner
            defender = closest_defender(shooter, [p for p in players if p.team != offense_team])
            contest = clamp(1 - dist((shooter.x, shooter.y), (defender.x, defender.y)) / 120, 0, 1)
            make_prob = clamp(0.55 - contest * 0.4, 0.05, 0.9)

            ball.state = "SHOT"
            ball.start = (shooter.x, shooter.y)
            ball.end = RIM_RIGHT
            ball.duration = random.uniform(0.8, 1.1)
            ball.owner = None
            shot_make = random.random() < make_prob
            shot_result_timer = 0

    elif state == "PASS" and ball.t >= ball.duration:
        ball.owner = target_receiver
        ball.state = "HELD"
        state = "ACTION"
        state_timer = 0

    elif state == "SHOT":
        shot_result_timer += dt_real
        if shot_result_timer > ball.duration:
            if shot_make:
                score[offense_team] += 2
                offense_team = 1 - offense_team
            # REBOUND
            candidates = sorted(players, key=lambda p: dist((p.x, p.y), RIM_RIGHT))[:4]
            rebounder = random.choice(candidates)
            ball.owner = rebounder
            state = "BRING_UP"
            shot_clock = SHOT_CLOCK_MAX
            state_timer = 0

    # =========================
    # UPDATE
    # =========================
    for p in players:
        p.update(dt_real)
    ball.update(dt_real)

    # =========================
    # DRAW
    # =========================
    screen.fill((90, 140, 210))
    pygame.draw.circle(screen, (255, 255, 255), RIM_RIGHT, 10, 2)

    for p in players:
        p.draw()
    ball.draw()

    ui = font.render(f"{int(game_clock)//60}:{int(game_clock)%60:02d}   SC:{int(shot_clock)}   {score[0]} - {score[1]}", True, (255,255,255))
    screen.blit(ui, (20, 20))

    pygame.display.flip()

pygame.quit()
