extends Control

var game: Control
var font: Font
const INK = Color("dce9eb")
const MUTED = Color("96aeb5")
const GOLD = Color("f4c66a")
const FLOOR = Color("293b45")
const ENEMY = Color("e17b65")
const FRIEND = Color("6fc5db")

func _ready() -> void:
	font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(900, 540)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _text(pos: Vector2, value: String, size_value := 15, color := INK) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func _rect(rect: Rect2, color: Color, border := Color.TRANSPARENT) -> void:
	draw_rect(rect, color)
	if border.a > 0: draw_rect(rect, border, false, 2.0)

func _icon(kind: String, c: Vector2, scale_value := 1.0) -> void:
	var s := scale_value
	match kind:
		"가시":
			draw_rect(Rect2(c + Vector2(-14, 5)*s, Vector2(28, 5)*s), Color("a1b7bd"))
			for k in range(3):
				var x: float = (k - 1) * 9.0 * s
				draw_colored_polygon(PackedVector2Array([c+Vector2(x-4*s, 5*s), c+Vector2(x, -10*s), c+Vector2(x+4*s, 5*s)]), Color("d1e0dc"))
		"화살":
			draw_line(c+Vector2(-13, 0)*s, c+Vector2(13, 0)*s, Color("f1d99c"), 3*s)
			draw_colored_polygon(PackedVector2Array([c+Vector2(14, 0)*s,c+Vector2(5, -6)*s,c+Vector2(5, 6)*s]), Color("f1d99c"))
			draw_line(c+Vector2(-13, 0)*s,c+Vector2(-17, -5)*s, Color("f1d99c"), 2*s)
			draw_line(c+Vector2(-13, 0)*s,c+Vector2(-17, 5)*s, Color("f1d99c"), 2*s)
		"돌":
			draw_colored_polygon(PackedVector2Array([c+Vector2(-15, 5)*s,c+Vector2(-12,-7)*s,c+Vector2(-3,-13)*s,c+Vector2(10,-10)*s,c+Vector2(15,2)*s,c+Vector2(6,10)*s,c+Vector2(-8,11)*s]), Color("b39a7f"))
			draw_line(c+Vector2(-7,-5)*s,c+Vector2(0,0)*s,Color("715f56"),2*s)

func _person(kind: String, c: Vector2, color: Color, s := 1.0) -> void:
	# Distinct silhouettes stay readable even without external sprite assets.
	draw_circle(c+Vector2(0,5)*s, 12*s, color.darkened(0.30))
	draw_colored_polygon(PackedVector2Array([c+Vector2(-10, 12)*s, c+Vector2(-8,0)*s, c+Vector2(8,0)*s, c+Vector2(10,12)*s]), color)
	draw_circle(c+Vector2(0,-6)*s, 6*s, Color("f3d6b2"))
	if kind == "기사" or kind == "검사":
		draw_arc(c+Vector2(0,-8)*s, 7*s, PI, TAU, 12, Color("dce7e5"), 3*s)
		draw_line(c+Vector2(10,8)*s,c+Vector2(16,-7)*s,Color("f2f1d8"),2*s)
	elif kind == "마법사":
		draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-10)*s,c+Vector2(0,-21)*s,c+Vector2(7,-10)*s]), Color("aa98ee"))
	elif kind == "궁수":
		draw_arc(c+Vector2(11,1)*s, 9*s, -1.1, 1.1, 12, Color("e9cf83"), 2*s)
	elif kind == "힐러":
		draw_rect(Rect2(c+Vector2(-2,-17)*s,Vector2(4,10)*s),Color("a4efbb"))
		draw_rect(Rect2(c+Vector2(-5,-14)*s,Vector2(10,4)*s),Color("a4efbb"))

func _bar(at: Vector2, width: float, value: float, color: Color) -> void:
	_rect(Rect2(at,Vector2(width,5)), Color("101a20"))
	_rect(Rect2(at,Vector2(width * clampf(value,0,1),5)), color)

