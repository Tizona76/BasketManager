#!/usr/bin/env bash
set -e

# 1) Activer le venv (si tu as un .venv, sinon ce bloc est ignoré)
if [ -d ".venv" ]; then
  source .venv/bin/activate
fi

# 2) Nettoyage de l'ancien build
rm -rf build_nuitka_dist

#!/usr/bin/env bash
set -e

# 1) Activer le venv (si tu as un .venv, sinon ce bloc est ignoré)
if [ -d ".venv" ]; then
  source .venv/bin/activate
fi

# 2) Nettoyage de l'ancien build
rm -rf build_nuitka_dist


# 3) Build Nuitka en mode standalone (SANS .app)
python3 -m nuitka \
  --standalone \
  --output-dir=build_nuitka_dist \
  --include-data-dir=images=images \
  --include-data-dir=fonts=fonts \
  --include-data-dir=sfx=sfx \
  --include-data-dir=assets=assets \
  basket_team_selector.py

