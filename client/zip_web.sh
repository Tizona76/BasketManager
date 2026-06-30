#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/isidroetannebosch/Dev/BasketManager/client"
WEB="$ROOT/web"
OUT="$ROOT/BasketManager_web.zip"

echo "== BasketManager Web ZIP =="
echo "WEB  : $WEB"
echo "OUT  : $OUT"
echo

if [ ! -d "$WEB" ]; then
  echo "[ERR] Dossier web introuvable: $WEB"
  exit 1
fi

cd "$WEB"

# Petite sécurité: vérifier fichiers attendus
for f in index.html index.js index.pck index.wasm; do
  if [ ! -f "$f" ]; then
    echo "[ERR] Fichier manquant dans web/: $f"
    exit 1
  fi
done

echo "[OK] Fichiers export détectés."

# Supprime l'ancien zip
rm -f "$OUT"

# Zip tout le contenu du dossier web
echo "[ZIP] Création du zip..."
zip -r "$OUT" . >/dev/null

echo "[OK] ZIP créé."

# Vérif contenu
echo "[CHK] Contenu du zip:"
unzip -l "$OUT" | head -n 30

echo
echo "[DONE] Upload sur itch: $OUT"

