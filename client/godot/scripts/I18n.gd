extends Node


# Applique tr() partout dans l'arbre.
# Règle :
# - Si un Control a un texte non vide, on le considère comme une KEY (ex: "BTN_ADD")
# - On mémorise la KEY dans meta("i18n_key") la 1ère fois
# - Puis on remplace ctrl.text par tr(key)

func set_locale_and_apply(locale: String) -> void:
	TranslationServer.set_locale(locale)
	apply_all()

func apply_all() -> void:
	var root := get_tree().root
	if root == null:
		return
	_apply_node_recursive(root)

func apply_node(n: Node) -> void:
	_apply_node_recursive(n)

func _bm_i18n_is_mobile_layout() -> bool:
	var vp := get_viewport().get_visible_rect().size
	var win := DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false

func _bm_i18n_apply_mobile_back_text_plus2(ctrl: Control, key: String) -> void:
	if not _bm_i18n_is_mobile_layout():
		return
	if not (ctrl is Button):
		return
	if ctrl.has_meta("bm_mobile_back_text_plus2_done"):
		return
	var txt := str(ctrl.get("text")).strip_edges().to_lower()
	var k := key.strip_edges().to_lower()
	var nm := String(ctrl.name).to_lower()
	if k not in ["btn_back", "btn.back", "teamname.back", "menu.back", "common.back", "back", "retour"] and txt not in ["back", "retour", "volver", "indietro", "voltar"] and not nm.contains("back") and not nm.contains("retour"):
		return
	ctrl.set_meta("bm_mobile_back_text_plus2_done", true)
	var fs: int = int(ctrl.get_theme_font_size("font_size"))
	if fs > 0:
		ctrl.add_theme_font_size_override("font_size", fs + 2)

func _apply_node_recursive(n: Node) -> void:
	# Traduire les Controls qui ont une propriété "text"
	if n is Label or n is Button or n is RichTextLabel:
		_apply_text_control(n as Control)

	for c in n.get_children():
		_apply_node_recursive(c)

func _apply_text_control(ctrl: Control) -> void:
	# On supporte Label/Button/RichTextLabel via propriété "text"
	if not ("text" in ctrl):
		return

	var current := str(ctrl.get("text"))
	if current == "":
		return

	# 1) Mémorise la KEY une seule fois.
	#    IMPORTANT : dans les scènes, mets des KEYS (BTN_ADD etc.)
	if not ctrl.has_meta("i18n_key"):
		ctrl.set_meta("i18n_key", current)

	var key := str(ctrl.get_meta("i18n_key"))
	if key == "":
		return

	# 2) Remplace par traduction
	ctrl.set("text", tr(key))
	_bm_i18n_apply_mobile_back_text_plus2(ctrl, key)
