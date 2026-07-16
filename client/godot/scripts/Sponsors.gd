extends Control

const SponsorDataRef := preload("res://scripts/SponsorData.gd")
const PlayerLife := preload("res://scripts/PlayerLife.gd")

const TEXT_PRIMARY := Color(0.96, 0.99, 1.0, 1.0)
const TEXT_SECONDARY := Color(0.78, 0.88, 0.95, 0.96)
const TEXT_DETAIL := Color(0.86, 0.94, 1.0, 0.94)
const TEXT_GOLD := Color(1.0, 0.82, 0.28, 1.0)
const TEXT_GREEN := Color(0.35, 1.0, 0.48, 1.0)
const TEXT_SHADOW := Color(0, 0, 0, 0.58)

static var active_sponsor_id: String = ""

@onready var title_label: Label = get_node_or_null("UI/Title") as Label
@onready var subtitle_label: Label = get_node_or_null("UI/Panel/Margin/VBox/Subtitle") as Label
@onready var current_title_label: Label = get_node_or_null("UI/Panel/Margin/VBox/CurrentSponsorTitle") as Label
@onready var current_empty_label: Label = get_node_or_null("UI/Panel/Margin/VBox/CurrentSponsorEmpty") as Label
@onready var offers_title_label: Label = get_node_or_null("UI/Panel/Margin/VBox/AvailableOffersTitle") as Label
@onready var offers_empty_label: Label = get_node_or_null("UI/Panel/Margin/VBox/AvailableOffersEmpty") as Label
@onready var info_label: Label = get_node_or_null("UI/Panel/Margin/VBox/Info") as Label
@onready var btn_retour: Button = get_node_or_null("UI/BtnRetour") as Button
@onready var vbox: VBoxContainer = get_node_or_null("UI/Panel/Margin/VBox") as VBoxContainer

var _offers_grid: GridContainer = null
var _confirm_popup: PanelContainer = null
var _pending_sponsor_id: String = ""
var _active_contract: Dictionary = {}


func _get_progressive_offer_families(club_level: int) -> Array[String]:
	match maxi(1, club_level):
		1:
			return [SponsorDataRef.FAMILY_LOCAL, SponsorDataRef.FAMILY_LOCAL, SponsorDataRef.FAMILY_LOCAL]
		2:
			return [SponsorDataRef.FAMILY_LOCAL, SponsorDataRef.FAMILY_LOCAL, SponsorDataRef.FAMILY_NATIONAL]
		3:
			return [SponsorDataRef.FAMILY_NATIONAL, SponsorDataRef.FAMILY_NATIONAL, SponsorDataRef.FAMILY_NATIONAL]
		4:
			return [SponsorDataRef.FAMILY_NATIONAL, SponsorDataRef.FAMILY_NATIONAL, SponsorDataRef.FAMILY_PREMIUM]
		_:
			return [SponsorDataRef.FAMILY_PREMIUM, SponsorDataRef.FAMILY_PREMIUM, SponsorDataRef.FAMILY_PREMIUM]


func _remove_one_offer_family_slot(families: Array[String], family: String) -> void:
	for i in range(families.size()):
		if families[i] == family:
			families.remove_at(i)
			return


func _add_sponsor_offer(offers: Array, used_ids: Array[String], sponsor: Dictionary) -> bool:
	var sponsor_id := str(sponsor.get("id", ""))
	if sponsor_id == "" or used_ids.has(sponsor_id):
		return false
	offers.append(sponsor.duplicate(true))
	used_ids.append(sponsor_id)
	return true


func _add_offer_from_family(offers: Array, used_ids: Array[String], family: String, preferred_ids: Array[String], avoid_ids: Array[String]) -> bool:
	for preferred_id in preferred_ids:
		if avoid_ids.has(preferred_id):
			continue
		var preferred_sponsor := SponsorDataRef.get_sponsor_by_id(preferred_id)
		if not preferred_sponsor.is_empty() and str(preferred_sponsor.get("family", "")) == family:
			if _add_sponsor_offer(offers, used_ids, preferred_sponsor):
				return true

	for sponsor in SponsorDataRef.SPONSORS:
		var sponsor_dict := sponsor as Dictionary
		var sponsor_id := str(sponsor_dict.get("id", ""))
		if avoid_ids.has(sponsor_id):
			continue
		if str(sponsor_dict.get("family", "")) == family:
			if _add_sponsor_offer(offers, used_ids, sponsor_dict):
				return true

	return false


