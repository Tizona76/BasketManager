import json, os, time
import urllib.request

API_BASE_DEFAULT = "https://api.basketmanager-game.com"

def _api_base():
    return (os.environ.get("BASKET_API_BASE_URL", "") or "").strip() or API_BASE_DEFAULT

def _api_post_json(url: str, payload: dict, timeout_s: float = 5.0):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url=url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout_s) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        return int(resp.status), body

def _queue_path():
    # Plus tard, on pourra le brancher sur ton dossier de sauvegarde.
    return os.path.join(os.getcwd(), "pending_api_queue.json")

def _queue_load():
    p = _queue_path()
    if not os.path.exists(p):
        return []
    try:
        with open(p, "r", encoding="utf-8") as f:
            arr = json.load(f)
        return arr if isinstance(arr, list) else []
    except Exception:
        return []

def _queue_save(arr):
    try:
        with open(_queue_path(), "w", encoding="utf-8") as f:
            json.dump(arr, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

def api_queue_submit(payload: dict):
    q = _queue_load()
    q.append({"ts": int(time.time()), "kind": "submit", "payload": payload})
    _queue_save(q)

def api_flush_queue(max_items: int = 2):
    q = _queue_load()
    if not q:
        return {"ok": True, "flushed": 0, "remaining": 0}

    base = _api_base()
    flushed = 0
    new_q = []

    for item in q:
        if flushed >= max_items:
            new_q.append(item)
            continue

        if item.get("kind") == "submit":
            try:
                status, _body = _api_post_json(
                    f"{base}/v1/leaderboard/season/submit",
                    item["payload"],
                    timeout_s=5.0
                )
                if 200 <= int(status) < 300:
                    flushed += 1
                    continue
                else:
                    new_q.append(item)
            except Exception:
                new_q.append(item)
        else:
            new_q.append(item)

    _queue_save(new_q)
    return {"ok": True, "flushed": flushed, "remaining": len(new_q)}
