extends Control

var game: Control
var font: Font
const FRIEND := Color("82d3db")
const ENEMY := Color("ee8d78")
const INK := Color("f0e6ce")
const MUTED := Color("afbac0")
const GOLD := Color("f5c76a")
const NODES := [150.0, 275.0, 400.0, 525.0, 650.0, 775.0, 900.0, 1025.0]
const BOARD_HEIGHT := 360.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(1200, BOARD_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 0:
		var required_height := BOARD_HEIGHT * size.x / 1200.0
		if absf(custom_minimum_size.y - required_height) > 0.5:
			custom_minimum_size.y = required_height
		queue_redraw()

func _lane_y(lane: int) -> float:
	return 110.0 + lane * 140.0 if game.lanes.size() == 2 else 75.0 + lane * 105.0

func _text(at: Vector2, value: String, size_value := 14, color := INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func _figure(kind: String, at: Vector2, enemy := false, scale_value := 1.0) -> void:
	var key := ("enemy_" if enemy else "") + kind
	if not game.sprite_icons.has(key): return
	var side := 38.0 * scale_value
	draw_texture_rect(game.sprite_icons[key], Rect2(at - Vector2(side / 2, side * 0.6), Vector2(side, side)), false)

func _trap(kind: String, at: Vector2, enabled: bool) -> void:
	var c := Color("e1c786") if enabled else Color("68777e")
	match kind:
		"가시":
			draw_line(at + Vector2(-9, 6), at + Vector2(9, 6), c, 2)
			for k in range(3):
				var x := (k - 1) * 6.0
				draw_colored_polygon(PackedVector2Array([at + Vector2(x - 3, 5), at + Vector2(x, -6), at + Vector2(x + 3, 5)]), c)
		"화살":
			draw_line(at + Vector2(-9, 0), at + Vector2(8, 0), c, 2)
			draw_colored_polygon(PackedVector2Array([at + Vector2(10, 0), at + Vector2(4, -4), at + Vector2(4, 4)]), c)
		"낙석":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 4), at + Vector2(-7, -6), at + Vector2(1, -9), at + Vector2(9, -4), at + Vector2(10, 5), at + Vector2(3, 7)]), c)
		"독가스 함정":
			draw_line(at + Vector2(-8, -8), at + Vector2(8, -8), c, 3)
			var gas := Color("91cc78") if enabled else c
			draw_circle(at + Vector2(-5, 2), 5, gas)
			draw_circle(at + Vector2(4, 3), 6, gas)
			draw_circle(at + Vector2(0, -2), 5, gas)