func _get_progressive_sponsor_offers(club_level: int, active_sponsor_id_value: String, known_sponsor_ids: Array[String]) -> Array:
	var offers: Array = []
	var used_ids: Array[String] = []
	var target_families := _get_progressive_offer_families(club_level)

	if active_sponsor_id_value != "":
		var active_sponsor := SponsorDataRef.get_sponsor_by_id(active_sponsor_id_value)
		if not active_sponsor.is_empty():
			_add_sponsor_offer(offers, used_ids, active_sponsor)
			_remove_one_offer_family_slot(target_families, str(active_sponsor.get("family", "")))

	var fresh_ids: Array[String] = []
	for sponsor in SponsorDataRef.SPONSORS:
		var sponsor_id := str((sponsor as Dictionary).get("id", ""))
		if sponsor_id != "" and not known_sponsor_ids.has(sponsor_id):
			fresh_ids.append(sponsor_id)

	for family in target_families:
		if offers.size() >= 3:
			break
		if _add_offer_from_family(offers, used_ids, family, fresh_ids, [active_sponsor_id_value]):
			continue
		_add_offer_from_family(offers, used_ids, family, known_sponsor_ids, [active_sponsor_id_value])

	return offers.slice(0, 3)


func _ready() -> void:
	_apply_i18n()
	if btn_retour != null and not btn_retour.pressed.is_connected(_on_btn_retour):
		btn_retour.pressed.connect(_on_btn_retour)
	_load_active_contract()
	_refresh_sponsor_ui()


func _tr_key(key: String) -> String:
	var value := tr(key)
	if value != "" and value != key:
		return value
	return key


func _money(value: Variant) -> String:
	return _format_bonus_amount(value) + " $"


func _format_bonus_amount(value: Variant) -> String:
	var n: int = abs(int(value))
	var raw := str(n)
	var result := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count == 3:
			result = "." + result
			count = 0
		result = raw[i] + result
		count += 1
	return result


func _apply_i18n() -> void:
	if title_label != null:
		title_label.text = _tr_key("sponsors.title")
		_apply_label_typography(title_label, 46, TEXT_PRIMARY, true, 2)
	if subtitle_label != null:
		subtitle_label.visible = false
	if current_title_label != null:
		current_title_label.visible = false
	if current_empty_label != null:
		current_empty_label.visible = false
	if offers_title_label != null:
		offers_title_label.text = _tr_key("sponsors.available_title")
		_apply_label_typography(offers_title_label, 29, TEXT_GOLD, true, 1)
	if offers_empty_label != null:
		offers_empty_label.text = _tr_key("sponsors.available_empty")
		_apply_label_typography(offers_empty_label, 24, TEXT_SECONDARY, true, 1)
	if info_label != null:
		info_label.text = _tr_key("sponsors.info")
		_apply_label_typography(info_label, 22, TEXT_SECONDARY, true, 1)
	if btn_retour != null:
		btn_retour.text = _tr_key("menu.back")


func _refresh_sponsor_ui() -> void:
	if _offers_grid != null and is_instance_valid(_offers_grid):
		_offers_grid.queue_free()
		_offers_grid = null
	if _confirm_popup != null and is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
		_confirm_popup = null

	if current_title_label != null:
		current_title_label.visible = false
	if current_empty_label != null:
		current_empty_label.visible = false

	if offers_empty_label != null:
		offers_empty_label.visible = false
	if vbox != null and offers_title_label != null:
		var club_level := _get_current_club_level()
		var save: Dictionary = PlayerLife.load_savegame()
		var known_sponsor_ids := SponsorDataRef.get_known_sponsors(save)
		var current_active_id := active_sponsor_id
		if current_active_id == "" and not _active_contract.is_empty():
			current_active_id = str(_active_contract.get("id", ""))
		vbox.add_theme_constant_override("separation", 34)
		_offers_grid = GridContainer.new()
		_offers_grid.name = "AvailableOffersGrid"
		_offers_grid.columns = 3
		_offers_grid.add_theme_constant_override("h_separation", 28)
		_offers_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(_offers_grid)
		vbox.move_child(_offers_grid, offers_title_label.get_index() + 1)
		var offers: Array = _get_progressive_sponsor_offers(club_level, current_active_id, known_sponsor_ids)
		var offered_ids: Array[String] = []
		for sponsor in offers:
			var sponsor_card_data: Dictionary = sponsor as Dictionary
			var offered_id := str(sponsor_card_data.get("id", ""))
			if offered_id != "" and not offered_ids.has(offered_id):
				offered_ids.append(offered_id)
			if not _active_contract.is_empty() and str(_active_contract.get("id", "")) == str(sponsor_card_data.get("id", "")):
				sponsor_card_data = _active_contract.duplicate(true)
			_offers_grid.add_child(_make_sponsor_card(sponsor_card_data, true))
		if SponsorDataRef.remember_sponsor_ids(save, offered_ids):
			PlayerLife.write_savegame(save)
	if _pending_sponsor_id != "":
		_show_confirm_popup(SponsorDataRef.get_sponsor_by_id(_pending_sponsor_id))


