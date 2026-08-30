from fastapi import FastAPI, HTTPException, Header, Request, Response
from pydantic import BaseModel, EmailStr
from typing import Any, Dict, Optional
import json
import hashlib
import copy
import os
import time
import uuid
import secrets
import urllib.request
import urllib.error

try:
    import stripe as stripe_sdk
except Exception:
    stripe_sdk = None


from datetime import datetime, timedelta, timezone


import json
from typing import Any, Dict, Tuple, Optional

async def safe_body_json(request) -> Tuple[Dict[str, Any], bytes]:
    """
    Parse JSON depuis le body sans lever JSONDecodeError.
    - Retourne (data_dict, raw_bytes)
    - Si body vide -> ({}, b"")
    - Si JSON invalide -> ({"_error":"JSON_INVALID", "_raw":"..."}, raw_bytes)
    """
    try:
        raw = await request.body()
    except Exception as e:
        return ({"_error": "BODY_READ_FAIL", "exc": repr(e)}, b"")

    if not raw:
        return ({}, b"")

    try:
        txt = raw.decode("utf-8", errors="replace")
        data = json.loads(txt)
        if isinstance(data, dict):
            return (data, raw)
        # Si le JSON est une liste / string etc, on l'encapsule pour debug
        return ({"_json": data}, raw)
    except Exception as e:
        return ({"_error": "JSON_INVALID", "exc": repr(e), "_raw": raw.decode("utf-8", errors="replace")}, raw)
# JWT (python-jose)
from jose import jwt
from jose.exceptions import JWTError

# Email (SMTP)
import smtplib
from email.mime.text import MIMEText


app = FastAPI(title="BM Online API", version="0.0.2-cloudtest")

@app.get("/debug/resend_env")
def debug_resend_env():
    k = os.getenv("RESEND_API_KEY", "") or ""
    frm = os.getenv("RESEND_FROM", "") or ""
    mode = os.getenv("EMAIL_MODE", "") or ""
    return {
        "has_key": bool(k),
        "key_len": len(k),
        "key_prefix": k[:3],
        "key_suffix": (k[-4:] if len(k) >= 4 else k),
        "key_has_space": (" " in k),
        "key_has_newline": ("\n" in k or "\r" in k),
        "from": frm,
        "email_mode": mode,
    }
@app.post("/debug/resend_send")
async def debug_resend_send(request: Request):
    """
    DEBUG endpoint: envoie un email via Resend.
    Objectifs:
    - Ne JAMAIS appeler request.json() (évite JSONDecodeError si body vide)
    - Parser le body de manière safe
    - En cas de 403 Resend, renvoyer status + body Resend via HTTPError.read()
    """
    data, raw = await safe_body_json(request)

    # Champs attendus (à adapter si tu veux)
    to = str(data.get("to", "") or "")
    subject = str(data.get("subject", "BM Debug Resend") or "BM Debug Resend")
    text = str(data.get("text", "Hello from /debug/resend_send") or "Hello from /debug/resend_send")

    # Petits indices utiles côté diagnostic (body vide / JSON invalide / etc.)
    diag = {
        "body_len": len(raw),
        "parsed_keys": list(data.keys()) if isinstance(data, dict) else [],
        "to_present": bool(to),
    }

    # Si tu veux autoriser un POST vide juste pour vérifier que ça ne 500 plus:
    if not to:
        return {"ok": False, "error": "MISSING_TO", "diag": diag, "received": data}

    import os, json as _json
    from urllib import request as _ureq
    from urllib.error import HTTPError, URLError

    api_key = os.environ.get("RESEND_API_KEY", "") or ""
    if not api_key:
        return {"ok": False, "error": "NO_RESEND_API_KEY", "diag": diag}

    url = "https://api.resend.com/emails"
    payload = {
        # ⚠️ Mets un from valide configuré chez Resend (domaine vérifié)
        "from": os.environ.get("RESEND_FROM", "BasketManager <no-reply@basketmanager-game.com>"),
        "to": [to],
        "subject": subject,
        "text": text,
    }
    body = _json.dumps(payload).encode("utf-8")

    req = _ureq.Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.add_header("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36")

    try:
        with _ureq.urlopen(req, timeout=20) as resp:
            resp_body = resp.read() or b""
            return {
                "ok": True,
                "status": getattr(resp, "status", 200),
                "body": resp_body.decode("utf-8", errors="replace"),
                "diag": diag,
            }

    except HTTPError as e:
        # 🔥 IMPORTANT: body Resend exploitable (notamment sur 403)
        err_body = b""
        try:
            err_body = e.read() or b""
        except Exception:
            pass

        return {
            "ok": False,
            "status": int(getattr(e, "code", 0) or 0),
            "reason": str(getattr(e, "reason", "") or ""),
            "body": err_body.decode("utf-8", errors="replace"),
            "diag": diag,
        }

    except URLError as e:
        return {"ok": False, "status": 0, "error": "URL_ERROR", "exc": repr(e), "diag": diag}

    except Exception as e:
        return {"ok": False, "status": 0, "error": "UNHANDLED", "exc": repr(e), "diag": diag}



@app.get("/v1/debug/salt_len")
def debug_salt_len():
    v = (os.environ.get("API_SALT_V1", "") or "").strip()
    return {"ok": True, "salt_len": len(v)}


@app.get("/")
def root():
    return {"ok": True, "service": "bm-online-api", "build": "2026-01-27-debugsend-v3"}

@app.get("/v1/health")
def health():
    return {"ok": True}

# Alias demandé
@app.get("/health")
def health_root():
    return {"ok": True}


# ============================================================
# LEADERBOARD (Postgres) — V1 saison mensuelle
# ============================================================
import os
from typing import Optional
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

_LB_ENGINE: Optional[Engine] = None

def _lb_get_engine() -> Optional[Engine]:
    """Retourne un engine Postgres pour le leaderboard (ou None si non configuré)."""
    global _LB_ENGINE
    if _LB_ENGINE is not None:
        return _LB_ENGINE
    try:
        db_url = (os.environ.get("DATABASE_URL", "") or "").strip()
        if not db_url:
            return None
        
        # Force driver psycopg v3 (Python 3.13 compatible)
        if db_url.startswith("postgresql://"):
            db_url = db_url.replace("postgresql://", "postgresql+psycopg://", 1)
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql+psycopg://", 1)

        _LB_ENGINE = create_engine(db_url, pool_pre_ping=True, future=True, connect_args={"sslmode": "require"})
        return _LB_ENGINE
    except Exception as e:
        try:
            print("[DBG][LB] _lb_get_engine FAIL:", repr(e))
            du = (os.environ.get("DATABASE_URL", "") or "").strip()
            print("[DBG][LB] DATABASE_URL len =", len(du), "starts=", du[:30])
        except Exception:
            pass
        return None


def _lb_init_schema() -> bool:
    """Crée la table si besoin. Ne casse jamais le serveur Cloud."""
    eng = _lb_get_engine()
    if eng is None:
        return False
    try:
        stmts = [
            """
            CREATE TABLE IF NOT EXISTS leaderboard_season (
              season_id       TEXT NOT NULL,
              profile_uuid    TEXT NOT NULL,
              pseudo          TEXT NOT NULL,
              club            TEXT NOT NULL,
              club_level      INT  NOT NULL DEFAULT 1,
              titles_total    INT  NOT NULL DEFAULT 0,
              winrate         DOUBLE PRECISION NOT NULL DEFAULT 0,
              score_final     INT  NOT NULL DEFAULT 0,
              meta_json       JSONB NOT NULL DEFAULT '{}'::jsonb,
              client_sig      TEXT NOT NULL DEFAULT '',
              updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              CONSTRAINT leaderboard_season_pk PRIMARY KEY (season_id, profile_uuid)
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS lb_season_score_idx
              ON leaderboard_season (season_id, score_final DESC, updated_at DESC);
            """,
            """
            CREATE INDEX IF NOT EXISTS lb_season_winrate_idx
              ON leaderboard_season (season_id, winrate DESC, updated_at DESC);
            """,
            """
            CREATE INDEX IF NOT EXISTS lb_season_titles_idx
              ON leaderboard_season (season_id, titles_total DESC, updated_at DESC);
            """,
            """
            CREATE INDEX IF NOT EXISTS lb_season_level_idx
              ON leaderboard_season (season_id, club_level DESC, updated_at DESC);
            """,
        ]

        with eng.begin() as conn:
            for s in stmts:
                conn.execute(text(s))
        return True
    except Exception as e:
        try:
            print("[DBG][LB] _lb_init_schema FAIL:", repr(e))
        except Exception:
            pass
        return False

