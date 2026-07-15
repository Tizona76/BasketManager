#!/bin/zsh
set -euo pipefail

SRC="$HOME/Dev/BasketManager_GIT"
DEST="$HOME/Library/Mobile Documents/com~apple~CloudDocs/BasketManager_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="BasketManager_backup_${TS}.zip"
TMP_ZIP="/tmp/${ZIP_NAME}"

mkdir -p "$DEST"
cd "$(dirname "$SRC")"

zip -r "$TMP_ZIP" "$(basename "$SRC")" \
  -x "BasketManager_GIT/**/.git/*" \
  -x "BasketManager_GIT/**/__pycache__/*" \
  -x "BasketManager_GIT/**/.pytest_cache/*" \
  -x "BasketManager_GIT/**/.mypy_cache/*" \
  -x "BasketManager_GIT/**/.DS_Store" \
  -x "BasketManager_GIT/**/venv/*" \
  -x "BasketManager_GIT/**/.venv/*" \
  -x "BasketManager_GIT/**/node_modules/*" \
  -x "BasketManager_GIT/**/build/*" \
  -x "BasketManager_GIT/**/dist/*" \
  -x "BasketManager_GIT/**/export/*" \
  -x "BasketManager_GIT/**/build_nuitka_dist/*" \
  -x "BasketManager_GIT/**/.godot/*"

mv -f "$TMP_ZIP" "$DEST/"

cd "$DEST"
ls -1t BasketManager_backup_*.zip 2>/dev/null | tail -n +11 | xargs -I{} rm -f "{}" || true
