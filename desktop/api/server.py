from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from typing import Optional
import sqlite3

app = FastAPI()
DB = "leaderboard.db"


def db():
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    return con


@app.on_event("startup")
def init_db():
    con = db()
    con.execute("""
    CREATE TABLE IF NOT EXISTS profiles (
        profile_uuid TEXT PRIMARY KEY,
        public_name TEXT,
        club_name TEXT,
        club_level INTEGER,
        titles_total INTEGER,
        wins INTEGER,
        matches_played INTEGER,
        client_version TEXT,
        locale TEXT,
        updated_at TEXT
    )
    """)
    con.commit()
    con.close()


@app.get("/ping")
def ping():
    return {"ok": True, "api_version": 1, "server_time": datetime.utcnow().isoformat()}


class SubmitPayload(BaseModel):
    profile_uuid: str
    public_name: Optional[str] = ""
    club_name: Optional[str] = ""
    club_level: int = 1
    titles_total: int = 0
    wins: int = 0
    matches_played: int = 0
    client_version: Optional[str] = "dev"
    locale: Optional[str] = "fr-FR"


@app.post("/leaderboard/submit")
def submit(p: SubmitPayload):
    # validations light
    if not p.profile_uuid or len(p.profile_uuid) < 8:
        raise HTTPException(400, "invalid profile_uuid")
    if p.club_level < 1 or p.club_level > 50:
        raise HTTPException(400, "invalid club_level")
    if p.titles_total < 0 or p.titles_total > 999:
        raise HTTPException(400, "invalid titles_total")
    if p.matches_played < 0 or p.matches_played > 100000:
        raise HTTPException(400, "invalid matches_played")
    if p.wins < 0 or p.wins > p.matches_played:
        raise HTTPException(400, "invalid wins")

    now = datetime.utcnow().isoformat()
    con = db()
    con.execute("""
    INSERT INTO profiles(profile_uuid, public_name, club_name, club_level, titles_total, wins, matches_played, client_version, locale, updated_at)
    VALUES(?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(profile_uuid) DO UPDATE SET
        public_name=excluded.public_name,
        club_name=excluded.club_name,
        club_level=excluded.club_level,
        titles_total=excluded.titles_total,
        wins=excluded.wins,
        matches_played=excluded.matches_played,
        client_version=excluded.client_version,
        locale=excluded.locale,
        updated_at=excluded.updated_at
    """, (
        p.profile_uuid,
        (p.public_name or "")[:24],
        (p.club_name or "")[:24],
        int(p.club_level),
        int(p.titles_total),
        int(p.wins),
        int(p.matches_played),
        (p.client_version or "dev")[:16],
        (p.locale or "fr-FR")[:12],
        now
    ))
    con.commit()
    con.close()
    return {"ok": True}


@app.get("/leaderboard")
def leaderboard(metric: str = "titles_total", limit: int = 50, min_matches: int = 20):
    metric = (metric or "").strip().lower()
    if metric not in ("titles_total", "club_level", "winrate"):
        raise HTTPException(400, "metric must be titles_total|club_level|winrate")

    if limit < 1:
        limit = 1
    if limit > 200:
        limit = 200

    con = db()

    if metric == "winrate":
        rows = con.execute("""
            SELECT *,
            CASE WHEN matches_played>0 THEN (1.0*wins)/matches_played ELSE 0 END AS winrate
            FROM profiles
            WHERE matches_played >= ?
            ORDER BY winrate DESC, matches_played DESC, titles_total DESC, club_level DESC, updated_at DESC
            LIMIT ?
        """, (int(min_matches), int(limit))).fetchall()
    else:
        rows = con.execute(f"""
            SELECT * FROM profiles
            ORDER BY {metric} DESC, titles_total DESC, wins DESC, matches_played DESC, updated_at DESC
            LIMIT ?
        """, (int(limit),)).fetchall()

    con.close()

    items = []
    for r in rows:
        d = dict(r)
        if metric == "winrate":
            d["winrate"] = round(float(d.get("winrate", 0.0)), 4)
        items.append(d)

    return {"metric": metric, "items": items}
