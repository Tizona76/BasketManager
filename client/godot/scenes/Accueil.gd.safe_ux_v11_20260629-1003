extends Node2D

signal intro_zoom_finished

@onready var logo: Sprite2D = $Logo
const STADIUM_INTRO_TEXTURE := preload("res://assets/images/stades/stade_13.png")

@export var duration: float = 2.35
@export var start_scale: float = 0.397953
@export var end_scale: float = 0.612
@export var start_alpha: float = 1.0
@export var end_alpha: float = 1.0

var _started: bool = false
var tooltip_label: Label = null
var _mobile_cover_layer: CanvasLayer = null
var _mobile_cover_rect: TextureRect = null

func _ready() -> void:

	# Tooltip création
	tooltip_label = Label.new()
	tooltip_label.text = "Choose a language"
	tooltip_label.visible = false
	tooltip_label.modulate.a = 0.9
	add_child(tooltip_label)

	_center_logo()
	_bm_apply_mobile_layout()


	if not _bm_is_mobile_layout():
		logo.scale = Vector2(start_scale, start_scale)
	logo.modulate.a = start_alpha
	logo.visible = false

	# ✅ branchement i18n drapeaux (si présents)
	_connect_flag("BtnFr", "fr")
	_connect_flag("BtnEn", "en")
	_connect_flag("BtnEs", "es")
	_connect_flag("BtnIt", "it")
	_connect_flag("BtnPt", "pt")



func _bm_apply_mobile_layout() -> void:
	if not _bm_is_mobile_layout():
		return

	var vp: Vector2 = get_viewport_rect().size

	# fond cover plein écran mobile : aucune déformation, crop accepté
	if logo != null and logo.texture != null:
		var tex_size: Vector2 = logo.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var cover_scale: float = maxf(vp.x / tex_size.x, vp.y / tex_size.y)
			logo.centered = true
			logo.position = vp * 0.5
			logo.scale = Vector2(cover_scale, cover_scale)

	# CTA mobile ciblé uniquement
	var btn: Control = find_child("BtnClickToPlay", true, false) as Control
	if btn != null:
		btn.scale = Vector2(1.6, 1.6)
		btn.custom_minimum_size = Vector2(360.0, 96.0)
		btn.position = Vector2(
			(vp.x - btn.size.x * btn.scale.x) * 0.5,
			vp.y - (btn.size.y * btn.scale.y) - 88.0
		)


func _connect_flag(node_name: String, code: String) -> void:
	var b := get_node_or_null("UI/" + node_name)
	if b == null:
		b = get_node_or_null(node_name)
	if b == null:
		return

	# Tooltip explicite
	var lang_name := code
	match code:
		"fr":
			lang_name = "French"
		"en":
			lang_name = "English"
		"es":
			lang_name = "Spanish"
		"it":
			lang_name = "Italian"
		"pt":
			lang_name = "Portuguese"

	if "tooltip_text" in b:
		b.tooltip_text = "Choose " + lang_name


	# TextureButton et Button ont un signal "pressed"
	if b.has_signal("pressed"):
		# Hover tooltip
		b.connect("mouse_entered", Callable(self, "_on_flag_hover"))
		b.connect("mouse_exited", Callable(self, "_on_flag_exit"))

		var cb := Callable(self, "_on_flag_pressed").bind(code)
		if not b.is_connected("pressed", cb):
			b.connect("pressed", cb)

func _on_flag_pressed(code: String) -> void:
	# Trouve Main (script Main.gd sur la scène Main.tscn)
	var main := get_tree().root.find_child("Main", true, false)
	if main != null and main.has_method("_apply_language"):
		main.call("_apply_language", code)
	else:
		# fallback si jamais
		TranslationServer.set_locale(code)
		I18nSvc.apply_all()
		get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)

