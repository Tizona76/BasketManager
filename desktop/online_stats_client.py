# online_stats_client.py
# Mini-module "Cloud-ready" niveau 1 : collecte locale des événements

import json
import os
import uuid
from datetime import datetime

# Dossier où on stocke les événements (tu peux l’adapter)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
EVENTS_FILE = os.path.join(DATA_DIR, "cloud_events_local.json")


def _assurer_dossier_data():
    """S'assure que le dossier data/ existe.""" 
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
    except Exception as e:
        print("[CLOUD][WARN] Impossible de créer le dossier data :", e)


def _charger_events():
    """Charge la liste d'événements déjà enregistrés (ou [] si vide)."""
    _assurer_dossier_data()
    if not os.path.exists(EVENTS_FILE):
        return []

    try:
        with open(EVENTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
        return []
    except Exception as e:
        print("[CLOUD][WARN] Impossible de lire cloud_events_local.json :", e)
        return []


def _sauver_events(events):
    """Sauvegarde la liste complète d'événements dans le fichier JSON."""
    _assurer_dossier_data()
    try:
        with open(EVENTS_FILE, "w", encoding="utf-8") as f:
            json.dump(events, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print("[CLOUD][WARN] Impossible d'écrire cloud_events_local.json :", e)


def initialiser_cloud_profil(profil: dict):
    """S'assure que le profil a un cloud_player_id et un flag cloud_opt_in.
    À appeler au moment de la création / chargement d'un profil.
    """
    if profil is None:
        return

    # ID unique pour ce joueur (reste le même toute la vie du profil)
    if not profil.get("cloud_player_id"):
        profil["cloud_player_id"] = str(uuid.uuid4())

    # Par défaut : pas d’envoi online (respect RGPD / opt-in explicite plus tard)
    if "cloud_opt_in" not in profil:
        profil["cloud_opt_in"] = False


def enregistrer_event_localement(event: dict):
    """Stocke un événement dans data/cloud_events_local.json.
    Pour l’instant : stockage local uniquement.
    Plus tard : on pourra envoyer ça vers un serveur.
    """
    try:
        events = _charger_events()
        events.append(event)
        _sauver_events(events)
    except Exception as e:
        print("[CLOUD][ERR] Impossible d'enregistrer l'événement cloud :", e)


def enregistrer_evenement_cloud(profil: dict, event_type: str, payload: dict):
    """Point d’entrée UNIQUE pour tous les événements “Cloud”.
    Aujourd’hui : log local, demain : envoi HTTP.

    event_type : ex. "match_fini", "tournoi_gagne", "saison_terminee"
    payload    : dict avec les infos du match / tournoi / saison.
    """
    if profil is None:
        return

    # On respecte le choix du joueur : pas d’opt-in → on ne logge même pas
    if not profil.get("cloud_opt_in", False):
        return

    # S’assure qu’on a bien un ID
    initialiser_cloud_profil(profil)

    event = {
        "cloud_player_id": profil.get("cloud_player_id"),
        "event_type": event_type,
        "payload": payload or {},
        "timestamp": datetime.utcnow().isoformat() + "Z",
        # Plus tard : version du jeu, plateforme, langue, etc.
    }

    enregistrer_event_localement(event)
