extends Button

var game: Control
var card_id: int

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not game or disabled or game.phase != "준비" or game.pending_skill_discards > 0:
		return null
	var index: int = game._hand_index_by_id(card_id)
	if index < 0 or game.card_defs[game.hand[index].name].type == "skill":
		return null
	var preview := Button.new()
	preview.text = text
	preview.icon = icon
	preview.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	preview.custom_minimum_size = size
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.add_theme_stylebox_override("normal", get_theme_stylebox("normal"))
	preview.add_theme_color_override("font_color", Color("f7e7c6"))
	preview.add_theme_font_size_override("font_size", 13)
	preview.add_theme_constant_override("icon_max_width", 55)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_drag_preview(preview)
	return {"kind":"hand_card", "card_id":card_id}