def _cloud_init_schema() -> bool:
    eng = _lb_get_engine()
    if eng is None:
        return False
    try:
        with eng.begin() as conn:
            conn.execute(text("""
            CREATE TABLE IF NOT EXISTS cloud_save (
              profile_uuid TEXT PRIMARY KEY,
              blob_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
              client_sig   TEXT NOT NULL DEFAULT '',
              updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """))
        return True
    except Exception as e:
        try:
            print("[DBG][CLOUD] _cloud_init_schema FAIL:", repr(e))
        except Exception:
            pass
        return False



def _lb_sig_v1(season_id: str, profile_uuid: str, pseudo: str, club: str,
              club_level: int, titles_total: int, winrate: float, score_final: int) -> str:
    """Signature simple V1 (anti-payload cassé). Si API_SALT_V1 absent => non vérifiée."""
    try:
        import hashlib
        salt = (os.environ.get("API_SALT_V1", "") or "").strip()
        canon = "|".join([
            str(season_id),
            str(profile_uuid),
            str(pseudo),
            str(club),
            str(int(club_level)),
            str(int(titles_total)),
            f"{float(winrate):.6f}",
            str(int(score_final)),
        ])
        return hashlib.sha256((canon + "|" + salt).encode("utf-8")).hexdigest()
    except Exception:
        return ""

