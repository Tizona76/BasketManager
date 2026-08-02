# Basket Manager Temporary Mobile Web Diagnostic

This tool instruments only the exported Web shell in `client/web_release`.
It does not modify Godot scenes, gameplay scripts, saves, assets, `index.js`,
`index.pck`, `project.godot`, or `export_presets.cfg`.

## 1. Installation locale

Recommended workflow:

1. Export Godot to `client/web_release`.
2. Install the diagnostic.
3. Check status.
4. Publish only if explicitly requested.
5. Test.
6. Remove.

```bash
cd /Users/isidroetannebosch/Dev/BasketManager_GIT && \
bash tools/bm_temp_mobile_diag/install.sh
```

Expected result:

- `client/web_release/index.html` gets one marked diagnostic block.
- `client/web_release/bm_mobile_web_diag.js` is created.
- `client/web_release/bm_mobile_web_diag.css` is created.
- Exact backups and hashes are stored in the tool state folder.

If Godot exported a fresh `client/web_release` after a previous diagnostic
installation, the manifest may still exist while the markers are gone. In that
case, run the same install command again. The installer detects the fresh export,
clears only its stale diagnostic state, and installs on the current export.

## 2. Vérification du statut

```bash
cd /Users/isidroetannebosch/Dev/BasketManager_GIT && \
bash tools/bm_temp_mobile_diag/status.sh
```

The status must show `installed=yes` and `safe_to_remove=yes`.

If it shows `export_after_install=yes` and `safe_to_reinstall=yes`, run:

```bash
cd /Users/isidroetannebosch/Dev/BasketManager_GIT && \
bash tools/bm_temp_mobile_diag/install.sh
```

## 3. Publication éventuelle uniquement sur instruction séparée

This tool does not export Godot and does not publish to itch.io.
If a diagnostic build must be published later, do that only after a separate
explicit instruction. The official channel remains:

```text
tizona2026/basket-manager:html5
```

## 4. Ouverture du diagnostic sur iPhone

If the URL can pass parameters to the game document, use:

```text
?bm_diag=1
```

or:

```text
#bm_diag=1
```

If query/hash activation is swallowed by itch.io, use five quick taps in the
top-left corner within three seconds.

## 5. Activation du panneau

Available activation methods:

- automatic with `bm_diag=1`;
- five quick top-left taps on mobile;
- `Ctrl + Shift + D` on desktop;
- small `diag` button in the instrumented build.

The panel starts in Standard mode. Standard mode is meant for quick user
feedback: browser, iframe/direct, viewport, visual viewport, canvas visibility,
health score, synthesis and findings.

Use `Mode: Expert` when you need the full flight recorder:

- metric histories over time;
- automatic deltas with green/orange/red severity;
- Godot viewport observations available from the Web shell;
- full raw JSON;
- report comparison by pasting one or more previous JSON reports.

## 6. Ordre recommandé des tests

Recommended matrix:

- iPhone 14 Safari portrait;
- iPhone 14 Safari landscape;
- iPhone 14 Chrome portrait;
- iPhone 14 Chrome landscape;
- Safari Mac;
- Chrome Mac;
- itch.io embedded page;
- direct access if available;
- Safari bars visible;
- Safari bars hidden;
- initial load;
- rotation;
- return from background;
- vertical drag;
- pinch.

Recommended sequence per environment:

1. Open the game fresh.
2. Mark `Barre Safari visible`.
3. Mark `Jeu trop haut observé` or `Affichage correct`.
4. Mark `Avant tentative de scroll`.
5. Try a one-finger vertical drag starting on the game canvas.
6. Mark `Après tentative de scroll`.
7. Mark `Avant pinch`.
8. Pinch in and out.
9. Mark `Après pinch`.
10. Rotate once and mark before/after rotation.
11. Background the browser, return, and mark `Retour depuis arrière-plan`.

## 7. Export du rapport

In the panel:

- `Copy short` copies a short report suitable for chat.
- `Copy summary JSON` copies the enriched diagnosis summary.
- `Copy raw JSON` copies the full flight-recorder JSON if clipboard permission
  is available.
- `Download JSON` creates a local `.json` file.
- `Download TXT` creates a local summary.
- If clipboard or download fails, show raw data and select/copy manually.

No report is sent to a server by this diagnostic.

For multi-browser comparison, collect one JSON per environment, open Expert
mode, paste the previous JSON reports into `Compare reports`, then run the
comparison. The current session is automatically included.

## 8. Suppression avec `--check-only`

```bash
cd /Users/isidroetannebosch/Dev/BasketManager_GIT && \
bash tools/bm_temp_mobile_diag/remove.sh --check-only
```

This reports what would be restored or deleted and verifies hashes before any
write.

## 9. Suppression finale en une commande

```bash
cd /Users/isidroetannebosch/Dev/BasketManager_GIT && \
bash tools/bm_temp_mobile_diag/remove.sh
```

This restores the exact original `index.html`, deletes only diagnostic files
created by the installer, verifies no marker remains, then removes the temporary
tool folder.

## 10. Version distante déjà publiée

Local removal cannot remove an already-published diagnostic build from itch.io.
If a diagnostic build was published, the cleanup sequence is:

1. remove/restore locally with this tool;
2. validate the local clean build;
3. perform a clean official Web export if needed;
4. verify `GODOT_THREADS_ENABLED = false`;
5. republish cleanly to the official itch.io channel only after explicit
   authorization.

Never rely on the local remover to clean a remote itch.io upload.
