#!/bin/zsh
set -euo pipefail

SRC="$HOME/Dev/BasketManager"
DEST="$HOME/Library/Mobile Documents/com~apple~CloudDocs/BasketManager_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="BasketManager_backup_${TS}.zip"
TMP_ZIP="/tmp/${ZIP_NAME}"

mkdir -p "$DEST"
cd "$(dirname "$SRC")"

zip -r "$TMP_ZIP" "$(basename "$SRC")" \
  -x "BasketManager/**/.git/*" \
  -x "BasketManager/**/__pycache__/*" \
  -x "BasketManager/**/.pytest_cache/*" \
  -x "BasketManager/**/.mypy_cache/*" \
  -x "BasketManager/**/.DS_Store" \
  -x "BasketManager/**/venv/*" \
  -x "BasketManager/**/.venv/*" \
  -x "BasketManager/**/node_modules/*" \
  -x "BasketManager/**/build/*" \
  -x "BasketManager/**/dist/*" \
  -x "BasketManager/**/export/*" \
  -x "BasketManager/**/build_nuitka_dist/*" \
  -x "BasketManager/**/.godot/*"

mv -f "$TMP_ZIP" "$DEST/"

cd "$DEST"
ls -1t BasketManager_backup_*.zip 2>/dev/null | tail -n +11 | xargs -I{} rm -f "{}" || true