def _cloud_sig_v1(profile_uuid: str, blob: Dict[str, Any]) -> str:
    """Signature Cloud V1. Si API_SALT_V1 absent => non vérifiée."""
    try:
        salt = (os.environ.get("API_SALT_V1", "") or "").strip()
        canon_blob = json.dumps(blob or {}, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256((str(profile_uuid) + "|" + canon_blob + "|" + salt).encode("utf-8")).hexdigest()
    except Exception:
        return ""



# ============================================================
# AUTH OTP (Email) + Sessions + Cloud Save V2 (Bearer)
# ============================================================

# -------- Config (env) --------
JWT_SECRET = (os.environ.get("JWT_SECRET", "") or "").strip()
JWT_ISSUER = (os.environ.get("JWT_ISSUER", "basketmanager-api") or "").strip()
JWT_AUDIENCE = (os.environ.get("JWT_AUDIENCE", "basketmanager-game") or "").strip()
ACCESS_TOKEN_MINUTES = int(os.environ.get("ACCESS_TOKEN_MINUTES", "15") or 15)
REFRESH_TOKEN_DAYS = int(os.environ.get("REFRESH_TOKEN_DAYS", "30") or 30)

EMAIL_MODE = (os.environ.get("EMAIL_MODE", "mock") or "mock").strip().lower()  # smtp|mock
SMTP_HOST = (os.environ.get("SMTP_HOST", "") or "").strip()
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587") or 587)
SMTP_USER = (os.environ.get("SMTP_USER", "") or "").strip()
SMTP_PASS = (os.environ.get("SMTP_PASS", "") or "").strip()
EMAIL_FROM = (os.environ.get("EMAIL_FROM", "no-reply@basketmanager-game.com") or "").strip()

OTP_TTL_MINUTES = int(os.environ.get("OTP_TTL_MINUTES", "10") or 10)
OTP_MAX_ATTEMPTS = int(os.environ.get("OTP_MAX_ATTEMPTS", "5") or 5)
OTP_START_COOLDOWN_SECONDS = int(os.environ.get("OTP_START_COOLDOWN_SECONDS", "60") or 60)

MAX_BLOB_BYTES = int(os.environ.get("MAX_BLOB_BYTES", "262144") or 262144)
SAVE_COOLDOWN_SECONDS = int(os.environ.get("SAVE_COOLDOWN_SECONDS", "10") or 10)

RL_GLOBAL_PER_MIN = int(os.environ.get("RL_GLOBAL_PER_MIN", "30") or 30)
RL_SAVE_PER_MIN = int(os.environ.get("RL_SAVE_PER_MIN", "5") or 5)

TESTERS_MODE = (os.environ.get("TESTERS_MODE", "0") or "0").strip() == "1"
_TESTERS_WHITELIST = set([e.strip().lower() for e in (os.environ.get("TESTERS_EMAIL_WHITELIST", "") or "").split(",") if e.strip()])

# Migration : autoriser l'ancien HMAC (API_SALT_V1) en dev seulement
ALLOW_HMAC_V1 = (os.environ.get("ALLOW_HMAC_V1", "0") or "0").strip() == "1"

# Stripe Checkout (SAFE 1: infrastructure only, no Token credit)
STRIPE_SECRET_KEY = (os.environ.get("STRIPE_SECRET_KEY", "") or "").strip()
STRIPE_PUBLISHABLE_KEY = (os.environ.get("STRIPE_PUBLISHABLE_KEY", "") or "").strip()
STRIPE_WEBHOOK_SECRET = (os.environ.get("STRIPE_WEBHOOK_SECRET", "") or "").strip()
STRIPE_SUCCESS_URL = (os.environ.get("STRIPE_SUCCESS_URL", "https://basketmanager-game.com/stripe/success?session_id={CHECKOUT_SESSION_ID}") or "").strip()
STRIPE_CANCEL_URL = (os.environ.get("STRIPE_CANCEL_URL", "https://basketmanager-game.com/stripe/cancel") or "").strip()

STRIPE_TOKEN_PACKS: Dict[str, Dict[str, Any]] = {
    "starter": {
        "pack_id": "starter",
        "stripe_price_id": (os.environ.get("STRIPE_PRICE_STARTER", "") or "").strip(),
        "tokens": 25,
        "amount": 99,
        "currency": "eur",
    },
    "club": {
        "pack_id": "club",
        "stripe_price_id": (os.environ.get("STRIPE_PRICE_CLUB", "") or "").strip(),
        "tokens": 75,
        "amount": 299,
        "currency": "eur",
    },
    "manager": {
        "pack_id": "manager",
        "stripe_price_id": (os.environ.get("STRIPE_PRICE_MANAGER", "") or "").strip(),
        "tokens": 150,
        "amount": 499,
        "currency": "eur",
    },
}


# -------- Helpers (time / hash / jwt) --------
def _utcnow() -> datetime:
    return datetime.now(timezone.utc)

def _sha256(s: str) -> str:
    return hashlib.sha256((s or "").encode("utf-8")).hexdigest()

def _otp_generate_6digits() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"

def _otp_hash(code: str) -> str:
    pepper = (os.environ.get("OTP_PEPPER", "pepper") or "pepper").strip()
    return _sha256(f"{pepper}:{code}")

def _jwt_make_access(user_id: str, email: str) -> str:
    if not JWT_SECRET:
        raise HTTPException(status_code=503, detail="JWT_NOT_CONFIGURED")

    now = _utcnow()
    exp = now + timedelta(minutes=ACCESS_TOKEN_MINUTES)
    payload = {
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "sub": user_id,
        "email": email,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "typ": "access",
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def _jwt_verify_access(token: str) -> Dict[str, Any]:
    try:
        claims = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=["HS256"],
            audience=JWT_AUDIENCE,
            issuer=JWT_ISSUER,
            options={"require_aud": True, "require_iss": True},
        )
        if claims.get("typ") != "access":
            raise HTTPException(status_code=401, detail="BAD_TOKEN_TYPE")
        return claims
    except JWTError:
        raise HTTPException(status_code=401, detail="INVALID_TOKEN")

def _new_refresh_token() -> str:
    return secrets.token_urlsafe(48)

def _refresh_expires_at() -> datetime:
    return _utcnow() + timedelta(days=REFRESH_TOKEN_DAYS)


# -------- Email sender (SMTP / mock / resend) --------
def _send_otp_email(to_email: str, code: str) -> None:
    # 1) mock
    if EMAIL_MODE == "mock":
        print(f"[MOCK_EMAIL] OTP for {to_email} = {code}")
        return

    subject = "Basket Manager — Code de connexion"
    body = f"Votre code Basket Manager est : {code}\n\nIl expire dans {OTP_TTL_MINUTES} minutes."

    # 2) resend
    if EMAIL_MODE == "resend":
        resend_key = os.environ.get("RESEND_API_KEY", "").strip()
        resend_from = os.environ.get("RESEND_FROM", "").strip()

        if not (resend_key and resend_from):
            raise HTTPException(status_code=503, detail="RESEND_NOT_CONFIGURED")

        try:
            import json
            import urllib.request

            req = urllib.request.Request(
                "https://api.resend.com/emails",
                data=json.dumps({
                    "from": resend_from,
                    "to": [to_email],
                    "subject": subject,
                    "text": body,
                }).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {resend_key}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )

            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read() or b"{}"

            # si Resend renvoie une erreur, on la propage clairement
            # (Resend renvoie souvent 200/201 en succès)
            return

        except Exception as e:
            resend_body = ""
            try:
                if hasattr(e, "read"):
                    resend_body = e.read().decode("utf-8", errors="replace")
            except Exception:
                resend_body = ""

            raise HTTPException(status_code=503, detail=f"RESEND_FAIL:{e} body={resend_body}")

    # 3) smtp (fallback)
    if not (SMTP_HOST and SMTP_USER and SMTP_PASS and EMAIL_FROM):
        raise HTTPException(status_code=503, detail="SMTP_NOT_CONFIGURED")

    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = EMAIL_FROM
    msg["To"] = to_email

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
        s.starttls()
        s.login(SMTP_USER, SMTP_PASS)
        s.sendmail(EMAIL_FROM, [to_email], msg.as_string())



# -------- Anti-abus (in-memory soft) --------
_RL_BUCKETS: Dict[str, list] = {}
_LAST_OTP_START: Dict[str, float] = {}
_LAST_SAVE: Dict[str, float] = {}

def _rl_hit(key: str, limit_per_min: int) -> None:
    now = time.time()
    window = 60.0
    arr = _RL_BUCKETS.get(key, [])
    arr = [t for t in arr if now - t < window]
    if len(arr) >= limit_per_min:
        raise HTTPException(status_code=429, detail="RATE_LIMIT")
    arr.append(now)
    _RL_BUCKETS[key] = arr

def _rl_global(user_key: str) -> None:
    _rl_hit(f"g:{user_key}", RL_GLOBAL_PER_MIN)

def _rl_save(user_key: str) -> None:
    _rl_hit(f"s:{user_key}", RL_SAVE_PER_MIN)

def _enforce_testers(email: str) -> None:
    if not TESTERS_MODE:
        return
    if _TESTERS_WHITELIST and (email.lower() not in _TESTERS_WHITELIST):
        raise HTTPException(status_code=403, detail="NOT_ALLOWED_TESTER")


# -------- Schema init (Postgres) --------
def _auth_init_schema() -> bool:
    eng = _lb_get_engine()
    if eng is None:
        return False
    try:
        stmts = [
            """
            CREATE TABLE IF NOT EXISTS users (
              user_id       TEXT PRIMARY KEY,
              email         TEXT NOT NULL UNIQUE,
              email_verified BOOLEAN NOT NULL DEFAULT FALSE,
              status        TEXT NOT NULL DEFAULT 'active',
              is_tester     BOOLEAN NOT NULL DEFAULT FALSE,
              created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              last_login_at TIMESTAMPTZ NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS otp_codes (
              otp_id        TEXT PRIMARY KEY,
              email         TEXT NOT NULL,
              code_hash     TEXT NOT NULL,
              purpose       TEXT NOT NULL DEFAULT 'login',
              expires_at    TIMESTAMPTZ NOT NULL,
              attempts_left INT NOT NULL DEFAULT 5,
              created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              sent_ip       TEXT NULL,
              last_try_at   TIMESTAMPTZ NULL
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS otp_email_idx
              ON otp_codes (email, purpose, created_at DESC);
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
              session_id    TEXT PRIMARY KEY,
              user_id       TEXT NOT NULL REFERENCES users(user_id),
              refresh_hash  TEXT NOT NULL UNIQUE,
              created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              expires_at    TIMESTAMPTZ NOT NULL,
              revoked_at    TIMESTAMPTZ NULL,
              last_used_at  TIMESTAMPTZ NULL,
              user_agent    TEXT NULL,
              ip            TEXT NULL
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS sessions_user_idx
              ON sessions (user_id, expires_at DESC);
            """,
            """
            CREATE TABLE IF NOT EXISTS cloud_saves_v2 (
              save_id       TEXT PRIMARY KEY,
              user_id       TEXT NOT NULL REFERENCES users(user_id),
              profile_uuid  TEXT NOT NULL,
              rev           INT  NOT NULL DEFAULT 1,
              checksum      TEXT NULL,
              blob_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
              blob_size     INT NOT NULL DEFAULT 0,
              updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              CONSTRAINT cloud_saves_v2_uq UNIQUE (user_id, profile_uuid)
            );
            """,
            """
            ALTER TABLE cloud_saves_v2
              ADD COLUMN IF NOT EXISTS career_id TEXT NULL;
            """,
            """
            ALTER TABLE cloud_saves_v2
              DROP CONSTRAINT IF EXISTS cloud_saves_v2_uq;
            """,
            """
            CREATE INDEX IF NOT EXISTS cloud_saves_v2_user_profile_idx
              ON cloud_saves_v2 (user_id, profile_uuid);
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS cloud_saves_v2_user_profile_career_uq
              ON cloud_saves_v2 (user_id, profile_uuid, career_id)
              WHERE career_id IS NOT NULL;
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS cloud_saves_v2_user_profile_legacy_uq
              ON cloud_saves_v2 (user_id, profile_uuid)
              WHERE career_id IS NULL;
            """,
            """
            CREATE INDEX IF NOT EXISTS cloud_saves_v2_user_profile_career_idx
              ON cloud_saves_v2 (user_id, profile_uuid, career_id);
            """,
            """
            CREATE TABLE IF NOT EXISTS club_token_wallets (
              user_id       TEXT NOT NULL REFERENCES users(user_id),
              profile_uuid  TEXT NOT NULL,
              tokens        INT NOT NULL DEFAULT 0 CHECK (tokens >= 0),
              updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              CONSTRAINT club_token_wallets_uq UNIQUE (user_id, profile_uuid)
            );
            """,
            """
            ALTER TABLE club_token_wallets
              ADD COLUMN IF NOT EXISTS career_id TEXT NULL;
            """,
            """
            ALTER TABLE club_token_wallets
              DROP CONSTRAINT IF EXISTS club_token_wallets_uq;
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS club_token_wallets_user_profile_career_uq
              ON club_token_wallets (user_id, profile_uuid, career_id)
              WHERE career_id IS NOT NULL;
            """,
            """
            CREATE UNIQUE INDEX IF NOT EXISTS club_token_wallets_user_profile_legacy_uq
              ON club_token_wallets (user_id, profile_uuid)
              WHERE career_id IS NULL;
            """,
            """
            CREATE INDEX IF NOT EXISTS club_token_wallets_user_profile_career_idx
              ON club_token_wallets (user_id, profile_uuid, career_id);
            """,
            """
            CREATE TABLE IF NOT EXISTS payments (
              payment_id               TEXT PRIMARY KEY,
              user_id                  TEXT NOT NULL REFERENCES users(user_id),
              profile_uuid             TEXT NOT NULL,
              provider                 TEXT NOT NULL DEFAULT 'stripe',
              stripe_session_id        TEXT UNIQUE,
              stripe_payment_intent_id TEXT UNIQUE,
              pack_id                  TEXT NOT NULL,
              amount                   INT NOT NULL,
              currency                 TEXT NOT NULL,
              status                   TEXT NOT NULL,
              created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
            """,
            """
            ALTER TABLE payments
              ADD COLUMN IF NOT EXISTS career_id TEXT NULL;
            """,
            """
            ALTER TABLE payments
              ADD COLUMN IF NOT EXISTS credited_at TIMESTAMPTZ NULL;
            """,
            """
            CREATE INDEX IF NOT EXISTS payments_user_profile_idx
              ON payments (user_id, profile_uuid, created_at DESC);
            """,
            """
            CREATE INDEX IF NOT EXISTS payments_user_profile_career_idx
              ON payments (user_id, profile_uuid, career_id, created_at DESC);
            """,
            """
            CREATE TABLE IF NOT EXISTS api_audit (
              id           BIGSERIAL PRIMARY KEY,
              user_id      TEXT NULL,
              endpoint     TEXT NOT NULL,
              status       INT NOT NULL,
              size         INT NULL,
              created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
              ip           TEXT NULL
            );
            """,
        ]
        with eng.begin() as conn:
            for s in stmts:
                conn.execute(text(s))
        return True
    except Exception as e:
        try:
            print("[DBG][AUTH] _auth_init_schema FAIL:", repr(e))
        except Exception:
            pass
        return False

def _audit(endpoint: str, status: int, user_id: Optional[str] = None, size: Optional[int] = None, ip: Optional[str] = None) -> None:
    try:
        eng = _lb_get_engine()
        if eng is None:
            return
        with eng.begin() as conn:
            conn.execute(text(
                """INSERT INTO api_audit (user_id, endpoint, status, size, ip)
                   VALUES (:user_id,:endpoint,:status,:size,:ip);"""
            ), {"user_id": user_id, "endpoint": endpoint, "status": int(status), "size": size, "ip": ip})
    except Exception:
        pass


# -------- Pydantic payloads (Auth + Cloud V2) --------
class AuthStartPayload(BaseModel):
    email: EmailStr

class AuthVerifyPayload(BaseModel):
    email: EmailStr
    code: str

class AuthRefreshPayload(BaseModel):
    refresh_token: str

class CloudSavePayloadV2(BaseModel):
    profile_uuid: str
    career_id: str = ""
    blob: Dict[str, Any]
    client_rev: Optional[int] = None
    checksum: Optional[str] = ""
    attach_legacy: Optional[bool] = False


class CreateCheckoutSessionPayload(BaseModel):
    profile_uuid: str = ""
    career_id: str = ""
    pack_id: str


# -------- Auth endpoints (OTP) --------
@app.post("/v1/auth/start")
def auth_start(p: AuthStartPayload, request: Request):
    # 0) DB ready
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    email = (p.email or "").strip().lower()
    _enforce_testers(email)
    _rl_global(email)

    # 1) cooldown start (soft)
    now = time.time()
    last = _LAST_OTP_START.get(email, 0.0)
    if now - last < OTP_START_COOLDOWN_SECONDS:
        return {"ok": True}
    _LAST_OTP_START[email] = now

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    # 2) upsert user
    user_id = None
    with eng.begin() as conn:
        r = conn.execute(text("SELECT user_id FROM users WHERE email = :email LIMIT 1;"), {"email": email}).fetchone()
        if r:
            user_id = r[0]
        else:
            user_id = uuid.uuid4().hex
            conn.execute(text("""
                INSERT INTO users (user_id, email, email_verified, status, is_tester, created_at)
                VALUES (:user_id, :email, FALSE, 'active', :is_tester, NOW());
            """), {"user_id": user_id, "email": email, "is_tester": bool(TESTERS_MODE)})

    # 3) create otp
    code = _otp_generate_6digits()
    otp_id = uuid.uuid4().hex
    expires_at = _utcnow() + timedelta(minutes=OTP_TTL_MINUTES)
    ip = request.client.host if request.client else None

    with eng.begin() as conn:
        conn.execute(text("""
            INSERT INTO otp_codes (otp_id, email, code_hash, purpose, expires_at, attempts_left, created_at, sent_ip)
            VALUES (:otp_id, :email, :code_hash, 'login', :expires_at, :attempts_left, NOW(), :sent_ip);
        """), {
            "otp_id": otp_id,
            "email": email,
            "code_hash": _otp_hash(code),
            "expires_at": expires_at,
            "attempts_left": int(OTP_MAX_ATTEMPTS),
            "sent_ip": ip,
        })

    _send_otp_email(email, code)
    _audit("/v1/auth/start", 200, user_id=user_id, ip=ip)
    return {"ok": True}


@app.post("/v1/auth/verify")
def auth_verify(p: AuthVerifyPayload, request: Request):
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    email = (p.email or "").strip().lower()
    code = (p.code or "").strip()
    _enforce_testers(email)
    _rl_global(email)

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    # 1) latest otp for email
    with eng.begin() as conn:
        otp = conn.execute(text("""
            SELECT otp_id, code_hash, expires_at, attempts_left
            FROM otp_codes
            WHERE email = :email AND purpose = 'login'
            ORDER BY created_at DESC
            LIMIT 1;
        """), {"email": email}).fetchone()

    if not otp:
        raise HTTPException(status_code=400, detail="OTP_NOT_FOUND")

    otp_id, code_hash, expires_at, attempts_left = otp[0], otp[1], otp[2], int(otp[3])

    if expires_at < _utcnow():
        raise HTTPException(status_code=400, detail="OTP_EXPIRED")
    if attempts_left <= 0:
        raise HTTPException(status_code=400, detail="OTP_LOCKED")

    # 2) decrement attempts first (prevents brute force)
    with eng.begin() as conn:
        conn.execute(text("""
            UPDATE otp_codes
            SET attempts_left = attempts_left - 1, last_try_at = NOW()
            WHERE otp_id = :otp_id;
        """), {"otp_id": otp_id})

    if _otp_hash(code) != code_hash:
        raise HTTPException(status_code=400, detail="OTP_INVALID")

    # 3) user
    with eng.begin() as conn:
        u = conn.execute(text("SELECT user_id, status FROM users WHERE email = :email LIMIT 1;"), {"email": email}).fetchone()
    if not u:
        raise HTTPException(status_code=400, detail="USER_NOT_FOUND")
    user_id = u[0]
    status = (u[1] or "active")
    if status != "active":
        raise HTTPException(status_code=403, detail="USER_BLOCKED")

    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent", "")

    # 4) mark verified + last_login
    with eng.begin() as conn:
        conn.execute(text("""
            UPDATE users
            SET email_verified = TRUE, last_login_at = NOW()
            WHERE user_id = :user_id;
        """), {"user_id": user_id})

    # 5) issue tokens
    access_token = _jwt_make_access(user_id, email)
    refresh_token = _new_refresh_token()

    sess_id = uuid.uuid4().hex
    with eng.begin() as conn:
        conn.execute(text("""
            INSERT INTO sessions (session_id, user_id, refresh_hash, created_at, expires_at, user_agent, ip)
            VALUES (:sid, :uid, :rh, NOW(), :exp, :ua, :ip);
        """), {
            "sid": sess_id,
            "uid": user_id,
            "rh": _sha256(refresh_token),
            "exp": _refresh_expires_at(),
            "ua": ua[:256],
            "ip": ip,
        })

    _audit("/v1/auth/verify", 200, user_id=user_id, ip=ip)
    return {"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer"}



@app.post("/v1/auth/guest")
def auth_guest(request: Request):
    auth_t0 = time.perf_counter()
    def _auth_timing(event: str) -> None:
        print(f"AUTH_TIMING event={event} elapsed_ms={int((time.perf_counter() - auth_t0) * 1000)}")

    _auth_timing("auth_start")
    _auth_timing("before_schema")
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")
    _auth_timing("after_schema")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    user_id = uuid.uuid4().hex
    email = f"guest_{user_id}@guest.local"
    ip = request.client.host if request.client else None
    ua = request.headers.get("user-agent", "")

    _auth_timing("before_insert_user")
    with eng.begin() as conn:
        conn.execute(text("""
            INSERT INTO users (user_id, email, email_verified, status, is_tester, created_at, last_login_at)
            VALUES (:user_id, :email, FALSE, 'active', FALSE, NOW(), NOW());
        """), {"user_id": user_id, "email": email})
    _auth_timing("after_insert_user")

    access_token = _jwt_make_access(user_id, email)
    _auth_timing("after_access_token")
    refresh_token = _new_refresh_token()
    _auth_timing("after_refresh_token")

    sess_id = uuid.uuid4().hex
    _auth_timing("before_insert_session")
    with eng.begin() as conn:
        conn.execute(text("""
            INSERT INTO sessions (session_id, user_id, refresh_hash, created_at, expires_at, user_agent, ip)
            VALUES (:sid, :uid, :rh, NOW(), :exp, :ua, :ip);
        """), {
            "sid": sess_id,
            "uid": user_id,
            "rh": _sha256(refresh_token),
            "exp": _refresh_expires_at(),
            "ua": ua[:256],
            "ip": ip,
        })
    _auth_timing("after_insert_session")

    _auth_timing("before_audit")
    _audit("/v1/auth/guest", 200, user_id=user_id, ip=ip)
    _auth_timing("after_audit")
    _auth_timing("before_return")
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "profile_uuid": user_id,
        "guest": True
    }


