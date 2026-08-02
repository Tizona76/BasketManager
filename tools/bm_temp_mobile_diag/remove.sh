#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/isidroetannebosch/Dev/BasketManager_GIT"
TOOL_DIR="$ROOT/tools/bm_temp_mobile_diag"
STATE_DIR="${BM_DIAG_STATE_DIR:-$TOOL_DIR/.active_install}"
MANIFEST="$STATE_DIR/manifest.env"
CHECK_ONLY=0
[ "${1:-}" != "--check-only" ] || CHECK_ONLY=1

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

load_manifest() {
  [ -f "$MANIFEST" ] || die "no active diagnostic manifest found: $MANIFEST"
  # shellcheck disable=SC1090
  . "$MANIFEST"
}

require_repo() {
  cd "$ROOT"
  local pwd_real top
  pwd_real="$(pwd -P)"
  top="$(git rev-parse --show-toplevel)"
  [ "$pwd_real" = "$ROOT" ] || die "wrong pwd: $pwd_real"
  [ "$top" = "$ROOT" ] || die "wrong git root: $top"
}

verify_installed_hashes() {
  if is_export_after_install; then
    return 2
  fi
  [ -f "$BM_DIAG_INDEX_HTML" ] || die "instrumented index.html missing"
  [ "$(sha256 "$BM_DIAG_INDEX_HTML")" = "$BM_DIAG_HTML_SHA_AFTER" ] || die "index.html changed after diagnostic installation; refusing to overwrite"
  [ -f "$BM_DIAG_JS_FILE" ] || die "diagnostic JS file missing"
  [ "$(sha256 "$BM_DIAG_JS_FILE")" = "$BM_DIAG_JS_ASSET_SHA" ] || die "diagnostic JS changed after installation"
  [ -f "$BM_DIAG_CSS_FILE" ] || die "diagnostic CSS file missing"
  [ "$(sha256 "$BM_DIAG_CSS_FILE")" = "$BM_DIAG_CSS_ASSET_SHA" ] || die "diagnostic CSS changed after installation"
  [ -f "$BM_DIAG_INDEX_JS" ] || die "index.js missing"
  [ "$(sha256 "$BM_DIAG_INDEX_JS")" = "$BM_DIAG_INDEX_JS_SHA_BEFORE" ] || die "index.js changed unexpectedly"
  if [ "$BM_DIAG_INDEX_PCK_SHA_BEFORE" != "missing" ]; then
    [ -f "$BM_DIAG_INDEX_PCK" ] || die "index.pck missing"
    [ "$(sha256 "$BM_DIAG_INDEX_PCK")" = "$BM_DIAG_INDEX_PCK_SHA_BEFORE" ] || die "index.pck changed unexpectedly"
  fi
  [ "$(sha256 "$BM_DIAG_PRESET")" = "$BM_DIAG_PRESET_SHA_BEFORE" ] || die "export preset changed unexpectedly"
}

is_export_after_install() {
  local current_html_sha markers_present
  [ -f "$BM_DIAG_INDEX_HTML" ] || return 1
  current_html_sha="$(sha256 "$BM_DIAG_INDEX_HTML")"
  markers_present=no
  if grep -q "BM_TEMP_MOBILE_DIAG_BEGIN" "$BM_DIAG_INDEX_HTML"; then
    markers_present=yes
  fi
  [ "$markers_present" = no ] && [ "$current_html_sha" != "$BM_DIAG_HTML_SHA_AFTER" ]
}

check_marker_state() {
  grep -q "BM_TEMP_MOBILE_DIAG_BEGIN" "$BM_DIAG_INDEX_HTML" || die "expected diagnostic marker missing from index.html"
  grep -q "bm_mobile_web_diag.js" "$BM_DIAG_INDEX_HTML" || die "expected diagnostic JS reference missing"
  grep -q "bm_mobile_web_diag.css" "$BM_DIAG_INDEX_HTML" || die "expected diagnostic CSS reference missing"
}

restore_files() {
  cp "$STATE_DIR/baseline/index.html" "$BM_DIAG_INDEX_HTML"
  [ "$(sha256 "$BM_DIAG_INDEX_HTML")" = "$BM_DIAG_HTML_SHA_BEFORE" ] || die "restored index.html sha mismatch"
  rm -f "$BM_DIAG_JS_FILE"
  rm -f "$BM_DIAG_CSS_FILE"
}