func _make_sponsor_card(sponsor: Dictionary, can_sign: bool) -> PanelContainer:
	var sponsor_id := str(sponsor.get("id", ""))
	var is_active: bool = sponsor_id == active_sponsor_id
	var is_pending: bool = sponsor_id == _pending_sponsor_id
	var is_market_closed_for_card: bool = active_sponsor_id != "" and not is_active
	var is_highlighted: bool = is_active or is_pending
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(395, 410)
	card.pivot_offset = card.custom_minimum_size * 0.5
	if is_highlighted:
		card.scale = Vector2(1.09, 1.09)
	if is_market_closed_for_card:
		card.self_modulate = Color(0.72, 0.72, 0.72, 0.62)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.72, 0.72, 0.08) if is_market_closed_for_card else Color(1, 1, 1, 0.18 if is_highlighted else 0.10)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = 2 if is_highlighted else 1
	style.border_width_right = 2 if is_highlighted else 1
	style.border_width_top = 2 if is_highlighted else 1
	style.border_width_bottom = 2 if is_highlighted else 1
	style.border_color = Color(0.1, 0.85, 0.35, 0.95) if is_highlighted else Color(1, 1, 1, 0.18)
	style.shadow_color = Color(0.05, 0.75, 0.25, 0.20) if is_highlighted else Color(0, 0, 0, 0.20)
	style.shadow_size = 5 if is_highlighted else 2
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var badge_row := HBoxContainer.new()
	badge_row.custom_minimum_size = Vector2(0, 8)
	badge_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(badge_row)
	if is_active:
		var remaining_label := _make_label(_format_remaining_text(sponsor), 23, Color(1.0, 0.55, 0.12, 1.0), true)
		remaining_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_child(remaining_label)
		var badge := Label.new()
		badge.text = _tr_key("sponsors.active")
		_apply_label_typography(badge, 18, TEXT_GREEN, true, 1)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge_row.add_child(badge)

	var logo_wrap := CenterContainer.new()
	logo_wrap.custom_minimum_size = Vector2(0, 210)
	box.add_child(logo_wrap)
	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(368, 220)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_path := str(sponsor.get("logo", ""))
	if logo_path == "" or not ResourceLoader.exists(logo_path):
		logo_path = SponsorDataRef.DEFAULT_SPONSOR_LOGO
	if ResourceLoader.exists(logo_path):
		logo.texture = load(logo_path) as Texture2D
	logo_wrap.add_child(logo)

	box.add_child(_make_label(_tr_key(str(sponsor.get("name", sponsor.get("name_key", "")))), 28, TEXT_PRIMARY, true))
	box.add_child(_make_label(_tr_key(str(SponsorDataRef.FAMILY_I18N.get(str(sponsor.get("family", "")), ""))), 23, TEXT_GOLD, true))
	box.add_child(_make_detail_label("sponsors.field.revenue", _money(sponsor.get("payment_amount", 0)) + " / " + _format_payment_unit(str(sponsor.get("payment_type", "")))))
	if int(sponsor.get("bonus_amount", 0)) > 0:
		box.add_child(_make_label(_tr_key("sponsors.field.bonus") + " " + _tr_key(str(SponsorDataRef.BONUS_I18N.get(str(sponsor.get("bonus_type", "")), ""))) + ": + " + _format_bonus_amount(sponsor.get("bonus_amount", 0)) + " $", 22, TEXT_DETAIL, false))
	else:
		box.add_child(_make_detail_label("sponsors.field.bonus", _tr_key("sponsors.bonus.none")))
	box.add_child(_make_detail_label("sponsors.field.duration", str(int(sponsor.get("duration_value", 0))) + " " + _format_duration_unit(str(sponsor.get("duration_type", "")), int(sponsor.get("duration_value", 0)))))

	if can_sign:
		var btn_wrap := MarginContainer.new()
		btn_wrap.add_theme_constant_override("margin_top", 8)
		var btn := Button.new()
		btn.text = _tr_key("sponsors.active") if is_active else (_tr_key("sponsors.unavailable") if is_market_closed_for_card else _tr_key("sponsors.sign_contract"))
		btn.disabled = is_active or is_pending or is_market_closed_for_card
		btn.custom_minimum_size = Vector2(242, 48)
		btn.add_theme_font_size_override("font_size", 23)
		_apply_sponsor_card_button_style(btn, is_active or is_pending or is_market_closed_for_card)
		if not is_active and not is_pending and not is_market_closed_for_card:
			btn.pressed.connect(func() -> void:
				_pending_sponsor_id = sponsor_id
				_refresh_sponsor_ui()
			)
		btn_wrap.add_child(btn)
		box.add_child(btn_wrap)

	return card


