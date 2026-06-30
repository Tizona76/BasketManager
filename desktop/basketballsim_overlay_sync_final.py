import pygame
import os
import random
import math
import sys

# =========================
# CONFIG (OVERLAY)
# =========================
WIDTH, HEIGHT = 1000, 600
FPS = 60

# Overlay duration (seconds, real time)
OVERLAY_DURATION = 40.0

# Score target to synchronize with (Home, Away) — replace from Basket Manager
TARGET_SCORE_DEFAULT = (84, 76)

# Stop as soon as both teams reach target
END_ON_TARGET_REACHED = True

# Make the overlay more "highlighty" (faster possessions, slightly higher make%)
HIGHLIGHTS_MODE = True

# Bias possessions towards the team that is behind its target (recommended)
USE_BIAS_POSSESSION = True

# UI debug (score + timer)
SHOW_UI = True

# Background court image (put your full-court asset(s) in images/terrain_simul)
BACKGROUND_DIR = "images/terrain_simul"
# Optional: force a specific file name (e.g. "mon_terrain.png"). Set to None to auto-pick.
BACKGROUND_FILE = False
# If not forcing a file, we prefer files starting with this prefix (e.g. mon_terrain.png)
BACKGROUND_PREFERRED_PREFIX = "mon_terrain"
# If several images exist, we pick the best match; otherwise first one found (png/jpg/webp).
FIT_WINDOW_TO_BACKGROUND = True  # if True: window size == background size; else: background scaled to WIDTHxHEIGHT

# =========================
# COURT / ACTORS
# =========================
RIM_RIGHT = (940, 300)
RIM_LEFT = (60, 300)

OFFENSE_SPOTS_RIGHT = {
    "PG": (720, 300),
    "SG": (780, 200),
    "SF": (780, 400),
    "PF": (930, 140),
    "C":  (880, 330),
}

PLAYER_RADIUS = 20
BALL_RADIUS = 12


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
        return 0.0, 0.0
    return dx / d, dy / d

def closest_defender(shooter, defenders):
    return min(defenders, key=lambda d: dist((d.x, d.y), (shooter.x, shooter.y)))

def target_reached(score, target):
    return score[0] >= target[0] and score[1] >= target[1]

def add_points_clamped(team, score, target, pts=2):
    """
    Adds points without ever exceeding target[team].
    If remaining == 1, adds +1 to support odd scores like 89-75.
    Returns points actually added (0/1/2).
    """
    remaining = int(target[team]) - int(score[team])
    if remaining <= 0:
        return 0
    if remaining == 1:
        score[team] += 1
        return 1
    add = min(int(pts), remaining)
    score[team] += add
    return add

def choose_offense_team_biased(score, target):
    """
    Chooses which team attacks next.
    Bias: team further from its target attacks more often.
    """
    r0 = max(0, int(target[0]) - int(score[0]))
    r1 = max(0, int(target[1]) - int(score[1]))

    if r0 == 0 and r1 == 0:
        return random.choice([0, 1])

    # Small base weight prevents lock-in when one team is at 0 remaining.
    w0 = 0.15 + r0
    w1 = 0.15 + r1
    return 0 if random.random() < (w0 / (w0 + w1)) else 1

def pick_random_owner(players, team):
    team_players = [p for p in players if p.team == team]
    return random.choice(team_players) if team_players else None

def get_attack_rim(team):
    # Team 0 (bleu) attaque à droite, Team 1 (rouge) attaque à gauche
    return RIM_RIGHT if team == 0 else RIM_LEFT

def get_offense_spots(team, spots_right):
    # Team 0 utilise spots_right
    # Team 1 utilise le miroir (gauche) : x -> WIDTH - x
    if team == 0:
        return spots_right
    return {role: (float(WIDTH) - float(x), float(y)) for role, (x, y) in spots_right.items()}

def assign_offense_positions(players, offense_team, spots_right):
    # Place les attaquants sur “leur” demi-terrain (cible tx/ty)
    spots = get_offense_spots(offense_team, spots_right)
    for p in players:
        if p.team == offense_team:
            sx, sy = spots.get(p.role, (p.x, p.y))
            p.tx, p.ty = float(sx), float(sy)