func _draw() -> void:
	if not game or not font: return
	var factor: float = size.x / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(factor, factor))
	_rect(Rect2(0,0,900,540), Color("152630"))
	_text(Vector2(20,26), "던전 경로  ·  칸이나 방을 클릭해 배치", 17, GOLD)
	for row in range(3):
		var y := 43.0 + row * 100.0
		_text(Vector2(13,y+37), "입구" if row == 0 else "다음", 13, MUTED)
		draw_line(Vector2(57,y+35), Vector2(74,y+35), MUTED, 2)
		for col in range(5):
			var i := row*5+col
			var x := 78.0 + col*105.0
			var active: bool = game.cursor == i
			_rect(Rect2(x,y,98,70), Color("4b4e3d") if active else FLOOR, GOLD if active else Color("50636a"))
			_text(Vector2(x+6,y+16), str(i+1), 12, MUTED)
			for t in game.traps[i]:
				var offset := 0.0
				if t == "가시": offset = -25.0
				elif t == "돌": offset = 25.0
				_icon(t, Vector2(x+49+offset,y+40), 0.65)
			if active:
				for j in range(mini(game.enemies.size(),4)):
					_person(game.enemies[j]["name"], Vector2(x+18+j*20,y+24), ENEMY, 0.42)
		if row < 2:
			var active_room: bool = game.current_room == row
			_rect(Rect2(618,y,192,70), Color("4b4e3d") if active_room else Color("30454a"), GOLD if active_room else Color("607a78"))
			_text(Vector2(627,y+17), "방 %d" % (row+1), 13, GOLD)
			for j in range(game.rooms[row].size()):
				var soldier: Dictionary = game.rooms[row][j]
				_person(soldier["name"], Vector2(645+j*42,y+42), FRIEND, 0.65)
				_bar(Vector2(634+j*42,y+58),24,float(soldier["hp"])/20.0,FRIEND)
			if active_room:
				_text(Vector2(727,y+17), "⚔ 전투 중", 12, ENEMY)
		else:
			_rect(Rect2(618,y,192,70), Color("4c3b3e"), Color("ad7975"))
			_text(Vector2(645,y+32), "♛  영주의 방", 17, Color("ffd998"))
			_text(Vector2(645,y+53), "적 도달 시 패배", 12, MUTED)
		_text(Vector2(820,y+40), "→", 22, MUTED)
	_rect(Rect2(12,349,876,177), Color("1d343d"), Color("455e62"))
	_text(Vector2(27,374), "적 파티  ·  선두 → 후열", 17, ENEMY)
	_text(Vector2(487,374), "방어 병사", 17, FRIEND)
	for j in range(game.enemies.size()):
		var e: Dictionary = game.enemies[j]
		var x := 65.0+j*100.0
		_person(e["name"], Vector2(x,412), ENEMY, 1.2)
		_text(Vector2(x-24,451),e["name"],14,INK)
		_bar(Vector2(x-25,459),50,float(e["hp"])/30.0,ENEMY)
		_text(Vector2(x-20,480),"%d / 30" % e["hp"],12,MUTED)
	if game.enemies.is_empty(): _text(Vector2(40,425),"적 전원 처치",16,GOLD)
	var display_room: int = game.current_room
	if display_room < 0 and game.phase == "준비": display_room = 0
	if display_room >= 0:
		for j in range(game.rooms[display_room].size()):
			var s: Dictionary = game.rooms[display_room][j]
			var x := 530.0+j*100.0
			_person(s["name"],Vector2(x,412),FRIEND,1.2)
			_text(Vector2(x-23,451),s["name"],14,INK)
			_bar(Vector2(x-25,459),50,float(s["hp"])/20.0,FRIEND)
			_text(Vector2(x-20,480),"%d / 20" % s["hp"],12,MUTED)
		if game.rooms[display_room].is_empty(): _text(Vector2(505,425),"이 방에 병사 없음",14,MUTED)
	else:
		_text(Vector2(500,425),"방에 도착하면 전투 표시",14,MUTED)
	if game.battle_actor == "적" and game.current_room >= 0:
		var target_x: float = 530.0 + game.target_index * 100.0
		draw_line(Vector2(420,397), Vector2(target_x-23,397), ENEMY, 3)
		draw_colored_polygon(PackedVector2Array([Vector2(target_x-18,397),Vector2(target_x-29,392),Vector2(target_x-29,402)]), ENEMY)
		draw_arc(Vector2(target_x,412),24,0,TAU,30,ENEMY,3)
	elif game.battle_actor == "병사" and game.current_room >= 0 and not game.enemies.is_empty():
		var attacker_x: float = 530.0 + game.actor_index * 100.0
		draw_line(Vector2(attacker_x-20,397), Vector2(90,397), FRIEND, 3)
		draw_colored_polygon(PackedVector2Array([Vector2(86,397),Vector2(97,392),Vector2(97,402)]), FRIEND)
		draw_arc(Vector2(65,412),24,0,TAU,30,FRIEND,3)
	elif game.battle_actor == "함정" and game.cursor >= 0:
		_text(Vector2(395,374),"▼ 함정 발동",14,GOLD)
	_text(Vector2(27,510),game.visual_event,15,GOLD)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / (size.x / 900.0)
		for row in range(3):
			var y := 43.0 + row * 100.0
			for col in range(5):
				if Rect2(78+col*105,y,98,70).has_point(p):
					game._cell_pressed(row*5+col)
					return
			if row < 2 and Rect2(618,y,192,70).has_point(p):
				game._room_pressed(row)
				return