func _show_confirm_popup(sponsor: Dictionary) -> void:
	if sponsor.is_empty():
		return
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return

	_confirm_popup = PanelContainer.new()
	_confirm_popup.name = "SponsorConfirmPopup"
	_confirm_popup.layout_mode = 1
	_confirm_popup.anchors_preset = Control.PRESET_CENTER
	_confirm_popup.anchor_left = 0.5
	_confirm_popup.anchor_top = 0.5
	_confirm_popup.anchor_right = 0.5
	_confirm_popup.anchor_bottom = 0.5
	_confirm_popup.offset_left = -260
	_confirm_popup.offset_top = -120
	_confirm_popup.offset_right = 260
	_confirm_popup.offset_bottom = 120
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.03, 0.06, 0.09, 0.94)
	popup_style.corner_radius_top_left = 18
	popup_style.corner_radius_top_right = 18
	popup_style.corner_radius_bottom_left = 18
	popup_style.corner_radius_bottom_right = 18
	popup_style.content_margin_left = 24
	popup_style.content_margin_top = 22
	popup_style.content_margin_right = 24
	popup_style.content_margin_bottom = 22
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.1, 0.85, 0.35, 0.85)
	_confirm_popup.add_theme_stylebox_override("panel", popup_style)
	ui.add_child(_confirm_popup)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	_confirm_popup.add_child(box)

	var title := _make_label(_tr_key("sponsors.confirm_title"), 28, TEXT_PRIMARY, true)
	box.add_child(title)
	var sponsor_name := _tr_key(str(sponsor.get("name", "")))
	var message := _make_label(_tr_key("sponsors.confirm_message") + "\n" + sponsor_name, 21, TEXT_SECONDARY, true)
	box.add_child(message)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)

	var btn_cancel := Button.new()
	btn_cancel.text = _tr_key("login.btn.cancel")
	btn_cancel.custom_minimum_size = Vector2(180, 48)
	btn_cancel.add_theme_font_size_override("font_size", 21)
	_apply_popup_button_style(btn_cancel, Color(0.82, 0.12, 0.12, 1), Color(1, 0.24, 0.24, 1))
	btn_cancel.pressed.connect(func() -> void:
		_pending_sponsor_id = ""
		_refresh_sponsor_ui()
	)
	buttons.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.text = _tr_key("common.confirm")
	btn_confirm.custom_minimum_size = Vector2(180, 48)
	btn_confirm.add_theme_font_size_override("font_size", 21)
	_apply_popup_button_style(btn_confirm, Color(0.08, 0.68, 0.22, 1), Color(0.18, 0.9, 0.34, 1))
	btn_confirm.pressed.connect(func() -> void:
		_activate_sponsor_contract(_pending_sponsor_id)
		_pending_sponsor_id = ""
		_refresh_sponsor_ui()
	)
	buttons.add_child(btn_confirm)


func _load_active_contract() -> void:
	var save: Dictionary = PlayerLife.load_savegame()
	if SponsorDataRef.expire_active_contract_if_needed(save):
		PlayerLife.write_savegame(save)
	_active_contract = SponsorDataRef.get_active_contract(save)
	active_sponsor_id = str(_active_contract.get("id", ""))


func _activate_sponsor_contract(sponsor_id: String) -> void:
	var sponsor := SponsorDataRef.get_sponsor_by_id(sponsor_id)
	if sponsor.is_empty():
		return
	var save: Dictionary = PlayerLife.load_savegame()
	PlayerLife.ensure_finance_schema(save)

	var contract: Dictionary = SponsorDataRef.make_contract_copy(sponsor)
	if str(contract.get("payment_type", "")) == SponsorDataRef.PAYMENT_PER_SEASON and not bool(contract.get("season_payment_paid", false)):
		SponsorDataRef.apply_sponsor_revenue_to_save(save, int(contract.get("payment_amount", 0)))
		contract["season_payment_paid"] = true

	save[SponsorDataRef.ACTIVE_CONTRACT_SAVE_KEY] = contract.duplicate(true)
	SponsorDataRef.remember_sponsor_ids(save, [sponsor_id])
	save[SponsorDataRef.LAST_SIGNED_SPONSOR_SAVE_KEY] = sponsor_id
	_sync_wallet_from_totals(save)
	PlayerLife.write_savegame(save)

	_active_contract = contract.duplicate(true)
	active_sponsor_id = str(_active_contract.get("id", ""))