def get_inbound_pos(team, margin=22):
    """
    Position derrière la ligne de fond, sous le panier que l'équipe va défendre
    (donc panier de l'équipe qui vient d'encaisser).
    Team 0 défend à gauche (RIM_LEFT), Team 1 défend à droite (RIM_RIGHT),
    si on garde: team 0 attaque à droite / team 1 attaque à gauche.
    """
    # Si team 0 attaque à droite, alors team 0 défend à gauche
    defend_rim = RIM_LEFT if team == 0 else RIM_RIGHT

    x, y = defend_rim
    # Derrière la ligne de fond : à gauche on décale vers l'extérieur (x - margin),
    # à droite on décale vers l'extérieur (x + margin)
    if defend_rim == RIM_LEFT:
        ix = x - margin
    else:
        ix = x + margin

    # Clamp pour rester dans l'écran
    ix = max(20, min(WIDTH - 20, ix))
    iy = max(40, min(HEIGHT - 40, y))
    return float(ix), float(iy)




# =========================
# CLASSES
# =========================
class Player:
    def __init__(self, team, role, x, y):
        self.team = team
        self.role = role
        self.x, self.y = float(x), float(y)
        self.tx, self.ty = float(x), float(y)
        self.speed = 160.0
        self.stamina = 1.0

    def update(self, dt):
        dx, dy = self.tx - self.x, self.ty - self.y
        d = math.hypot(dx, dy)
        if d > 1:
            nx, ny = dx / d, dy / d
            self.x += nx * self.speed * self.stamina * dt
            self.y += ny * self.speed * self.stamina * dt
        self.x = clamp(self.x, 40, WIDTH - 40)
        self.y = clamp(self.y, 40, HEIGHT - 40)

    def draw(self, screen):
        color = (0, 120, 255) if self.team == 0 else (220, 60, 60)
        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), PLAYER_RADIUS)

class Ball:
    def __init__(self):
        self.owner = None
        self.x = 0.0
        self.y = 0.0
        self.state = "HELD"     # HELD / PASS / SHOT
        self.t = 0.0
        self.duration = 1.0
        self.start = (0.0, 0.0)
        self.end = (0.0, 0.0)

    def start_anim(self, state, start, end, duration):
        self.state = state
        self.start = (float(start[0]), float(start[1]))
        self.end = (float(end[0]), float(end[1]))
        self.duration = max(0.001, float(duration))
        self.t = 0.0
        self.owner = None

    def update(self, dt):
        if self.owner:
            self.x = self.owner.x + 8
            self.y = self.owner.y
        elif self.state in ("PASS", "SHOT"):
            self.t += dt
            t = clamp(self.t / self.duration, 0.0, 1.0)
            x = self.start[0] + (self.end[0] - self.start[0]) * t
            y = self.start[1] + (self.end[1] - self.start[1]) * t
            if self.state == "SHOT":
                arc = -120 * math.sin(math.pi * t)
                y += arc
            self.x, self.y = x, y

    def draw(self, screen):
        pygame.draw.circle(screen, (255, 140, 0), (int(self.x), int(self.y)), BALL_RADIUS)


# =========================
# DEFENSE
# =========================
def assign_defense(players, offense_team):
    offense = [p for p in players if p.team == offense_team]
    defense = [p for p in players if p.team != offense_team]
    d_by_role = {d.role: d for d in defense}

    for o in offense:
        d = d_by_role.get(o.role)
        if not d:
            continue
        rim = get_attack_rim(offense_team)
        dx, dy = rim[0] - o.x, rim[1] - o.y
        nx, ny = normalize(dx, dy)
        d.tx = o.x + nx * 50
        d.ty = o.y + ny * 50


