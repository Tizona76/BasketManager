#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/isidroetannebosch/Dev/BasketManager_GIT"
TOOL_DIR="$ROOT/tools/bm_temp_mobile_diag"
WEB_ROOT="${BM_DIAG_WEB_ROOT:-$ROOT/client/web_release}"
STATE_DIR="${BM_DIAG_STATE_DIR:-$TOOL_DIR/.active_install}"
MANIFEST="$STATE_DIR/manifest.env"
BEGIN_MARKER="<!-- BM_TEMP_MOBILE_DIAG_BEGIN -->"
END_MARKER="<!-- BM_TEMP_MOBILE_DIAG_END -->"
JS_NAME="bm_mobile_web_diag.js"
CSS_NAME="bm_mobile_web_diag.css"
INDEX_HTML="$WEB_ROOT/index.html"
INDEX_JS="$WEB_ROOT/index.js"
INDEX_PCK="$WEB_ROOT/index.pck"
PRESET="$ROOT/client/godot/export_presets.cfg"

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

size_bytes() {
  wc -c < "$1" | tr -d ' '
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_repo() {
  cd "$ROOT"
  local pwd_real top
  pwd_real="$(pwd -P)"
  top="$(git rev-parse --show-toplevel)"
  [ "$pwd_real" = "$ROOT" ] || die "wrong pwd: $pwd_real"
  [ "$top" = "$ROOT" ] || die "wrong git root: $top"
}

require_files() {
  [ -d "$ROOT/client/godot" ] || die "missing Godot project"
  [ -d "$WEB_ROOT" ] || die "missing web root: $WEB_ROOT"
  [ -f "$INDEX_HTML" ] || die "missing index.html"
  [ -f "$INDEX_JS" ] || die "missing index.js"
  [ -f "$TOOL_DIR/$JS_NAME" ] || die "missing diagnostic JS"
  [ -f "$TOOL_DIR/$CSS_NAME" ] || die "missing diagnostic CSS"
  [ -f "$PRESET" ] || die "missing export_presets.cfg"
}

require_no_active_install() {
  [ ! -e "$STATE_DIR" ] || die "diagnostic already installed or state directory exists: $STATE_DIR"
  if grep -q "BM_TEMP_MOBILE_DIAG" "$INDEX_HTML"; then
    die "diagnostic markers already present in index.html without this installer state"
  fi
  if grep -q "$JS_NAME\|$CSS_NAME" "$INDEX_HTML"; then
    die "diagnostic references already present in index.html"
  fi
}

inject_html() {
  local tmp="$STATE_DIR/index.html.instrumented"
  python3 - "$INDEX_HTML" "$tmp" "$BEGIN_MARKER" "$END_MARKER" "$JS_NAME" "$CSS_NAME" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
begin, end, js, css = sys.argv[3:7]
text = src.read_text(encoding="utf-8")
if begin in text or end in text:
    raise SystemExit("markers already present")
needle = "</head>"
if needle not in text:
    raise SystemExit("missing </head>")
block = f"""{begin}
<link rel="stylesheet" href="{css}">
<script defer src="{js}"></script>
{end}
"""
dst.write_text(text.replace(needle, block + needle, 1), encoding="utf-8")
PY
  cp "$tmp" "$INDEX_HTML"
}

main() {
  require_repo
  require_files
  require_no_active_install

  mkdir -p "$STATE_DIR/baseline"
  local install_id now html_sha_before js_sha_before pck_sha_before preset_sha_before
  install_id="bm_diag_$(date -u +%Y%m%dT%H%M%SZ)_$$"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  html_sha_before="$(sha256 "$INDEX_HTML")"
  js_sha_before="$(sha256 "$INDEX_JS")"
  pck_sha_before="$([ -f "$INDEX_PCK" ] && sha256 "$INDEX_PCK" || echo "missing")"
  preset_sha_before="$(sha256 "$PRESET")"

  cp "$INDEX_HTML" "$STATE_DIR/baseline/index.html"
  cp "$INDEX_JS" "$STATE_DIR/baseline/index.js"
  [ ! -f "$INDEX_PCK" ] || cp "$INDEX_PCK" "$STATE_DIR/baseline/index.pck"
  cp "$PRESET" "$STATE_DIR/baseline/export_presets.cfg"

  cp "$TOOL_DIR/$JS_NAME" "$WEB_ROOT/$JS_NAME"
  cp "$TOOL_DIR/$CSS_NAME" "$WEB_ROOT/$CSS_NAME"
  inject_html

  grep -q "BM_TEMP_MOBILE_DIAG_BEGIN" "$INDEX_HTML" || die "marker not injected"
  grep -q "$JS_NAME" "$INDEX_HTML" || die "JS reference missing"
  grep -q "$CSS_NAME" "$INDEX_HTML" || die "CSS reference missing"
  [ "$(sha256 "$INDEX_JS")" = "$js_sha_before" ] || die "index.js changed unexpectedly"
  if [ -f "$INDEX_PCK" ]; then
    [ "$(sha256 "$INDEX_PCK")" = "$pck_sha_before" ] || die "index.pck changed unexpectedly"
  fi
  [ "$(sha256 "$PRESET")" = "$preset_sha_before" ] || die "export preset changed unexpectedly"
  grep -q "GODOT_THREADS_ENABLED = false" "$INDEX_HTML" || die "GODOT_THREADS_ENABLED=false not found"

  local html_sha_after js_asset_sha css_asset_sha
  html_sha_after="$(sha256 "$INDEX_HTML")"
  js_asset_sha="$(sha256 "$WEB_ROOT/$JS_NAME")"
  css_asset_sha="$(sha256 "$WEB_ROOT/$CSS_NAME")"

  cat > "$MANIFEST" <<EOF
BM_DIAG_INSTALL_ID='$install_id'
BM_DIAG_INSTALLED_AT_UTC='$now'
BM_DIAG_ROOT='$ROOT'
BM_DIAG_WEB_ROOT='$WEB_ROOT'
BM_DIAG_INDEX_HTML='$INDEX_HTML'
BM_DIAG_INDEX_JS='$INDEX_JS'
BM_DIAG_INDEX_PCK='$INDEX_PCK'
BM_DIAG_PRESET='$PRESET'
BM_DIAG_JS_FILE='$WEB_ROOT/$JS_NAME'
BM_DIAG_CSS_FILE='$WEB_ROOT/$CSS_NAME'
BM_DIAG_HTML_SHA_BEFORE='$html_sha_before'
BM_DIAG_HTML_SHA_AFTER='$html_sha_after'
BM_DIAG_INDEX_JS_SHA_BEFORE='$js_sha_before'
BM_DIAG_INDEX_PCK_SHA_BEFORE='$pck_sha_before'
BM_DIAG_PRESET_SHA_BEFORE='$preset_sha_before'
BM_DIAG_JS_ASSET_SHA='$js_asset_sha'
BM_DIAG_CSS_ASSET_SHA='$css_asset_sha'
BM_DIAG_INDEX_HTML_SIZE_BEFORE='$(size_bytes "$STATE_DIR/baseline/index.html")'
BM_DIAG_INDEX_HTML_SIZE_AFTER='$(size_bytes "$INDEX_HTML")'
BM_DIAG_CREATED_FILES='$WEB_ROOT/$JS_NAME;$WEB_ROOT/$CSS_NAME'
BM_DIAG_MARKERS='BM_TEMP_MOBILE_DIAG_BEGIN;BM_TEMP_MOBILE_DIAG_END'
EOF

  echo "BM temporary mobile diagnostic installed"
  echo "install_id=$install_id"
  echo "web_root=$WEB_ROOT"
  echo "index_html_sha_before=$html_sha_before"
  echo "index_html_sha_after=$html_sha_after"
  echo "created_files:"
  echo " - $WEB_ROOT/$JS_NAME"
  echo " - $WEB_ROOT/$CSS_NAME"
  echo "No Godot scripts, scenes, saves, index.js, index.pck or presets were modified."
}

main "$@"