func _sync_wallet_from_totals(save: Dictionary) -> void:
	var wallet_value: int = maxi(0, int(save.get("total_recettes", 0)) - int(save.get("total_depenses", 0)))
	if not save.has("finance") or typeof(save["finance"]) != TYPE_DICTIONARY:
		save["finance"] = {}
	(save["finance"] as Dictionary)["euros"] = wallet_value
	if not save.has("wallet") or typeof(save["wallet"]) != TYPE_DICTIONARY:
		save["wallet"] = {}
	(save["wallet"] as Dictionary)["euros"] = wallet_value


func _get_current_club_level() -> int:
	var save: Dictionary = PlayerLife.load_savegame()
	return PlayerLife.get_club_level(save)


func _apply_popup_button_style(button: Button, bg_color: Color, border_color: Color) -> void:
	var normal := _make_popup_button_style(bg_color, border_color)
	var hover := _make_popup_button_style(bg_color.lightened(0.08), border_color.lightened(0.06))
	var pressed := _make_popup_button_style(bg_color.darkened(0.12), border_color.darkened(0.08))
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)


func _apply_sponsor_card_button_style(button: Button, disabled_state: bool) -> void:
	var normal := _make_popup_button_style(Color(0.04, 0.62, 0.24, 1), Color(0.25, 0.95, 0.42, 1))
	var hover := _make_popup_button_style(Color(0.06, 0.72, 0.29, 1), Color(0.38, 1, 0.52, 1))
	var pressed := _make_popup_button_style(Color(0.03, 0.48, 0.19, 1), Color(0.18, 0.76, 0.33, 1))
	var disabled := _make_popup_button_style(Color(0.08, 0.32, 0.16, 0.92), Color(0.22, 0.72, 0.34, 0.75))
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 1, 0.78, 0.95))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", disabled if disabled_state else normal)
	button.add_theme_stylebox_override("hover", disabled if disabled_state else hover)
	button.add_theme_stylebox_override("pressed", disabled if disabled_state else pressed)
	button.add_theme_stylebox_override("disabled", disabled)


func _make_popup_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 3
	return style


func _make_label(text_value: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	_apply_label_typography(label, font_size, color, centered, 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_detail_label(label_key: String, value: String) -> Label:
	return _make_label(_tr_key(label_key) + ": " + value, 22, TEXT_DETAIL, false)


func _apply_label_typography(label: Label, font_size: int, color: Color, centered: bool, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.42))
	label.add_theme_constant_override("line_spacing", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT


func _format_payment_unit(payment_type: String) -> String:
	if payment_type == SponsorDataRef.PAYMENT_PER_MATCH:
		return _tr_key("sponsors.unit.match")
	if payment_type == SponsorDataRef.PAYMENT_PER_SEASON:
		return _tr_key("sponsors.unit.season")
	return _tr_key(str(SponsorDataRef.PAYMENT_I18N.get(payment_type, "")))


func _format_duration_unit(duration_type: String, duration_value: int) -> String:
	var plural := duration_value != 1
	if duration_type == SponsorDataRef.PAYMENT_PER_MATCH:
		return _tr_key("sponsors.unit.matches" if plural else "sponsors.unit.match")
	if duration_type == SponsorDataRef.PAYMENT_PER_SEASON:
		return _tr_key("sponsors.unit.seasons" if plural else "sponsors.unit.season")
	return _format_payment_unit(duration_type)


func _format_remaining_text(sponsor: Dictionary) -> String:
	var payment_type := str(sponsor.get("payment_type", ""))
	if payment_type == SponsorDataRef.PAYMENT_PER_MATCH:
		var remaining_matches := int(sponsor.get("remaining_matches", sponsor.get("duration_value", 0)))
		var total_matches := int(sponsor.get("duration_value", remaining_matches))
		return _tr_key("sponsors.remaining") + ": " + str(remaining_matches) + " / " + str(total_matches) + " " + _tr_key("sponsors.remaining_matches")
	if payment_type == SponsorDataRef.PAYMENT_PER_SEASON:
		var remaining_seasons := int(sponsor.get("remaining_seasons", sponsor.get("duration_value", 0)))
		var total_seasons := int(sponsor.get("duration_value", remaining_seasons))
		return _tr_key("sponsors.remaining") + ": " + str(remaining_seasons) + " / " + str(total_seasons) + " " + _tr_key("sponsors.remaining_seasons")
	return ""


func _on_btn_retour() -> void:
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file("res://scenes/Menu.tscn")