# =========================
# OVERLAY SIM (HOOKABLE)
# =========================
def run_overlay(target_score=None, duration_s=None, highlights=None, bias_possession=None):
    """
    Standalone overlay run.
    Basket Manager hook idea: call run_overlay(target_score=(home, away), duration_s=8.0, highlights=True, bias_possession=True)
    """
    target = list(target_score if target_score is not None else TARGET_SCORE_DEFAULT)
    duration = float(duration_s if duration_s is not None else OVERLAY_DURATION)
    highlights_mode = bool(HIGHLIGHTS_MODE if highlights is None else highlights)
    use_bias = bool(USE_BIAS_POSSESSION if bias_possession is None else bias_possession)

    pygame.init()

    # --- BACKGROUND + RESIZE (full court with two baskets) ---
    bg_surface = None
    bg_path_used = None

    # Resolve background directory relative to THIS script (robust even if you run from another CWD)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    bg_dir_abs = BACKGROUND_DIR
    if not os.path.isabs(bg_dir_abs):
        bg_dir_abs = os.path.join(script_dir, BACKGROUND_DIR)

    try:
        exts = (".png", ".jpg", ".jpeg", ".webp")
        if os.path.isdir(bg_dir_abs):
            names = [n for n in os.listdir(bg_dir_abs) if n.lower().endswith(exts)]
            chosen = None

            # 1) Force exact file if configured
            if BACKGROUND_FILE:
                # Accept exact name, or name without extension (try common image extensions)
                cand = os.path.join(bg_dir_abs, BACKGROUND_FILE)
                if os.path.isfile(cand):
                    chosen = cand
                else:
                    root, ext = os.path.splitext(BACKGROUND_FILE)
                    if ext == "":
                        for _ext in exts:
                            cand2 = os.path.join(bg_dir_abs, root + _ext)
                            if os.path.isfile(cand2):
                                chosen = cand2
                                break

            # 2) Prefer prefix "mon_terrain" (or configured prefix)
            if chosen is None and BACKGROUND_PREFERRED_PREFIX:
                pref = BACKGROUND_PREFERRED_PREFIX.lower()
                pref_matches = [n for n in names if os.path.splitext(n)[0].lower().startswith(pref)]
                if pref_matches:
                    chosen = os.path.join(bg_dir_abs, sorted(pref_matches)[0])

            # 3) Fallback: first image in sorted order
            if chosen is None and names:
                chosen = os.path.join(bg_dir_abs, sorted(names)[0])

            if chosen:
                bg_path_used = chosen
                bg_surface = pygame.image.load(bg_path_used)  # convert after set_mode()
    except Exception as _e:
        print(f"[SIM][BG] load error: {_e}")
        bg_surface = None
        bg_path_used = None

    # Choose window size
    if bg_surface is not None and FIT_WINDOW_TO_BACKGROUND:
        w, h = bg_surface.get_width(), bg_surface.get_height()
    else:
        w, h = WIDTH, HEIGHT

    if bg_surface is None:
        print(f"[SIM] Background NOT loaded. Expected folder: {bg_dir_abs}")
    else:
        print(f"[SIM] Background loaded: {bg_path_used} ({bg_surface.get_width()}x{bg_surface.get_height()})")

    # Apply runtime sizing globally (Player clamp + coordinate scaling)
    globals()["WIDTH"], globals()["HEIGHT"] = int(w), int(h)

    # Scale key court coordinates from the original 1000x600 reference
    base_w, base_h = 1000.0, 600.0
    sx, sy = (w / base_w), (h / base_h)

    def _sp(x, y):
        return (float(x) * sx, float(y) * sy)

    globals()["RIM_RIGHT"] = _sp(940, 300)
    globals()["RIM_LEFT"]  = _sp(60, 300)

    offense_spots_right = {
        "PG": _sp(720, 300),
        "SG": _sp(780, 200),
        "SF": _sp(780, 400),
        "PF": _sp(930, 140),
        "C":  _sp(880, 330),
    }

    # Create window
    screen = pygame.display.set_mode((int(w), int(h)))

    # Convert background to display format now that video mode is set
    if bg_surface is not None:
        try:
            bg_surface = bg_surface.convert()
        except Exception as _e:
            print(f"[SIM][BG] convert error: {_e}")

    pygame.display.set_caption("Basketball Result Overlay (Synced Score)")
    clock = pygame.time.Clock()
    font = pygame.font.SysFont(None, 24)

    # Tuning
    if highlights_mode:
        action_wait_min, action_wait_max = 2.0, 3.4
        pass_chance = 0.35
        pass_dur_min, pass_dur_max = 0.18, 0.30
        shot_dur_min, shot_dur_max = 0.65, 0.90
        make_prob_bonus = 0.08
    else:
        action_wait_min, action_wait_max = 1.5, 2.5
        pass_chance = 0.55
        pass_dur_min, pass_dur_max = 0.25, 0.40
        shot_dur_min, shot_dur_max = 0.80, 1.10
        make_prob_bonus = 0.00

    # Setup players (same as your version)
    players = []
    for role, (x, y) in offense_spots_right.items():
        players.append(Player(0, role, x + random.randint(-8, 8), y + random.randint(-8, 8)))
        players.append(Player(1, role, WIDTH - x + random.randint(-8, 8), y + random.randint(-8, 8)))

    ball = Ball()

    # Overlay score (displayed) starts at 0-0
    score = [0, 0]

    # Possession / state
    offense_team = choose_offense_team_biased(score, target) if use_bias else 0
    ball.owner = pick_random_owner(players, offense_team)

    state = "BRING_UP"
    state_timer = 0.0
    overlay_t = 0.0

    # State-local vars
    target_receiver = None
    shot_make = False
    shot_result_timer = 0.0

    shot_team = None
    shot_rim = None

    inbounder = None
    inbound_timer = 0.0
    INBOUND_DELAY = 0.45  # 0.35 à 0.6s selon le rendu voulu


    running = True
    while running:
        dt_real = clock.tick(FPS) / 1000.0
        overlay_t += dt_real

        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                running = False

        # End conditions
        if overlay_t >= duration:
            state = "END"
        if END_ON_TARGET_REACHED and target_reached(score, target):
            state = "END"

        if state == "END":
            # one last draw frame (still responsive)
            pass
        else:
            # Defense aligns on offense
            assign_defense(players, offense_team)
            assign_offense_positions(players, offense_team, offense_spots_right)


            # =========================
            # STATE MACHINE
            # =========================
            state_timer += dt_real

            if state == "BRING_UP" and state_timer > 1.4:
                state = "ACTION"
                state_timer = 0.0

            elif state == "ACTION" and state_timer > random.uniform(action_wait_min, action_wait_max):
                # If offense already reached target, force a "stall" / miss by switching possession
                if score[offense_team] >= target[offense_team]:
                    offense_team = choose_offense_team_biased(score, target) if use_bias else (1 - offense_team)
                    ball.owner = pick_random_owner(players, offense_team)
                    state = "BRING_UP"
                    state_timer = 0.0
                else:
                    r = random.random()
                    if r < pass_chance and ball.owner is not None:
                        state = "PASS"
                        receiver = random.choice([p for p in players if p.team == offense_team and p != ball.owner])
                        target_receiver = receiver
                        ball.start_anim(
                            "PASS",
                            start=(ball.owner.x, ball.owner.y),
                            end=(receiver.x, receiver.y),
                            duration=random.uniform(pass_dur_min, pass_dur_max),
                        )
                    else:
                        state = "SHOT"
                        shot_team = offense_team
                        shot_rim = get_attack_rim(offense_team)

                        shooter = ball.owner
                        if shooter is None:
                            # Safety: if no owner, re-pick owner for offense
                            ball.owner = pick_random_owner(players, offense_team)
                            shooter = ball.owner

                        defender = closest_defender(shooter, [p for p in players if p.team != offense_team])
                        contest = clamp(1 - dist((shooter.x, shooter.y), (defender.x, defender.y)) / 120, 0, 1)

                        make_prob = clamp(0.55 - contest * 0.4 + make_prob_bonus, 0.05, 0.95)

                        # If this team already reached its target, force miss
                        if score[offense_team] >= target[offense_team]:
                            shot_make = False
                        else:
                            shot_make = (random.random() < make_prob)

                        ball.start_anim(
                            "SHOT",
                            start=(shooter.x, shooter.y),
                            end=shot_rim,

                            duration=random.uniform(shot_dur_min, shot_dur_max),
                        )
                        shot_result_timer = 0.0

                    state_timer = 0.0

            elif state == "PASS":
                # Finish pass when animation ends
                if ball.t >= ball.duration:
                    ball.owner = target_receiver
                    ball.state = "HELD"
                    state = "ACTION"
                    state_timer = 0.0

            elif state == "INBOUND":
                inbound_timer += dt_real
                # pendant ce court délai, la défense a le temps de revenir
                if inbound_timer >= INBOUND_DELAY:
                    state = "BRING_UP"
                    state_timer = 0.0

            elif state == "SHOT":
                shot_result_timer += dt_real
                if shot_result_timer >= ball.duration:

                    # IMPORTANT : on fige le "panier du tir" AVANT de modifier offense_team
                    rim_shot = get_attack_rim(offense_team)

                    if shot_make:
                        added = add_points_clamped(offense_team, score, target, pts=2)
                        if added > 0:
                            # panier marqué -> l'équipe adverse récupère
                            offense_team = 1 - offense_team

                            # INBOUND : un joueur de l'équipe qui récupère se place derrière la ligne de fond
                            inbounder = pick_random_owner(players, offense_team)
                            if inbounder is not None:
                                ix, iy = get_inbound_pos(offense_team, margin=28)
                                inbounder.x, inbounder.y = ix, iy
                                inbounder.tx, inbounder.ty = ix, iy

                                ball.owner = inbounder
                                ball.state = "HELD"

                                state = "INBOUND"
                                inbound_timer = 0.0
                                state_timer = 0.0
                                # On sort immédiatement du bloc SHOT (pas de rebond dans ce cas)
                                continue


                    # REBOUND (toujours près du panier du tir)
                    candidates = sorted(players, key=lambda p: dist((p.x, p.y), rim_shot))[:4]
                    rebounder = random.choice(candidates) if candidates else None

                    # Si tir raté : la possession dépend du rebondeur
                    if (not shot_make) and rebounder is not None:
                        offense_team = rebounder.team

                    # Si tu veux garder le bias, applique-le uniquement sur les possessions "neutres"
                    # (donc PAS après un panier marqué), et pas s'il y a un rebondeur qui fixe la possession.
                    if use_bias and (not shot_make) and rebounder is None:
                        offense_team = choose_offense_team_biased(score, target)

                    ball.owner = pick_random_owner(players, offense_team) or rebounder

                    state = "BRING_UP"
                    state_timer = 0.0


        # =========================
        # UPDATE
        # =========================
        for p in players:
            p.update(dt_real)
        ball.update(dt_real)

        # =========================
        # DRAW
        # =========================
        if bg_surface is not None:
            if FIT_WINDOW_TO_BACKGROUND:
                screen.blit(bg_surface, (0, 0))
            else:
                screen.blit(pygame.transform.smoothscale(bg_surface, (int(w), int(h))), (0, 0))
        else:
            screen.fill((90, 140, 210))

        for p in players:
            p.draw(screen)
        ball.draw(screen)

        if SHOW_UI:
            ui = font.render(f"{score[0]} - {score[1]}", True, (255,255,255))
            screen.blit(ui, (20, 20))


        pygame.display.flip()

    pygame.quit()
    return tuple(score)


# =========================
# CLI (optional)
# =========================
if __name__ == "__main__":
    # Usage examples:
    #   python basketballsim_overlay_sync.py
    #   python basketballsim_overlay_sync.py 92 88 10
    #   python basketballsim_overlay_sync.py 92 88 10 --no-highlights --no-bias
    args = [a.strip() for a in sys.argv[1:]]
    home = None
    away = None
    dur = None
    highlights = None
    bias = None

    # flags
    if "--no-highlights" in args:
        highlights = False
        args.remove("--no-highlights")
    if "--highlights" in args:
        highlights = True
        args.remove("--highlights")
    if "--no-bias" in args:
        bias = False
        args.remove("--no-bias")
    if "--bias" in args:
        bias = True
        args.remove("--bias")

    # positional: home away duration
    try:
        if len(args) >= 2:
            home = int(args[0])
            away = int(args[1])
        if len(args) >= 3:
            dur = float(args[2])
    except Exception:
        home = None
        away = None
        dur = None

    target = (home, away) if (home is not None and away is not None) else None
    run_overlay(target_score=target, duration_s=dur, highlights=highlights, bias_possession=bias)