@app.post("/v1/auth/refresh")
def auth_refresh(p: AuthRefreshPayload, request: Request):
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    rt = (p.refresh_token or "").strip()
    if len(rt) < 30:
        raise HTTPException(status_code=400, detail="BAD_REFRESH")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    rh = _sha256(rt)

    with eng.begin() as conn:
        s = conn.execute(text("""
            SELECT session_id, user_id, expires_at, revoked_at
            FROM sessions
            WHERE refresh_hash = :rh
            LIMIT 1;
        """), {"rh": rh}).fetchone()

    if not s:
        raise HTTPException(status_code=401, detail="REFRESH_INVALID")

    session_id, user_id, expires_at, revoked_at = s[0], s[1], s[2], s[3]
    if revoked_at is not None:
        raise HTTPException(status_code=401, detail="REFRESH_REVOKED")
    if expires_at < _utcnow():
        raise HTTPException(status_code=401, detail="REFRESH_EXPIRED")

    with eng.begin() as conn:
        u = conn.execute(text("SELECT email, status FROM users WHERE user_id = :uid LIMIT 1;"), {"uid": user_id}).fetchone()
    if not u:
        raise HTTPException(status_code=401, detail="USER_NOT_FOUND")
    email, status = (u[0] or ""), (u[1] or "active")
    if status != "active":
        raise HTTPException(status_code=403, detail="USER_BLOCKED")

    # rotate refresh
    new_refresh = _new_refresh_token()
    with eng.begin() as conn:
        conn.execute(text("""
            UPDATE sessions
            SET refresh_hash = :new_rh, last_used_at = NOW()
            WHERE session_id = :sid;
        """), {"new_rh": _sha256(new_refresh), "sid": session_id})

    access_token = _jwt_make_access(user_id, email)
    ip = request.client.host if request.client else None
    _audit("/v1/auth/refresh", 200, user_id=user_id, ip=ip)
    return {"access_token": access_token, "refresh_token": new_refresh, "token_type": "bearer"}


