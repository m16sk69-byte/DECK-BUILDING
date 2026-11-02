extends Control

var game: Control
var font: Font
const FRIEND := Color("82d3db")
const ENEMY := Color("ee8d78")
const INK := Color("f0e6ce")
const MUTED := Color("afbac0")
const GOLD := Color("f5c76a")
const NODES := [195.0, 420.0, 645.0, 870.0]

func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(1200, 265)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 0:
		var required_height := 265.0 * size.x / 1200.0
		if absf(custom_minimum_size.y - required_height) > 0.5:
			custom_minimum_size.y = required_height
		queue_redraw()

func _text(at: Vector2, value: String, size_value := 14, color := INK, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at, value, align, width, size_value, color)

func _figure(kind: String, at: Vector2, color: Color, scale_value := 1.0) -> void:
	var key := ("enemy_" if color == ENEMY else "") + kind
	if not game.sprite_icons.has(key): return
	var side := 38.0 * scale_value
	draw_texture_rect(game.sprite_icons[key], Rect2(at - Vector2(side / 2, side * 0.6), Vector2(side, side)), false)

func _trap(kind: String, at: Vector2, enabled: bool) -> void:
	var c := Color("e1c786") if enabled else Color("68777e")
	match kind:
		"가시":
			draw_line(at+Vector2(-13,7), at+Vector2(13,7), c, 3)
			for k in range(3):
				var x := (k-1)*8.0
				draw_colored_polygon(PackedVector2Array([at+Vector2(x-4,5),at+Vector2(x,-8),at+Vector2(x+4,5)]), c)
		"화살":
			draw_line(at+Vector2(-13,0), at+Vector2(12,0), c, 3)
			draw_colored_polygon(PackedVector2Array([at+Vector2(14,0),at+Vector2(5,-5),at+Vector2(5,5)]), c)
		"낙석":
			draw_colored_polygon(PackedVector2Array([at+Vector2(-13,5),at+Vector2(-10,-8),at+Vector2(1,-12),at+Vector2(12,-6),at+Vector2(14,6),at+Vector2(4,10)]), c)

func _draw() -> void:
	if not game or not font: return
	var scale_value := size.x / 1200.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_value, scale_value))
	draw_rect(Rect2(0,0,1200,265), Color("142632"))
	draw_rect(Rect2(1,1,1198,263), Color("466071"), false, 2)
	for y in [82.0, 190.0]:
		draw_line(Vector2(70,y),Vector2(1110,y),Color("263c47"), 40)
		draw_line(Vector2(70,y),Vector2(1110,y),Color("607b78"), 2)
	for lane in range(2):
		var y := 82.0 + lane * 108.0
		var highlighted: bool = not game.parties.is_empty() and game.parties[game.selected_party].lane == lane
		_text(Vector2(14,y+5), "위 경로" if lane == 0 else "아래 경로", 15, GOLD if highlighted else MUTED)
		for pos in range(4):
			var x: float = NODES[pos]
			var is_room := pos % 2 == 1
			var rect := Rect2(x-92,y-38,184,76)
			draw_rect(rect, Color("304651") if is_room else Color("293a40"))
			draw_rect(rect, GOLD if highlighted else Color("57717a"), false, 2)
			# Masonry and a small banner make rooms and corridors visually distinct.
			for brick in range(4):
				draw_line(Vector2(x-85+brick*43,y-23),Vector2(x-67+brick*43,y-23),Color("5d7273", .35),2)
			_text(Vector2(x-83,y-20), ("방 " if is_room else "통로 ") + str(int(pos/2)+1), 13, GOLD if highlighted else MUTED)
			if is_room:
				var soldiers: Array = game.lanes[lane].rooms[int(pos/2)]
				if soldiers.is_empty(): _text(Vector2(x-30,y+14),"빈 방",13,MUTED)
				for i in range(soldiers.size()):
					var soldier: Dictionary = soldiers[i]
					var cx: float = x - 57 + i*39
					_figure(soldier.name,Vector2(cx,y+4),FRIEND,.8)
					draw_rect(Rect2(cx-14,y+22,28,4),Color("101820"))
					draw_rect(Rect2(cx-14,y+22,28*float(soldier.hp)/soldier.max_hp,4),FRIEND)
					_text(Vector2(cx-3,y+36),str(i+1),10,INK)
			else:
				var traps: Array = game.lanes[lane].traps[int(pos/2)]
				if traps.is_empty(): _text(Vector2(x-29,y+14),"빈 통로",13,MUTED)
				for i in range(traps.size()):
					var trap: Dictionary = traps[i]
					var cx: float = x-42+i*40
					_trap(trap.name,Vector2(cx,y+5),trap.active)
					if not trap.active: _text(Vector2(cx-12,y+28),"%dG" % (5*maxi(1,trap.hits)),11,ENEMY)
		# Goal is a simple neutral keep, not a final character choice.
		draw_rect(Rect2(1085,y-25,45,50),Color("817462"))
		draw_rect(Rect2(1092,y-35,11,12),Color("a69a80"))
		draw_rect(Rect2(1112,y-35,11,12),Color("a69a80"))
		draw_rect(Rect2(1100,y+5,14,20),Color("263746"))
		_text(Vector2(1075,y+46),"수호 지점",12,INK)
	for i in range(game.parties.size()):
		var party: Dictionary = game.parties[i]
		if party.done: continue
		var y: float = 82.0 + party.lane*108.0
		var x: float = 95.0 - i*13 if party.pos < 0 else NODES[clampi(party.pos,0,3)]
		# The red flag remains visible over the current tile while a wave is running.
		if party.pos >= 0:
			draw_line(Vector2(x+66,y-33),Vector2(x+66,y-9),ENEMY,2)
			draw_colored_polygon(PackedVector2Array([Vector2(x+66,y-33),Vector2(x+82,y-28),Vector2(x+66,y-23)]),ENEMY)
			_text(Vector2(x+58,y-12),str(i+1),11,INK)
			var alive: Array = party.units.filter(func(unit): return unit.hp > 0)
			if not alive.is_empty():
				_figure(alive[0].name,Vector2(x+65,y+10),ENEMY,.52)
		else:
			_figure("방패병",Vector2(x,y-3),ENEMY,.65)
			_text(Vector2(x-6,y+20),str(i+1),11,INK)
	_text(Vector2(14,20), "◆ 방어선  |  통로와 방을 클릭해 배치", 15, GOLD)
	if game.phase == "웨이브" and not game.battle_notice.is_empty():
		_text(Vector2(450,20),game.battle_notice,14,ENEMY)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / (size.x / 1200.0)
		for lane in range(2):
			var y := 82.0 + lane * 108.0
			for pos in range(4):
				if Rect2(NODES[pos]-92,y-38,184,76).has_point(p):
					game._slot_pressed(lane,int(pos/2),pos%2 == 1)
					return