func _orthogonal(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var middle := (from.x + to.x) / 2.0
	draw_line(from, Vector2(middle, from.y), color, width)
	draw_line(Vector2(middle, from.y), Vector2(middle, to.y), color, width)
	draw_line(Vector2(middle, to.y), to, color, width)

func _party_route(party: Dictionary) -> Array:
	if party.has("route") and party.route.size() == NODES.size(): return party.route
	var route: Array = []
	for i in range(NODES.size()): route.append(party.lane)
	return route

func _draw() -> void:
	if not game or not font: return
	var scale_value := size.x / 1200.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_value, scale_value))
	draw_rect(Rect2(0, 0, 1200, BOARD_HEIGHT), Color("142632"))
	draw_rect(Rect2(1, 1, 1198, BOARD_HEIGHT - 2), Color("466071"), false, 2)
	var entry := Vector2(55, BOARD_HEIGHT / 2.0)
	var goal := Vector2(1140, BOARD_HEIGHT / 2.0)
	var path_color := Color("66817d")
	for lane in range(game.lanes.size()):
		var y := _lane_y(lane)
		draw_line(Vector2(NODES[0], y), Vector2(NODES[-1], y), path_color, 6)
		_orthogonal(entry, Vector2(NODES[0], y), path_color, 6)
		_orthogonal(Vector2(NODES[-1], y), goal, path_color, 6)
	for crossing in game.map_crossings:
		var x: float = NODES[crossing.after] + 51.0
		draw_line(Vector2(x, _lane_y(crossing.top)), Vector2(x, _lane_y(crossing.top + 1)), path_color, 6)
	var selected_route: Array = []
	if game.phase not in ["이벤트", "카드 보상", "보스 보상"] and game.selected_party >= 0 and game.selected_party < game.parties.size():
		selected_route = _party_route(game.parties[game.selected_party])
		_orthogonal(entry, Vector2(NODES[0], _lane_y(selected_route[0])), GOLD, 4)
		for stage in range(NODES.size() - 1):
			var from := Vector2(NODES[stage], _lane_y(selected_route[stage]))
			var to := Vector2(NODES[stage + 1], _lane_y(selected_route[stage + 1]))
			var bend_x: float = from.x + 51.0 if from.y != to.y else (from.x + to.x) / 2.0
			draw_line(from, Vector2(bend_x, from.y), GOLD, 4)
			draw_line(Vector2(bend_x, from.y), Vector2(bend_x, to.y), GOLD, 4)
			draw_line(Vector2(bend_x, to.y), to, GOLD, 4)
		_orthogonal(Vector2(NODES[-1], _lane_y(selected_route[-1])), goal, GOLD, 4)
	for lane in range(game.lanes.size()):
		var y := _lane_y(lane)
		_text(Vector2(100, y - 37), game._lane_name(lane) + " 길", 13, MUTED)
		for stage_index in range(NODES.size()):
			var x: float = NODES[stage_index]
			var stage: Dictionary = game._map_stage(lane, stage_index)
			if stage.type == "path": continue
			var is_room: bool = stage.type == "room"
			var rect := Rect2(x - 51, y - 31, 102, 62)
			draw_rect(rect, Color("304651") if is_room else Color("293a40"))
			var selected: bool = not selected_route.is_empty() and selected_route[stage_index] == lane
			draw_rect(rect, GOLD if selected else Color("57717a"), false, 2)
			_text(Vector2(x - 46, y - 15), ("방 " if is_room else "통로 ") + str(stage.slot + 1), 11, GOLD if selected else MUTED)
			if is_room:
				var soldiers: Array = game.lanes[lane].rooms[stage.slot]
				if soldiers.is_empty(): _text(Vector2(x - 15, y + 13), "빈 방", 12, MUTED)
				for i in range(soldiers.size()):
					var soldier: Dictionary = soldiers[i]
					var cx: float = x - 36 + i * 24
					_figure(soldier.name, Vector2(cx, y + 5), false, 0.62)
					draw_rect(Rect2(cx - 10, y + 19, 20, 3), Color("101820"))
					draw_rect(Rect2(cx - 10, y + 19, 20 * float(soldier.hp) / soldier.max_hp, 3), FRIEND)
					_text(Vector2(cx - 3, y + 29), str(i + 1), 9, INK)
			else:
				var traps: Array = game.lanes[lane].traps[stage.slot]
				if traps.is_empty(): _text(Vector2(x - 19, y + 13), "빈 통로", 12, MUTED)
				for i in range(traps.size()):
					var trap: Dictionary = traps[i]
					var cx: float = x - 28 + i * 28
					_trap(trap.name, Vector2(cx, y + 3), trap.active)
					if not trap.active: _text(Vector2(cx - 10, y + 23), "%dG" % (5 * maxi(1, trap.hits)), 10, ENEMY)
	draw_rect(Rect2(entry - Vector2(13, 13), Vector2(26, 26)), Color("62ba84"))
	draw_rect(Rect2(goal - Vector2(15, 15), Vector2(30, 30)), Color("66a9d0"))
	_text(entry + Vector2(-22, 36), "입구", 13, INK)
	_text(goal + Vector2(-26, 39), "던전 코어", 12, INK)
	for i in range(game.parties.size()):
		var party: Dictionary = game.parties[i]
		if party.done: continue
		var at := entry + Vector2(-20 + i * 13, 0) if party.pos < 0 else Vector2(NODES[clampi(party.pos, 0, NODES.size() - 1)], _lane_y(party.lane))
		if party.pos >= NODES.size(): at = goal - Vector2(35, 0)
		var alive: Array = party.units.filter(func(unit): return unit.hp > 0)
		if not alive.is_empty(): _figure(alive[0].name, at + Vector2(35, -4), true, 0.5)
		_text(at + Vector2(32, -17), str(i + 1), 10, ENEMY)
	_text(Vector2(14, 20), "◆ 방어선  |  노란 선: 선택한 파티의 전체 경로", 14, GOLD)
	if game.phase == "웨이브" and not game.battle_notice.is_empty():
		_text(Vector2(460, 20), game.battle_notice, 13, ENEMY)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / (size.x / 1200.0)
		for lane in range(game.lanes.size()):
			var y := _lane_y(lane)
			for stage_index in range(NODES.size()):
				if Rect2(NODES[stage_index] - 51, y - 31, 102, 62).has_point(p):
					var stage: Dictionary = game._map_stage(lane, stage_index)
					if stage.type == "path": return
					game._slot_pressed(lane, stage.slot, stage.type == "room")
					return