@app.post("/v1/auth/logout")
def auth_logout(p: AuthRefreshPayload, request: Request):
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="AUTH_DB_NOT_READY")

    rt = (p.refresh_token or "").strip()
    if len(rt) < 30:
        return {"ok": True}

    eng = _lb_get_engine()
    if eng is None:
        return {"ok": True}

    rh = _sha256(rt)
    with eng.begin() as conn:
        s = conn.execute(text("SELECT session_id, user_id FROM sessions WHERE refresh_hash = :rh LIMIT 1;"), {"rh": rh}).fetchone()
        if not s:
            return {"ok": True}
        sid, uid = s[0], s[1]
        conn.execute(text("UPDATE sessions SET revoked_at = NOW() WHERE session_id = :sid;"), {"sid": sid})

    ip = request.client.host if request.client else None
    _audit("/v1/auth/logout", 200, user_id=uid, ip=ip)
    return {"ok": True}


# -------- Bearer helper --------
def _require_bearer_claims(authorization: str = Header(default="")) -> Dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="MISSING_BEARER")
    token = authorization.split(" ", 1)[1].strip()
    return _jwt_verify_access(token)



# ============================================================
# LEADERBOARD — Endpoints Postgres (V1)
# ============================================================

class LBMeta(BaseModel):
    matches_played: int = 0
    wins: int = 0
    max_streak: int = 0
    rank_start: Optional[int] = None
    rank_end: Optional[int] = None

class LBSubmitPayload(BaseModel):
    season_id: str  # "YYYY-MM"
    profile_uuid: str
    pseudo: str
    club: str
    club_level: int = 1
    titles_total: int = 0
    winrate: float = 0.0
    score_final: int = 0
    meta: LBMeta = LBMeta()
    client_sig: Optional[str] = ""


class CloudSavePayload(BaseModel):
    profile_uuid: str
    blob: Dict[str, Any]  # snapshot JSON du profil (ou tout le save)
    client_sig: Optional[str] = ""

@app.post("/v1/leaderboard/season/submit")
def lb_season_submit(p: LBSubmitPayload):
    if not _lb_init_schema():
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    if not p.season_id or len(p.season_id) != 7 or p.season_id[4] != "-":
        raise HTTPException(status_code=400, detail="BAD_SEASON_ID")
    if not p.profile_uuid or len(p.profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")

    salt = (os.environ.get("API_SALT_V1", "") or "").strip()
    if salt:
        expected = _lb_sig_v1(
            p.season_id, p.profile_uuid, p.pseudo, p.club,
            int(p.club_level), int(p.titles_total), float(p.winrate), int(p.score_final)
        )
        if (p.client_sig or "") != expected:
            raise HTTPException(status_code=400, detail="BAD_SIGNATURE")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    import json
    meta_json = json.dumps(p.meta.model_dump() if hasattr(p.meta, "model_dump") else (p.meta or {}))


    q = text("""
        INSERT INTO leaderboard_season
        (season_id, profile_uuid, pseudo, club, club_level, titles_total, winrate, score_final, meta_json, client_sig, updated_at)
        VALUES
        (:season_id, :profile_uuid, :pseudo, :club, :club_level, :titles_total, :winrate, :score_final, CAST(:meta_json AS jsonb), :client_sig, NOW())
        ON CONFLICT (season_id, profile_uuid)
        DO UPDATE SET
            pseudo = EXCLUDED.pseudo,
            club = EXCLUDED.club,
            club_level = EXCLUDED.club_level,
            titles_total = EXCLUDED.titles_total,
            winrate = EXCLUDED.winrate,
            score_final = EXCLUDED.score_final,
            meta_json = EXCLUDED.meta_json,
            client_sig = EXCLUDED.client_sig,
            updated_at = NOW()
        RETURNING updated_at;
    """)
    
    try:
        with eng.begin() as conn:
            params = {
                "season_id": p.season_id,
                "profile_uuid": p.profile_uuid,
                "pseudo": (p.pseudo or "")[:24],
                "club": (p.club or "")[:24],
                "club_level": int(p.club_level),
                "titles_total": int(p.titles_total),
                "winrate": float(p.winrate),
                "score_final": int(p.score_final),
                "meta_json": meta_json,
                "client_sig": (p.client_sig or "")[:128],
            }

            # --- Debug preuve (temporaire) ---
            try:
                print("[DBG][LB][SUBMIT] params keys =", sorted(list(params.keys())))
                print("[DBG][LB][SUBMIT] meta_json len =", len(meta_json or ""))
            except Exception:
                pass

            row = conn.execute(q, params).fetchone()

    except Exception as e:
        try:
            print("[DBG][LB][SUBMIT] SQL FAIL:", repr(e))
        except Exception:
            pass
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_ERROR")

    return {
        "ok": True,
        "season_id": p.season_id,
        "profile_uuid": p.profile_uuid,
        "updated_at": str(row[0]) if row else None
    }



@app.get("/v1/leaderboard/season/top")

def lb_season_top(season_id: str, metric: str = "score_final", limit: int = 50, offset: int = 0):
    if not _lb_init_schema():
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    metric = (metric or "").strip().lower()
    if metric not in ("score_final", "winrate", "titles_total", "club_level"):
        raise HTTPException(status_code=400, detail="BAD_METRIC")

    limit = max(1, min(int(limit), 200))
    offset = max(0, int(offset))

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    q = text(f"""
        SELECT profile_uuid, pseudo, club, club_level, titles_total, winrate, score_final, updated_at
        FROM leaderboard_season
        WHERE season_id = :season_id
        ORDER BY {metric} DESC, updated_at DESC
        LIMIT :limit OFFSET :offset;
    """)
    qc = text("SELECT COUNT(*) FROM leaderboard_season WHERE season_id = :season_id;")

    with eng.begin() as conn:
        total = int(conn.execute(qc, {"season_id": season_id}).scalar() or 0)
        rows = conn.execute(q, {"season_id": season_id, "limit": limit, "offset": offset}).fetchall()

    items = []
    for i, r in enumerate(rows):
        items.append({
            "rank": offset + i + 1,
            "profile_uuid": r[0],
            "pseudo": r[1],
            "club": r[2],
            "club_level": int(r[3]),
            "titles_total": int(r[4]),
            "winrate": float(r[5]),
            "score_final": int(r[6]),
            "updated_at": str(r[7]),
        })

    return {"ok": True, "season_id": season_id, "metric": metric, "items": items, "total": total}

@app.get("/v1/leaderboard/season/me")
def lb_season_me(season_id: str, profile_uuid: str, metric: str = "score_final"):
    if not _lb_init_schema():
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    metric = (metric or "").strip().lower()
    if metric not in ("score_final", "winrate", "titles_total", "club_level"):
        raise HTTPException(status_code=400, detail="BAD_METRIC")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="LEADERBOARD_DB_NOT_READY")

    q = text(f"""
        WITH ranked AS (
            SELECT
              profile_uuid, pseudo, club, club_level, titles_total, winrate, score_final, updated_at,
              ROW_NUMBER() OVER (ORDER BY {metric} DESC, updated_at DESC) AS rk
            FROM leaderboard_season
            WHERE season_id = :season_id
        )
        SELECT profile_uuid, pseudo, club, club_level, titles_total, winrate, score_final, updated_at, rk
        FROM ranked
        WHERE profile_uuid = :profile_uuid
        LIMIT 1;
    """)

    with eng.begin() as conn:
        r = conn.execute(q, {"season_id": season_id, "profile_uuid": profile_uuid}).fetchone()

    if not r:
        return {"ok": True, "season_id": season_id, "metric": metric, "me": None}

    me = {
        "rank": int(r[8]),
        "profile_uuid": r[0],
        "pseudo": r[1],
        "club": r[2],
        "club_level": int(r[3]),
        "titles_total": int(r[4]),
        "winrate": float(r[5]),
        "score_final": int(r[6]),
        "updated_at": str(r[7]),
    }
    return {"ok": True, "season_id": season_id, "metric": metric, "me": me}