verify_clean() {
  [ ! -f "$BM_DIAG_JS_FILE" ] || die "diagnostic JS still present"
  [ ! -f "$BM_DIAG_CSS_FILE" ] || die "diagnostic CSS still present"
  if grep -R "BM_TEMP_MOBILE_DIAG\|bm_mobile_web_diag.js\|bm_mobile_web_diag.css" "$BM_DIAG_WEB_ROOT" >/dev/null 2>&1; then
    die "diagnostic marker or reference remains in web root"
  fi
  [ "$(sha256 "$BM_DIAG_INDEX_JS")" = "$BM_DIAG_INDEX_JS_SHA_BEFORE" ] || die "index.js sha changed"
  if [ "$BM_DIAG_INDEX_PCK_SHA_BEFORE" != "missing" ]; then
    [ "$(sha256 "$BM_DIAG_INDEX_PCK")" = "$BM_DIAG_INDEX_PCK_SHA_BEFORE" ] || die "index.pck sha changed"
  fi
  [ "$(sha256 "$BM_DIAG_PRESET")" = "$BM_DIAG_PRESET_SHA_BEFORE" ] || die "preset sha changed"
}

remove_state_and_tool_if_real() {
  rm -f "$STATE_DIR/baseline/index.html"
  rm -f "$STATE_DIR/baseline/index.js"
  rm -f "$STATE_DIR/baseline/index.pck"
  rm -f "$STATE_DIR/baseline/export_presets.cfg"
  rm -f "$STATE_DIR/index.html.instrumented"
  rm -f "$MANIFEST"
  rmdir "$STATE_DIR/baseline" 2>/dev/null || true
  rmdir "$STATE_DIR" 2>/dev/null || true
  if [ "${BM_DIAG_KEEP_TOOL:-0}" = "1" ]; then
    return
  fi
  rm -f "$TOOL_DIR/install.sh"
  rm -f "$TOOL_DIR/status.sh"
  rm -f "$TOOL_DIR/bm_mobile_web_diag.js"
  rm -f "$TOOL_DIR/bm_mobile_web_diag.css"
  rm -f "$TOOL_DIR/README_TEMP_DIAG.md"
  rm -f "$TOOL_DIR/remove.sh"
  rmdir "$TOOL_DIR" 2>/dev/null || true
}

clear_stale_export_state() {
  if [ -f "$BM_DIAG_JS_FILE" ]; then
    [ "$(sha256 "$BM_DIAG_JS_FILE")" = "$BM_DIAG_JS_ASSET_SHA" ] || die "stale diagnostic JS was modified; refusing automatic cleanup"
    [ "$CHECK_ONLY" = "1" ] || rm -f "$BM_DIAG_JS_FILE"
  fi
  if [ -f "$BM_DIAG_CSS_FILE" ]; then
    [ "$(sha256 "$BM_DIAG_CSS_FILE")" = "$BM_DIAG_CSS_ASSET_SHA" ] || die "stale diagnostic CSS was modified; refusing automatic cleanup"
    [ "$CHECK_ONLY" = "1" ] || rm -f "$BM_DIAG_CSS_FILE"
  fi
  if [ "$CHECK_ONLY" = "1" ]; then
    echo "BM diagnostic stale export state detected"
    echo "Would remove stale manifest only; no previous index.html would be restored."
    echo "Next install can run safely after this cleanup."
    exit 0
  fi
  rm -f "$STATE_DIR/baseline/index.html"
  rm -f "$STATE_DIR/baseline/index.js"
  rm -f "$STATE_DIR/baseline/index.pck"
  rm -f "$STATE_DIR/baseline/export_presets.cfg"
  rm -f "$STATE_DIR/index.html.instrumented"
  rm -f "$MANIFEST"
  rmdir "$STATE_DIR/baseline" 2>/dev/null || true
  rmdir "$STATE_DIR" 2>/dev/null || true
  echo "BM temporary mobile diagnostic stale manifest removed after fresh export"
  exit 0
}

main() {
  require_repo
  load_manifest
  if verify_installed_hashes; then
    :
  else
    local verify_rc="$?"
    case "$verify_rc" in
      2) clear_stale_export_state ;;
      *) exit 1 ;;
    esac
  fi
  check_marker_state
  if [ "$CHECK_ONLY" = "1" ]; then
    echo "BM diagnostic removal check OK"
    echo "Would restore: $BM_DIAG_INDEX_HTML"
    echo "Would delete:"
    echo " - $BM_DIAG_JS_FILE"
    echo " - $BM_DIAG_CSS_FILE"
    echo "Hashes concord; removal is safe."
    exit 0
  fi
  restore_files
  verify_clean
  remove_state_and_tool_if_real
  echo "BM temporary mobile diagnostic removed and original files restored"
}

main "$@"
