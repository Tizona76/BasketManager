#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/isidroetannebosch/Dev/BasketManager_GIT"
TOOL_DIR="$ROOT/tools/bm_temp_mobile_diag"
STATE_DIR="${BM_DIAG_STATE_DIR:-$TOOL_DIR/.active_install}"
MANIFEST="$STATE_DIR/manifest.env"
DEFAULT_WEB_ROOT="${BM_DIAG_WEB_ROOT:-$ROOT/client/web_release}"

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

cd "$ROOT"
echo "BM temporary mobile diagnostic status"
echo "root=$(pwd -P)"
echo "git_root=$(git rev-parse --show-toplevel)"

if [ ! -f "$MANIFEST" ]; then
  echo "installed=no"
  if grep -R "BM_TEMP_MOBILE_DIAG\|bm_mobile_web_diag.js\|bm_mobile_web_diag.css" "$DEFAULT_WEB_ROOT" >/dev/null 2>&1; then
    echo "markers_or_references=present_without_manifest"
    exit 2
  fi
  echo "markers_or_references=absent"
  exit 0
fi

# shellcheck disable=SC1090
. "$MANIFEST"
echo "installed=yes"
echo "install_id=$BM_DIAG_INSTALL_ID"
echo "web_root=$BM_DIAG_WEB_ROOT"
echo "manifest=$MANIFEST"

html_ok=no
js_ok=no
css_ok=no
index_js_ok=no
pck_ok=not_applicable
preset_ok=no
markers=missing

[ -f "$BM_DIAG_INDEX_HTML" ] && [ "$(sha256 "$BM_DIAG_INDEX_HTML")" = "$BM_DIAG_HTML_SHA_AFTER" ] && html_ok=yes
[ -f "$BM_DIAG_JS_FILE" ] && [ "$(sha256 "$BM_DIAG_JS_FILE")" = "$BM_DIAG_JS_ASSET_SHA" ] && js_ok=yes
[ -f "$BM_DIAG_CSS_FILE" ] && [ "$(sha256 "$BM_DIAG_CSS_FILE")" = "$BM_DIAG_CSS_ASSET_SHA" ] && css_ok=yes
[ -f "$BM_DIAG_INDEX_JS" ] && [ "$(sha256 "$BM_DIAG_INDEX_JS")" = "$BM_DIAG_INDEX_JS_SHA_BEFORE" ] && index_js_ok=yes
if [ "$BM_DIAG_INDEX_PCK_SHA_BEFORE" != "missing" ]; then
  pck_ok=no
  [ -f "$BM_DIAG_INDEX_PCK" ] && [ "$(sha256 "$BM_DIAG_INDEX_PCK")" = "$BM_DIAG_INDEX_PCK_SHA_BEFORE" ] && pck_ok=yes
fi
[ -f "$BM_DIAG_PRESET" ] && [ "$(sha256 "$BM_DIAG_PRESET")" = "$BM_DIAG_PRESET_SHA_BEFORE" ] && preset_ok=yes
if grep -q "BM_TEMP_MOBILE_DIAG_BEGIN" "$BM_DIAG_INDEX_HTML" && grep -q "bm_mobile_web_diag.js" "$BM_DIAG_INDEX_HTML"; then
  markers=present
fi

export_after_install=no
if [ "$markers" = missing ] && [ "$html_ok" = no ]; then
  export_after_install=yes
fi

echo "index_html_hash_ok=$html_ok"
echo "diagnostic_js_hash_ok=$js_ok"
echo "diagnostic_css_hash_ok=$css_ok"
echo "index_js_unchanged=$index_js_ok"
echo "index_pck_unchanged=$pck_ok"
echo "preset_unchanged=$preset_ok"
echo "markers=$markers"
echo "export_after_install=$export_after_install"

if [ "$html_ok" = yes ] && [ "$js_ok" = yes ] && [ "$css_ok" = yes ] && [ "$index_js_ok" = yes ] && [ "$pck_ok" != no ] && [ "$preset_ok" = yes ] && [ "$markers" = present ]; then
  echo "safe_to_remove=yes"
elif [ "$export_after_install" = yes ]; then
  echo "safe_to_remove=no"
  echo "safe_to_reinstall=yes"
  echo "next_step=bash tools/bm_temp_mobile_diag/install.sh"
  exit 4
else
  echo "safe_to_remove=no"
  echo "safe_to_reinstall=no"
  exit 3
fi