# ============================================================
# CLOUD SAVE — V2 (Bearer) + Legacy V1 (HMAC) migration
# ============================================================

def _club_token_wallet_attach_legacy_once(conn, user_id: str, profile_uuid: str, career_id: str, attach_legacy: bool) -> None:
    if not attach_legacy:
        return

    existing = conn.execute(text("""
        SELECT 1
        FROM club_token_wallets
        WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
        LIMIT 1;
    """), {"uid": user_id, "p": profile_uuid, "c": career_id}).fetchone()
    if existing:
        return

    legacy_rows = conn.execute(text("""
        SELECT user_id, profile_uuid
        FROM club_token_wallets
        WHERE user_id = :uid AND profile_uuid = :p AND career_id IS NULL
        LIMIT 2;
    """), {"uid": user_id, "p": profile_uuid}).fetchall()

    if len(legacy_rows) > 1:
        raise HTTPException(status_code=409, detail="LEGACY_WALLET_AMBIGUOUS")
    if len(legacy_rows) == 0:
        return

    conn.execute(text("""
        UPDATE club_token_wallets
        SET career_id = :c, updated_at = NOW()
        WHERE user_id = :uid AND profile_uuid = :p AND career_id IS NULL;
    """), {"uid": user_id, "p": profile_uuid, "c": career_id})


def _club_token_wallet_get_or_create(conn, user_id: str, profile_uuid: str, career_id: str, attach_legacy: bool = False) -> int:
    cid = _clean_career_id(career_id)
    _club_token_wallet_attach_legacy_once(conn, user_id, profile_uuid, cid, bool(attach_legacy))

    conn.execute(text("""
        INSERT INTO club_token_wallets (user_id, profile_uuid, career_id, tokens, updated_at)
        VALUES (:uid, :p, :c, 0, NOW())
        ON CONFLICT (user_id, profile_uuid, career_id) WHERE career_id IS NOT NULL DO NOTHING;
    """), {"uid": user_id, "p": profile_uuid, "c": cid})

    row = conn.execute(text("""
        SELECT tokens
        FROM club_token_wallets
        WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
        LIMIT 1;
    """), {"uid": user_id, "p": profile_uuid, "c": cid}).fetchone()

    return max(0, int(row[0])) if row else 0


def _cloud_blob_with_server_tokens(blob: Dict[str, Any], server_tokens: int) -> Dict[str, Any]:
    clean_blob = copy.deepcopy(blob or {})
    if not isinstance(clean_blob, dict):
        clean_blob = {}
    if not isinstance(clean_blob.get("wallet"), dict):
        clean_blob["wallet"] = {}
    clean_blob["wallet"]["tokens"] = max(0, int(server_tokens))
    return clean_blob


def _clean_career_id(career_id: str) -> str:
    cid = str(career_id or "").strip()
    if not cid or len(cid) > 128:
        raise HTTPException(status_code=400, detail="BAD_CAREER_ID")
    return cid


def _cloud_v2_attach_legacy_once(conn, user_id: str, profile_uuid: str, career_id: str, attach_legacy: bool) -> None:
    if not attach_legacy:
        return

    existing = conn.execute(text("""
        SELECT save_id
        FROM cloud_saves_v2
        WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
        LIMIT 1;
    """), {"uid": user_id, "p": profile_uuid, "c": career_id}).fetchone()
    if existing:
        return

    legacy_rows = conn.execute(text("""
        SELECT save_id
        FROM cloud_saves_v2
        WHERE user_id = :uid AND profile_uuid = :p AND career_id IS NULL
        LIMIT 2;
    """), {"uid": user_id, "p": profile_uuid}).fetchall()

    if len(legacy_rows) > 1:
        raise HTTPException(status_code=409, detail="LEGACY_CLOUD_AMBIGUOUS")
    if len(legacy_rows) == 0:
        return

    conn.execute(text("""
        UPDATE cloud_saves_v2
        SET career_id = :c, updated_at = NOW()
        WHERE save_id = :sid AND user_id = :uid AND profile_uuid = :p AND career_id IS NULL;
    """), {"sid": legacy_rows[0][0], "uid": user_id, "p": profile_uuid, "c": career_id})


