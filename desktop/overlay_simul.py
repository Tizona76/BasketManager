import os
import random
import math
import pygame

"""
overlay_simul.py

Module "embeddable" pour Basket Manager.
- AUCUN pygame.display.set_mode()
- AUCUNE boucle d'events interne
- update(dt) + draw(surface) uniquement
- Dessine dans une surface fournie (ex: un rect "zone grise" de l'overlay)
"""

# =========================
# Helpers
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
    Ajoute des points sans jamais dépasser target[team].
    Supporte les scores impairs (+1 si remaining == 1).
    Retourne les points réellement ajoutés (0/1/2).
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
    Bias: l'équipe la plus en retard attaque plus souvent.
    """
    r0 = max(0, int(target[0]) - int(score[0]))
    r1 = max(0, int(target[1]) - int(score[1]))

    if r0 == 0 and r1 == 0:
        return random.choice([0, 1])

    w0 = 0.15 + r0
    w1 = 0.15 + r1
    return 0 if random.random() < (w0 / (w0 + w1)) else 1

def get_attack_rim(team, rim_right, rim_left):
    # Team 0 (bleu) attaque à droite, Team 1 (rouge) attaque à gauche
    return rim_right if team == 0 else rim_left

def get_inbound_pos(team, rim_right, rim_left, width, height, margin=22):
    """
    Position derrière la ligne de fond sous le panier que l'équipe va défendre.
    Si team 0 attaque à droite, alors team 0 défend à gauche; team 1 défend à droite.
    """
    defend_rim = rim_left if team == 0 else rim_right
    x, y = defend_rim
    if defend_rim == rim_left:
        ix = x - margin
    else:
        ix = x + margin

    ix = max(20, min(width - 20, ix))
    iy = max(40, min(height - 40, y))
    return float(ix), float(iy)

def mirror_spots_left(spots_right, width):
    # Miroir: x -> width - x
    return {role: (float(width) - float(x), float(y)) for role, (x, y) in spots_right.items()}

# =========================
# Actor classes
# =========================
class Player:
    def __init__(self, team, role, x, y, width, height, radius=20):
        self.team = team
        self.role = role
        self.x, self.y = float(x), float(y)
        self.tx, self.ty = float(x), float(y)
        self.speed = 160.0
        self.stamina = 1.0
        self._w = int(width)
        self._h = int(height)
        self._radius = int(radius)

    def set_bounds(self, width, height):
        self._w = int(width)
        self._h = int(height)

    def set_radius(self, radius):
        self._radius = int(radius)

    def update(self, dt):
        dx, dy = self.tx - self.x, self.ty - self.y
        d = math.hypot(dx, dy)
        if d > 1:
            nx, ny = dx / d, dy / d
            self.x += nx * self.speed * self.stamina * dt
            self.y += ny * self.speed * self.stamina * dt
        self.x = clamp(self.x, 40, self._w - 40)
        self.y = clamp(self.y, 40, self._h - 40)

    def draw(self, surf):
        color = (0, 120, 255) if self.team == 0 else (220, 60, 60)
        pygame.draw.circle(surf, color, (int(self.x), int(self.y)), self._radius)

class Ball:
    def __init__(self, radius=12):
        self.owner = None
        self.x = 0.0
        self.y = 0.0
        self.state = "HELD"     # HELD / PASS / SHOT
        self.t = 0.0
        self.duration = 1.0
        self.start = (0.0, 0.0)
        self.end = (0.0, 0.0)
        self._radius = int(radius)

    def set_radius(self, radius):
        self._radius = int(radius)

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

    def draw(self, surf):
        pygame.draw.circle(surf, (255, 140, 0), (int(self.x), int(self.y)), self._radius)

# =========================
# Main embeddable class
# =========================
class MatchSimOverlay:
    """
    Classe embeddable :
      - instanciation au début du "score_roll" (40s)
      - update(dt) à chaque frame
      - draw(surface) à chaque frame dans la zone grise
      - done == True => stop / passer aux stats

    IMPORTANT :
      - draw() ne modifie PAS l'état global du jeu
      - update() ne dépend que de dt et de l'état interne
      - aucun appel à pygame.display / event loop
    """

    def __init__(
        self,
        size,
        target_score,
        duration_s=40.0,
        end_on_target=True,
        highlights=True,
        use_bias=True,
        show_ui=False,
        background_dir="images/terrain_simul",
        background_file=None,
        preferred_prefix="mon_terrain",
        fit_bg=True,
        player_radius=20,
        ball_radius=12,
    ):
        self.w, self.h = int(size[0]), int(size[1])
        self.target = [int(target_score[0]), int(target_score[1])]
        self.duration = float(duration_s)
        self.end_on_target = bool(end_on_target)
        self.highlights = bool(highlights)
        self.use_bias = bool(use_bias)
        self.show_ui = bool(show_ui)

        self.player_radius = int(player_radius)
        self.ball_radius = int(ball_radius)

        # Background
        self.bg_surface = None
        self.fit_bg = bool(fit_bg)
        self._bg_scaled_cache = None
        self._bg_scaled_size = None
        self._bg_path = None
        self._load_background(background_dir, background_file, preferred_prefix)

        # Court scaling from base 1000x600 -> local surface size
        self._setup_court()

        # Actors
        self.players = []
        self.ball = Ball(radius=self.ball_radius)
        self._setup_players()

        # Score displayed
        self.score = [0, 0]

        # Possession / state machine
        self.offense_team = choose_offense_team_biased(self.score, self.target) if self.use_bias else 0
        self.ball.owner = self._pick_random_owner(self.offense_team)

        self.state = "BRING_UP"
        self.state_timer = 0.0
        self.overlay_t = 0.0

        self.target_receiver = None
        self.shot_make = False
        self.shot_result_timer = 0.0

        self.inbound_timer = 0.0
        self.INBOUND_DELAY = 0.45

        # Tuning
        if self.highlights:
            self.action_wait_min, self.action_wait_max = 2.0, 3.4
            self.pass_chance = 0.35
            self.pass_dur_min, self.pass_dur_max = 0.18, 0.30
            self.shot_dur_min, self.shot_dur_max = 0.65, 0.90
            self.make_prob_bonus = 0.08
        else:
            self.action_wait_min, self.action_wait_max = 1.5, 2.5
            self.pass_chance = 0.55
            self.pass_dur_min, self.pass_dur_max = 0.25, 0.40
            self.shot_dur_min, self.shot_dur_max = 0.80, 1.10
            self.make_prob_bonus = 0.00

        # One font cached (optional)
        self._font = None

    @property
    def done(self):
        if self.overlay_t >= self.duration:
            return True
        if self.end_on_target and target_reached(self.score, self.target):
            return True
        return False

    def get_score(self):
        return (int(self.score[0]), int(self.score[1]))

    def update(self, dt_real):
        if self.done:
            return

        dt = float(dt_real)
        self.overlay_t += dt

        # Align defense + offense each frame
        self._assign_defense()
        self._assign_offense_positions()

        # State machine
        self.state_timer += dt

        if self.state == "BRING_UP" and self.state_timer > 1.4:
            self.state = "ACTION"
            self.state_timer = 0.0

        elif self.state == "ACTION" and self.state_timer > random.uniform(self.action_wait_min, self.action_wait_max):
            if self.score[self.offense_team] >= self.target[self.offense_team]:
                self.offense_team = choose_offense_team_biased(self.score, self.target) if self.use_bias else (1 - self.offense_team)
                self.ball.owner = self._pick_random_owner(self.offense_team)
                self.state = "BRING_UP"
                self.state_timer = 0.0
            else:
                r = random.random()
                if r < self.pass_chance and self.ball.owner is not None:
                    self.state = "PASS"
                    receiver = random.choice([p for p in self.players if p.team == self.offense_team and p != self.ball.owner])
                    self.target_receiver = receiver
                    self.ball.start_anim(
                        "PASS",
                        start=(self.ball.owner.x, self.ball.owner.y),
                        end=(receiver.x, receiver.y),
                        duration=random.uniform(self.pass_dur_min, self.pass_dur_max),
                    )
                else:
                    self.state = "SHOT"
                    shooter = self.ball.owner
                    if shooter is None:
                        self.ball.owner = self._pick_random_owner(self.offense_team)
                        shooter = self.ball.owner

                    defenders = [p for p in self.players if p.team != self.offense_team]
                    defender = closest_defender(shooter, defenders)
                    contest = clamp(1 - dist((shooter.x, shooter.y), (defender.x, defender.y)) / 120, 0, 1)
                    make_prob = clamp(0.55 - contest * 0.4 + self.make_prob_bonus, 0.05, 0.95)

                    if self.score[self.offense_team] >= self.target[self.offense_team]:
                        self.shot_make = False
                    else:
                        self.shot_make = (random.random() < make_prob)

                    rim = get_attack_rim(self.offense_team, self.rim_right, self.rim_left)
                    self.ball.start_anim(
                        "SHOT",
                        start=(shooter.x, shooter.y),
                        end=rim,
                        duration=random.uniform(self.shot_dur_min, self.shot_dur_max),
                    )
                    self.shot_result_timer = 0.0

                self.state_timer = 0.0

        elif self.state == "PASS":
            if self.ball.t >= self.ball.duration:
                self.ball.owner = self.target_receiver
                self.ball.state = "HELD"
                self.state = "ACTION"
                self.state_timer = 0.0

        elif self.state == "INBOUND":
            self.inbound_timer += dt
            if self.inbound_timer >= self.INBOUND_DELAY:
                self.state = "BRING_UP"
                self.state_timer = 0.0

        elif self.state == "SHOT":
            self.shot_result_timer += dt
            if self.shot_result_timer >= self.ball.duration:
                rim_shot = get_attack_rim(self.offense_team, self.rim_right, self.rim_left)

                if self.shot_make:
                    added = add_points_clamped(self.offense_team, self.score, self.target, pts=2)
                    if added > 0:
                        self.offense_team = 1 - self.offense_team

                        inbounder = self._pick_random_owner(self.offense_team)
                        if inbounder is not None:
                            ix, iy = get_inbound_pos(self.offense_team, self.rim_right, self.rim_left, self.w, self.h, margin=28)
                            inbounder.x, inbounder.y = ix, iy
                            inbounder.tx, inbounder.ty = ix, iy

                            self.ball.owner = inbounder
                            self.ball.state = "HELD"

                            self.state = "INBOUND"
                            self.inbound_timer = 0.0
                            self.state_timer = 0.0

                            self._update_actors(dt)
                            return

                candidates = sorted(self.players, key=lambda p: dist((p.x, p.y), rim_shot))[:4]
                rebounder = random.choice(candidates) if candidates else None

                if (not self.shot_make) and rebounder is not None:
                    self.offense_team = rebounder.team

                if self.use_bias and (not self.shot_make) and rebounder is None:
                    self.offense_team = choose_offense_team_biased(self.score, self.target)

                self.ball.owner = self._pick_random_owner(self.offense_team) or rebounder

                self.state = "BRING_UP"
                self.state_timer = 0.0

        self._update_actors(dt)

    def draw(self, surface):
        # Background
        if self.bg_surface is not None:
            if self.fit_bg and self.bg_surface.get_size() == (self.w, self.h):
                surface.blit(self.bg_surface, (0, 0))
            else:
                if self._bg_scaled_cache is None or self._bg_scaled_size != (self.w, self.h):
                    self._bg_scaled_cache = pygame.transform.smoothscale(self.bg_surface, (self.w, self.h))
                    self._bg_scaled_size = (self.w, self.h)
                surface.blit(self._bg_scaled_cache, (0, 0))
        else:
            surface.fill((90, 140, 210))

        for p in self.players:
            p.draw(surface)
        self.ball.draw(surface)

        if self.show_ui:
            if self._font is None:
                self._font = pygame.font.SysFont(None, 24)
            ui = self._font.render(f"{self.score[0]} - {self.score[1]}", True, (255, 255, 255))
            surface.blit(ui, (10, 10))

    def _load_background(self, background_dir, background_file, preferred_prefix):
        module_dir = os.path.dirname(os.path.abspath(__file__))
        bg_dir_abs = background_dir
        if not os.path.isabs(bg_dir_abs):
            bg_dir_abs = os.path.join(module_dir, bg_dir_abs)

        exts = (".png", ".jpg", ".jpeg", ".webp")
        chosen = None

        try:
            if os.path.isdir(bg_dir_abs):
                names = [n for n in os.listdir(bg_dir_abs) if n.lower().endswith(exts)]

                if background_file:
                    cand = os.path.join(bg_dir_abs, background_file)
                    if os.path.isfile(cand):
                        chosen = cand
                    else:
                        root, ext = os.path.splitext(background_file)
                        if ext == "":
                            for _ext in exts:
                                cand2 = os.path.join(bg_dir_abs, root + _ext)
                                if os.path.isfile(cand2):
                                    chosen = cand2
                                    break

                if chosen is None and preferred_prefix:
                    pref = str(preferred_prefix).lower()
                    pref_matches = [n for n in names if os.path.splitext(n)[0].lower().startswith(pref)]
                    if pref_matches:
                        chosen = os.path.join(bg_dir_abs, sorted(pref_matches)[0])

                if chosen is None and names:
                    chosen = os.path.join(bg_dir_abs, sorted(names)[0])

            if chosen:
                self._bg_path = chosen
                self.bg_surface = pygame.image.load(chosen)
        except Exception:
            self.bg_surface = None
            self._bg_path = None

    def _setup_court(self):
        base_w, base_h = 1000.0, 600.0
        sx, sy = (self.w / base_w), (self.h / base_h)

        def _sp(x, y):
            return (float(x) * sx, float(y) * sy)

        self.rim_right = _sp(940, 300)
        self.rim_left  = _sp(60, 300)

        self.offense_spots_right = {
            "PG": _sp(720, 300),
            "SG": _sp(780, 200),
            "SF": _sp(780, 400),
            "PF": _sp(930, 140),
            "C":  _sp(880, 330),
        }
        self.offense_spots_left = mirror_spots_left(self.offense_spots_right, self.w)

    def _setup_players(self):
        self.players = []
        for role, (x, y) in self.offense_spots_right.items():
            self.players.append(Player(0, role, x + random.randint(-8, 8), y + random.randint(-8, 8), self.w, self.h, radius=self.player_radius))
            self.players.append(Player(1, role, self.w - x + random.randint(-8, 8), y + random.randint(-8, 8), self.w, self.h, radius=self.player_radius))

    def _pick_random_owner(self, team):
        team_players = [p for p in self.players if p.team == team]
        return random.choice(team_players) if team_players else None

    def _assign_offense_positions(self):
        spots = self.offense_spots_right if self.offense_team == 0 else self.offense_spots_left
        for p in self.players:
            if p.team == self.offense_team:
                sx, sy = spots.get(p.role, (p.x, p.y))
                p.tx, p.ty = float(sx), float(sy)

    def _assign_defense(self):
        offense = [p for p in self.players if p.team == self.offense_team]
        defense = [p for p in self.players if p.team != self.offense_team]
        d_by_role = {d.role: d for d in defense}

        rim = get_attack_rim(self.offense_team, self.rim_right, self.rim_left)

        for o in offense:
            d = d_by_role.get(o.role)
            if not d:
                continue
            dx, dy = rim[0] - o.x, rim[1] - o.y
            nx, ny = normalize(dx, dy)
            d.tx = o.x + nx * 50
            d.ty = o.y + ny * 50

    def _update_actors(self, dt):
        for p in self.players:
            p.update(dt)
        self.ball.update(dt)