func start_intro() -> void:
	if _started:
		return
	_started = true

	# Remplacer logo par stade AU MOMENT DU CLIC
	if _bm_is_mobile_layout():
		logo.visible = false
		logo.modulate.a = 0.0
		_bm_show_mobile_cover(STADIUM_INTRO_TEXTURE)
	else:
		logo.visible = true
		logo.texture = STADIUM_INTRO_TEXTURE

	# reset propre pour zoom
	var vp := get_viewport_rect().size
	if not _bm_is_mobile_layout():
		var tex_size := logo.texture.get_size()
		var cover_scale: float = max(vp.x / tex_size.x, vp.y / tex_size.y)
		var zoom_ratio: float = end_scale / max(0.001, start_scale)
		logo.scale = Vector2(cover_scale, cover_scale)
		end_scale = cover_scale * zoom_ratio
		logo.modulate.a = 1.0
		logo.position = Vector2(vp.x * 0.5, vp.y * 0.47)

	_start_logo_tween()


func _bm_show_mobile_cover(tex: Texture2D) -> void:
	var vp: Vector2 = get_viewport_rect().size

	if _mobile_cover_layer == null:
		_mobile_cover_layer = CanvasLayer.new()
		_mobile_cover_layer.name = "MobileCoverCanvasLayer"
		_mobile_cover_layer.layer = 20
		add_child(_mobile_cover_layer)

	if _mobile_cover_rect == null:
		_mobile_cover_rect = TextureRect.new()
		_mobile_cover_rect.name = "MobileCoverTextureRect"
		_mobile_cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mobile_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mobile_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_mobile_cover_layer.add_child(_mobile_cover_rect)

	_mobile_cover_rect.texture = tex
	_mobile_cover_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mobile_cover_rect.position = Vector2.ZERO
	_mobile_cover_rect.size = vp
	_mobile_cover_rect.custom_minimum_size = vp
	_mobile_cover_rect.pivot_offset = vp * 0.5
	_mobile_cover_rect.scale = Vector2.ONE
	_mobile_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Mobile intro: garder les proportions de stade_13, jamais d'étirement vertical.
	_mobile_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mobile_cover_rect.modulate.a = 1.0
	_mobile_cover_rect.visible = true

	print("[ACCUEIL][MOBILE_COVER] tex=", tex.resource_path, " vp=", vp, " tex_size=", tex.get_size(), " stretch=", _mobile_cover_rect.stretch_mode)


func _start_logo_tween() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	if _bm_is_mobile_layout():
		if _mobile_cover_rect != null:
			# Zoom uniforme uniquement : même scale X/Y pour éviter toute déformation verticale.
			tw.tween_property(_mobile_cover_rect, "scale", Vector2(1.54, 1.54), duration)
			tw.parallel().tween_property(_mobile_cover_rect, "modulate:a", end_alpha, duration)
	else:
		tw.tween_property(logo, "scale", Vector2(end_scale, end_scale), duration)
		tw.parallel().tween_property(logo, "modulate:a", end_alpha, duration)
	tw.finished.connect(func(): intro_zoom_finished.emit(), CONNECT_ONE_SHOT)


func _bm_is_mobile_layout() -> bool:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	if OS.has_feature("android") or OS.has_feature("ios") or minf(vp.x, float(win.x)) < 900.0:
		return true
	if OS.has_feature("web"):
		var js_mobile: Variant = JavaScriptBridge.eval("(window.innerWidth < 900) || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)", true)
		return bool(js_mobile)
	return false


func _center_logo() -> void:
	var vp: Vector2 = get_viewport_rect().size

	if _bm_is_mobile_layout():
		return

	logo.position = Vector2(vp.x * 0.5, vp.y * 0.87)
	logo.scale *= 0.8


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_center_logo()
		_bm_apply_mobile_layout()
		if _mobile_cover_rect != null:
			var vp: Vector2 = get_viewport_rect().size
			_mobile_cover_rect.position = Vector2.ZERO
			_mobile_cover_rect.size = vp
			_mobile_cover_rect.custom_minimum_size = vp
			_mobile_cover_rect.pivot_offset = vp * 0.5