def _cloud_v2_save(user_id: str, profile_uuid: str, career_id: str, blob: Dict[str, Any], client_rev: Optional[int], checksum: str, attach_legacy: bool = False) -> Dict[str, Any]:
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    if not profile_uuid or len(profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")
    cid = _clean_career_id(career_id)
    if not isinstance(blob, dict):
        raise HTTPException(status_code=400, detail="BAD_BLOB")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    with eng.begin() as conn:
        _cloud_v2_attach_legacy_once(conn, user_id, profile_uuid, cid, bool(attach_legacy))
        r = conn.execute(text("""
            SELECT rev FROM cloud_saves_v2
            WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
            LIMIT 1;
        """), {"uid": user_id, "p": profile_uuid, "c": cid}).fetchone()
        server_rev = int(r[0]) if r else 0
        server_tokens = _club_token_wallet_get_or_create(conn, user_id, profile_uuid, cid, bool(attach_legacy))

        if client_rev is not None and server_rev and int(client_rev) < server_rev:
            raise HTTPException(status_code=409, detail="REV_CONFLICT")

        new_rev = server_rev + 1 if server_rev else 1
        save_id = uuid.uuid4().hex
        safe_blob = _cloud_blob_with_server_tokens(blob, server_tokens)
        blob_json = json.dumps(safe_blob, separators=(",", ":"), ensure_ascii=False)
        blob_bytes = blob_json.encode("utf-8")
        if len(blob_bytes) > MAX_BLOB_BYTES:
            raise HTTPException(status_code=413, detail="BLOB_TOO_LARGE")

        q = text("""
            INSERT INTO cloud_saves_v2 (save_id, user_id, profile_uuid, career_id, rev, checksum, blob_json, blob_size, updated_at)
            VALUES (:sid, :uid, :p, :c, :rev, :chk, CAST(:blob_json AS jsonb), :sz, NOW())
            ON CONFLICT (user_id, profile_uuid, career_id) WHERE career_id IS NOT NULL
            DO UPDATE SET
              rev = EXCLUDED.rev,
              checksum = EXCLUDED.checksum,
              blob_json = EXCLUDED.blob_json,
              blob_size = EXCLUDED.blob_size,
              updated_at = NOW()
            RETURNING rev, updated_at;
        """)
        row = conn.execute(q, {
            "sid": save_id,
            "uid": user_id,
            "p": profile_uuid,
            "c": cid,
            "rev": int(new_rev),
            "chk": (checksum or "")[:128],
            "blob_json": blob_json,
            "sz": int(len(blob_bytes)),
        }).fetchone()

    return {
        "ok": True,
        "profile_uuid": profile_uuid,
        "career_id": cid,
        "rev": int(row[0]) if row else new_rev,
        "checksum": (checksum or "")[:128],
        "updated_at": str(row[1]) if row else None,
    }


def _cloud_v2_load(user_id: str, profile_uuid: str, career_id: str, attach_legacy: bool = False) -> Dict[str, Any]:
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    if not profile_uuid or len(profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")
    cid = _clean_career_id(career_id)

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    with eng.begin() as conn:
        _cloud_v2_attach_legacy_once(conn, user_id, profile_uuid, cid, bool(attach_legacy))
        server_tokens = _club_token_wallet_get_or_create(conn, user_id, profile_uuid, cid, bool(attach_legacy))
        r = conn.execute(text("""
            SELECT blob_json, rev, checksum, updated_at
            FROM cloud_saves_v2
            WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
            LIMIT 1;
        """), {"uid": user_id, "p": profile_uuid, "c": cid}).fetchone()

    if not r:
        return {"ok": True, "profile_uuid": profile_uuid, "career_id": cid, "found": False, "blob": None}

    safe_blob = _cloud_blob_with_server_tokens(r[0] if isinstance(r[0], dict) else {}, server_tokens)

    return {
        "ok": True,
        "profile_uuid": profile_uuid,
        "career_id": cid,
        "found": True,
        "blob": safe_blob,
        "rev": int(r[1]),
        "checksum": r[2] or "",
        "updated_at": str(r[3]),
    }


# Legacy V1 (HMAC) helpers (kept for migration)
def _cloud_v1_save(p: CloudSavePayload) -> Dict[str, Any]:
    if not _cloud_init_schema():
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    if not p.profile_uuid or len(p.profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")

    salt = (os.environ.get("API_SALT_V1", "") or "").strip()
    if salt:
        expected = _cloud_sig_v1(p.profile_uuid, p.blob)
        if (p.client_sig or "") != expected:
            raise HTTPException(status_code=400, detail="BAD_SIGNATURE")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    blob_json = json.dumps(p.blob or {}, separators=(",", ":"), ensure_ascii=False)

    q = text("""
        INSERT INTO cloud_save (profile_uuid, blob_json, client_sig, updated_at)
        VALUES (:profile_uuid, CAST(:blob_json AS jsonb), :client_sig, NOW())
        ON CONFLICT (profile_uuid)
        DO UPDATE SET
            blob_json = EXCLUDED.blob_json,
            client_sig = EXCLUDED.client_sig,
            updated_at = NOW()
        RETURNING updated_at;
    """)

    try:
        with eng.begin() as conn:
            row = conn.execute(q, {
                "profile_uuid": p.profile_uuid,
                "blob_json": blob_json,
                "client_sig": (p.client_sig or "")[:128],
            }).fetchone()
    except Exception as e:
        try:
            print("[DBG][CLOUD][SAVE] SQL FAIL:", repr(e))
        except Exception:
            pass
        raise HTTPException(status_code=503, detail="CLOUD_DB_ERROR")

    return {"ok": True, "profile_uuid": p.profile_uuid, "updated_at": str(row[0]) if row else None}


def _cloud_v1_load(profile_uuid: str) -> Dict[str, Any]:
    if not _cloud_init_schema():
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    if not profile_uuid or len(profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="CLOUD_DB_NOT_READY")

    q = text("SELECT blob_json, updated_at FROM cloud_save WHERE profile_uuid = :profile_uuid LIMIT 1;")

    with eng.begin() as conn:
        r = conn.execute(q, {"profile_uuid": profile_uuid}).fetchone()

    if not r:
        return {"ok": True, "profile_uuid": profile_uuid, "found": False, "blob": None}

    return {"ok": True, "profile_uuid": profile_uuid, "found": True, "blob": r[0], "updated_at": str(r[1])}


# -------- Routes (public path = V2) --------
@app.post("/v1/cloud/save")
def cloud_save_v2(p: CloudSavePayloadV2, request: Request, authorization: str = Header(default="")):
    # V2 = toujours Bearer
    claims = _require_bearer_claims(authorization)
    user_id = str(claims.get("sub") or "")

    _rl_global(user_id)
    _rl_save(user_id)

    # cooldown (per user)
    now = time.time()
    last = _LAST_SAVE.get(user_id, 0.0)
    if now - last < SAVE_COOLDOWN_SECONDS:
        raise HTTPException(status_code=429, detail="SAVE_COOLDOWN")
    _LAST_SAVE[user_id] = now

    ip = request.client.host if request.client else None

    try:
        out = _cloud_v2_save(user_id, p.profile_uuid, p.career_id, p.blob, p.client_rev, p.checksum or "", bool(p.attach_legacy))
        _audit("/v1/cloud/save", 200, user_id=user_id, size=None, ip=ip)
        return out
    except HTTPException as he:
        _audit("/v1/cloud/save", int(he.status_code), user_id=user_id, ip=ip)
        raise


@app.get("/v1/cloud/load")
def cloud_load_v2(profile_uuid: str, request: Request, career_id: str = "", attach_legacy: bool = False, authorization: str = Header(default="")):
    claims = _require_bearer_claims(authorization)
    user_id = str(claims.get("sub") or "")

    _rl_global(user_id)

    ip = request.client.host if request.client else None
    try:
        out = _cloud_v2_load(user_id, profile_uuid, career_id, bool(attach_legacy))
        _audit("/v1/cloud/load", 200, user_id=user_id, ip=ip)
        return out
    except HTTPException as he:
        _audit("/v1/cloud/load", int(he.status_code), user_id=user_id, ip=ip)
        raise



# ============================================================
# PAYMENTS — Stripe Checkout (SAFE 1: no Token credit)
# ============================================================

def _stripe_require_config() -> None:
    if stripe_sdk is None:
        raise HTTPException(status_code=503, detail="STRIPE_SDK_NOT_AVAILABLE")
    if not STRIPE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="STRIPE_SECRET_KEY_NOT_CONFIGURED")
    stripe_sdk.api_key = STRIPE_SECRET_KEY


def _stripe_get_pack(pack_id: str) -> Dict[str, Any]:
    pid = (pack_id or "").strip().lower()
    pack = STRIPE_TOKEN_PACKS.get(pid)
    if not pack:
        raise HTTPException(status_code=400, detail="UNKNOWN_PACK")
    if not str(pack.get("stripe_price_id", "")).strip():
        raise HTTPException(status_code=503, detail="STRIPE_PRICE_NOT_CONFIGURED")
    return pack


def _payment_profile_uuid_from_claims(claims: Dict[str, Any]) -> str:
    return str(claims.get("sub") or "")


def _payment_upsert_checkout_session(conn, *, payment_id: str, user_id: str, profile_uuid: str, career_id: str,
                                     session_id: str, payment_intent_id: str, pack: Dict[str, Any],
                                     status: str) -> None:
    conn.execute(text("""
        INSERT INTO payments (
          payment_id, user_id, profile_uuid, career_id, provider, stripe_session_id, stripe_payment_intent_id,
          pack_id, amount, currency, status, created_at, updated_at
        ) VALUES (
          :payment_id, :user_id, :profile_uuid, :career_id, 'stripe', :stripe_session_id, :stripe_payment_intent_id,
          :pack_id, :amount, :currency, :status, NOW(), NOW()
        )
        ON CONFLICT (stripe_session_id)
        DO UPDATE SET
          stripe_payment_intent_id = COALESCE(EXCLUDED.stripe_payment_intent_id, payments.stripe_payment_intent_id),
          career_id = COALESCE(payments.career_id, EXCLUDED.career_id),
          status = EXCLUDED.status,
          updated_at = NOW();
    """), {
        "payment_id": payment_id,
        "user_id": user_id,
        "profile_uuid": profile_uuid,
        "career_id": career_id or None,
        "stripe_session_id": session_id,
        "stripe_payment_intent_id": payment_intent_id or None,
        "pack_id": str(pack.get("pack_id", "")),
        "amount": int(pack.get("amount", 0)),
        "currency": str(pack.get("currency", "eur")),
        "status": status,
    })


def _payment_mark_credited_once(conn, session_id: str) -> bool:
    row = conn.execute(text("""
        UPDATE payments
        SET credited_at = NOW(), updated_at = NOW()
        WHERE stripe_session_id = :stripe_session_id AND credited_at IS NULL
        RETURNING payment_id;
    """), {"stripe_session_id": session_id}).fetchone()
    return row is not None


def _payment_credit_wallet(conn, user_id: str, profile_uuid: str, career_id: str, tokens: int) -> int:
    cid = _clean_career_id(career_id)
    credit = max(0, int(tokens))
    if credit <= 0:
        return _club_token_wallet_get_or_create(conn, user_id, profile_uuid, cid, False)

    _club_token_wallet_get_or_create(conn, user_id, profile_uuid, cid, False)
    row = conn.execute(text("""
        UPDATE club_token_wallets
        SET tokens = tokens + :tokens, updated_at = NOW()
        WHERE user_id = :uid AND profile_uuid = :p AND career_id = :c
        RETURNING tokens;
    """), {"uid": user_id, "p": profile_uuid, "c": cid, "tokens": credit}).fetchone()
    return max(0, int(row[0])) if row else 0


@app.post("/v1/payments/create_checkout_session")
def create_checkout_session(p: CreateCheckoutSessionPayload, request: Request, authorization: str = Header(default="")):
    claims = _require_bearer_claims(authorization)
    user_id = str(claims.get("sub") or "")
    profile_uuid = str(p.profile_uuid or "").strip()
    if not profile_uuid or len(profile_uuid) < 16:
        raise HTTPException(status_code=400, detail="BAD_PROFILE_UUID")
    career_id = _clean_career_id(p.career_id)

    _rl_global(user_id)
    _stripe_require_config()
    pack = _stripe_get_pack(p.pack_id)

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="PAYMENTS_DB_NOT_READY")
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="PAYMENTS_DB_NOT_READY")

    try:
        session = stripe_sdk.checkout.Session.create(
            mode="payment",
            line_items=[{"price": str(pack["stripe_price_id"]), "quantity": 1}],
            success_url=STRIPE_SUCCESS_URL,
            cancel_url=STRIPE_CANCEL_URL,
            client_reference_id=user_id,
            metadata={
                "user_id": user_id,
                "profile_uuid": profile_uuid,
                "career_id": career_id,
                "pack_id": str(pack["pack_id"]),
                "tokens": str(int(pack["tokens"])),
            },
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"STRIPE_CHECKOUT_CREATE_FAILED:{type(e).__name__}")

    session_id = str(getattr(session, "id", "") or session.get("id", ""))
    checkout_url = str(getattr(session, "url", "") or session.get("url", ""))
    if not session_id or not checkout_url:
        raise HTTPException(status_code=502, detail="STRIPE_CHECKOUT_BAD_RESPONSE")

    with eng.begin() as conn:
        _payment_upsert_checkout_session(
            conn,
            payment_id=uuid.uuid4().hex,
            user_id=user_id,
            profile_uuid=profile_uuid,
            career_id=career_id,
            session_id=session_id,
            payment_intent_id="",
            pack=pack,
            status="checkout_created",
        )

    ip = request.client.host if request.client else None
    _audit("/v1/payments/create_checkout_session", 200, user_id=user_id, ip=ip)
    return {"ok": True, "url": checkout_url}


@app.post("/v1/payments/stripe/webhook")
async def stripe_webhook(request: Request, stripe_signature: str = Header(default="", alias="Stripe-Signature")):
    if stripe_sdk is None:
        raise HTTPException(status_code=503, detail="STRIPE_SDK_NOT_AVAILABLE")
    if not STRIPE_WEBHOOK_SECRET:
        raise HTTPException(status_code=503, detail="STRIPE_WEBHOOK_SECRET_NOT_CONFIGURED")

    payload = await request.body()
    try:
        event = stripe_sdk.Webhook.construct_event(payload, stripe_signature, STRIPE_WEBHOOK_SECRET)
    except ValueError:
        raise HTTPException(status_code=400, detail="INVALID_WEBHOOK_PAYLOAD")
    except Exception:
        raise HTTPException(status_code=400, detail="INVALID_WEBHOOK_SIGNATURE")

    event_type = str(event.get("type", ""))
    if event_type not in {
        "checkout.session.completed",
        "checkout.session.async_payment_succeeded",
        "checkout.session.async_payment_failed",
        "checkout.session.expired",
    }:
        return {"ok": True, "ignored": event_type}

    session = event.get("data", {}).get("object", {})
    session_id = str(session.get("id", "") or "")
    if not session_id:
        raise HTTPException(status_code=400, detail="MISSING_STRIPE_SESSION_ID")

    metadata = session.get("metadata") or {}
    pack_id = str(metadata.get("pack_id", "")).strip().lower()
    pack = STRIPE_TOKEN_PACKS.get(pack_id)
    if not pack:
        raise HTTPException(status_code=400, detail="UNKNOWN_PACK")

    user_id = str(metadata.get("user_id", "") or session.get("client_reference_id", "")).strip()
    profile_uuid = str(metadata.get("profile_uuid", "") or user_id).strip()
    career_id = str(metadata.get("career_id", "")).strip()
    if not user_id or not profile_uuid:
        raise HTTPException(status_code=400, detail="MISSING_PAYMENT_OWNER")
    has_career_id = career_id != ""

    payment_status = str(session.get("payment_status", "") or "")
    status = "webhook_received"
    if event_type in {"checkout.session.completed", "checkout.session.async_payment_succeeded"}:
        status = "paid" if payment_status in {"", "paid"} else payment_status
    elif event_type == "checkout.session.async_payment_failed":
        status = "failed"
    elif event_type == "checkout.session.expired":
        status = "expired"

    payment_intent_id = str(session.get("payment_intent", "") or "")

    eng = _lb_get_engine()
    if eng is None:
        raise HTTPException(status_code=503, detail="PAYMENTS_DB_NOT_READY")
    if not _auth_init_schema():
        raise HTTPException(status_code=503, detail="PAYMENTS_DB_NOT_READY")

    credited = False
    wallet_tokens = None
    with eng.begin() as conn:
        _payment_upsert_checkout_session(
            conn,
            payment_id=uuid.uuid4().hex,
            user_id=user_id,
            profile_uuid=profile_uuid,
            career_id=career_id if has_career_id else "",
            session_id=session_id,
            payment_intent_id=payment_intent_id,
            pack=pack,
            status=status,
        )
        if status == "paid":
            if not has_career_id:
                return {"ok": True, "event": event_type, "status": status, "credited": False, "reason": "MISSING_CAREER_ID"}
            if _payment_mark_credited_once(conn, session_id):
                wallet_tokens = _payment_credit_wallet(conn, user_id, profile_uuid, career_id, int(pack.get("tokens", 0)))
                credited = True

    return {"ok": True, "event": event_type, "status": status, "career_id": career_id if has_career_id else None, "credited": credited, "wallet_tokens": wallet_tokens}

# -------- Legacy endpoints (V1 HMAC) — migration only --------
@app.post("/v1/cloud/save_v1")
def cloud_save_v1(p: CloudSavePayload, request: Request):
    if not ALLOW_HMAC_V1:
        raise HTTPException(status_code=404, detail="NOT_FOUND")
    return _cloud_v1_save(p)

@app.get("/v1/cloud/load_v1")
def cloud_load_v1(profile_uuid: str, request: Request):
    if not ALLOW_HMAC_V1:
        raise HTTPException(status_code=404, detail="NOT_FOUND")
    return _cloud_v1_load(profile_uuid)
