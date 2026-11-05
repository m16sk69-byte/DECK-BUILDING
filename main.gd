extends Control

# Prototype values; see README for the assumptions behind them.
const CARDS = {
	"가시": {"type":"trap", "slot":"바닥", "cost":1, "damage":4, "consumable":false, "description":"선두 1명 4 피해"},
	"화살": {"type":"trap", "slot":"벽", "cost":1, "damage":8, "consumable":true, "description":"#소모성\n후방 2명 각 8 피해"},
	"낙석": {"type":"trap", "slot":"천장", "cost":2, "damage":8, "consumable":true, "description":"#소모성\n적 전체 각 8 피해"},
	"고블린": {"type":"soldier", "cost":1, "hp":20, "attack":5, "description":"HP 20 · 선두 5 피해"},
	"고블린 궁수": {"type":"soldier", "cost":1, "hp":10, "attack":8, "description":"HP 10 · 선두 8 피해"},
	"언데드 골렘": {"type":"soldier", "cost":3, "hp":30, "attack":4, "regen":10, "description":"HP 30 · 공격 4\n#재생10"},
	"오크": {"type":"soldier", "cost":2, "hp":25, "attack":10, "front_only":true, "description":"HP 25 · 공격 10\n선두 고정"},
	"녹티스": {"type":"soldier", "cost":2, "hp":20, "attack":8, "unique":true, "lifesteal":3, "description":"HP 20 · 공격 8\n#고유 #흡혈3"},
	"궁수": {"type":"soldier", "cost":1, "hp":16, "attack":7, "description":"HP 16 · 선두 7 피해"},
	"마법사": {"type":"soldier", "cost":2, "hp":14, "attack":4, "area_attack":true, "description":"HP 14 · 전체 4 피해"},
}
const REWARDS = ["최대 코스트 +1", "모든 병사 공격력 +2", "모든 함정 피해 +2", "골드 +12", "모든 병사 체력 10 회복", "언데드 골렘 카드 획득", "덱에 낙석 2장 추가", "최대 코스트 +2", "모든 병사 공격력 +1"]
const TEST_EVENTS = ["가능성 연구", "강화 의식", "시험 이벤트 3", "시험 이벤트 4"]
const VAMPIRE_EVENT = "흡혈귀와의 만남"
const NOCTIS_PRICE := 30
const RITUAL_KEYWORDS = {"regen":5, "lifesteal":2, "blur":0, "poison":5, "bleed":3}
const KEYWORD_NAMES = {"regen":"재생", "lifesteal":"흡혈", "blur":"흐릿함", "poison":"중독", "bleed":"출혈"}
const RESEARCH_PRICE := 70
const REST_HEAL_RATE := 0.30
var rng := RandomNumberGenerator.new()
var card_defs: Dictionary = CARDS.duplicate(true)
var research_selected: Array = []
var deck: Array = []
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var lanes: Array = []
var parties: Array = []
var reserves: Array = []
var moving_soldier: Dictionary = {}
var selected_order: Dictionary = {}
var phase := "준비"
var round_number := 1
var max_cost := 5
var cost := 5
var gold := 30
var soldier_bonus := 0
var trap_bonus := 0
var damage_total := 0
var cards_used := 0
var selected_card := -1
var mode := "card"
var selected_party := 0
var speed := 0.4
var played_rounds := 0
var rewards_used: Array = []
var event_index := 0
var seen_events: Array = []
var pending_event := false
var current_event := ""
var next_card_id := 0
var wave_token := 0
var record_path := "user://runs.json"
var battle_notice := ""
var card_icons: Dictionary = {}
var sprite_icons: Dictionary = {}
var music_player: AudioStreamPlayer
var music_button: Button
var music_enabled := true
var summary: Label
var status_label: Label
var party_box: VBoxContainer
var hand_box: HBoxContainer
var board_box: VBoxContainer
var reserves_box: VBoxContainer
var log_box: RichTextLabel
var action_box: HBoxContainer
var options_box: HBoxContainer
var start_button: Button
var log_lines: Array[String] = []

func _ready() -> void:
	rng.randomize()
	_load_art()
	_start_music()
	_build_ui()
	_new_game()

func _load_art() -> void:
	var names := {"가시":"spike", "화살":"arrow", "낙석":"rock"}
	for card_name in names:
		var svg := FileAccess.get_file_as_string("res://assets/%s.svg" % names[card_name])
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			card_icons[card_name] = ImageTexture.create_from_image(image)
	var pixel_art = preload("res://pixel_characters.gd")
	for kind in ["궁수", "마법사", "고블린", "고블린 궁수", "언데드 골렘", "오크", "녹티스"]:
		card_icons[kind] = pixel_art.make_card(kind)
		sprite_icons[kind] = pixel_art.make_sprite(kind)
	for kind in ["방패병", "검투사", "궁수", "마법사", "보스"]:
		sprite_icons["enemy_" + kind] = pixel_art.make_sprite(kind, true)

func _start_music() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var file := FileAccess.open("res://assets/dungeon_theme.wav", FileAccess.READ)
	if not file or file.get_length() <= 44: return
	file.seek(44)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = file.get_buffer(file.get_length() - 44)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	music_player.stream = stream
	music_player.volume_db = -14.0
	if DisplayServer.get_name() != "headless":
		music_player.play()

func _toggle_music() -> void:
	if not music_player or not music_player.stream: return
	music_enabled = not music_enabled
	music_player.stream_paused = not music_enabled
	music_button.text = "배경음: 켬" if music_enabled else "배경음: 끔"

func _exit_tree() -> void:
	if music_player:
		music_player.stop()
		music_player.stream = null

func _label(value: String, size := 16) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(105, 44)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("243747")
	normal.border_color = Color("537282")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 5
	normal.content_margin_right = 5
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("345469")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(callback)
	return button

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101a24")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	scroll.add_child(margin)
	var root := VBoxContainer.new()
	root.custom_minimum_size.x = 1280
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	root.add_child(_label("덱빌딩 디펜스  |  라운드 프로토타입", 27))
	summary = _label("", 19)
	root.add_child(summary)
	status_label = _label("", 16)
	root.add_child(status_label)
	root.add_child(_label("적 파티 · 클릭하면 경로를 강조합니다", 19))
	party_box = VBoxContainer.new()
	root.add_child(party_box)
	root.add_child(_label("방어선 · 카드 선택 후 통로 또는 방을 클릭하세요", 19))
	board_box = VBoxContainer.new()
	root.add_child(board_box)
	action_box = HBoxContainer.new()
	root.add_child(action_box)
	action_box.add_child(_button("회수 모드", _set_mode.bind("remove")))
	action_box.add_child(_button("병사 이동", _set_mode.bind("move")))
	action_box.add_child(_button("병사 순서", _set_mode.bind("order")))
	action_box.add_child(_button("병사 휴식", _set_mode.bind("rest")))
	action_box.add_child(_button("함정 재장전", _set_mode.bind("rearm")))
	start_button = _button("웨이브 시작", _start_wave)
	action_box.add_child(start_button)
	action_box.add_child(_button("속도 변경", _toggle_speed))
	music_button = _button("배경음: 켬", _toggle_music)
	action_box.add_child(music_button)
	action_box.add_child(_button("새 게임", _new_game))
	reserves_box = VBoxContainer.new()
	root.add_child(reserves_box)
	options_box = HBoxContainer.new()
	root.add_child(options_box)
	root.add_child(_label("손패 · 각 카드를 누른 뒤 배치할 칸을 누르세요", 19))
	hand_box = HBoxContainer.new()
	root.add_child(hand_box)
	root.add_child(_label("진행 및 전투 기록", 19))
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size = Vector2(0, 230)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	root.add_child(log_box)

func _add_card(name_value: String, initial := false) -> void:
	var card := {"id":next_card_id, "name":name_value}
	deck.append(card)
	if initial: draw_pile.append(card)
	else: discard_pile.append(card)
	next_card_id += 1

func _shuffle_draw_pile() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp

func _new_game() -> void:
	wave_token += 1
	battle_notice = ""
	phase = "준비"
	round_number = 1
	max_cost = 5
	cost = 5
	gold = 30
	soldier_bonus = 0
	trap_bonus = 0
	damage_total = 0
	cards_used = 0
	played_rounds = 0
	selected_card = -1
	selected_party = 0
	mode = "card"
	rewards_used.clear()
	event_index = 0
	seen_events.clear()
	pending_event = false
	current_event = ""
	for card_name in card_defs:
		if not CARDS.has(card_name):
			card_icons.erase(card_name)
			sprite_icons.erase(card_name)
	card_defs = CARDS.duplicate(true)
	research_selected.clear()
	deck.clear()
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	reserves.clear()
	moving_soldier.clear()
	selected_order.clear()
	next_card_id = 0
	for card_name in ["가시", "가시", "가시", "화살", "낙석", "고블린", "고블린", "고블린", "고블린", "고블린 궁수"]:
		_add_card(card_name, true)
	_shuffle_draw_pile()
	lanes = []
	for lane in range(2):
		lanes.append({"traps":[[], []], "rooms":[[], []]})
	log_lines.clear()
	_clear(options_box)
	_prepare_round()
	_log("새 게임. 수치는 임시값입니다. 적 경로를 확인하고 방어선을 배치하세요.")

func _draw_hand(amount := 5) -> void:
	for i in range(amount):
		if draw_pile.is_empty():
			if discard_pile.is_empty(): break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			_shuffle_draw_pile()
		hand.append(draw_pile.pop_back())

func _discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

func _regenerate_soldiers() -> void:
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room:
				var amount: int = card_defs[soldier.name].get("regen", 0)
				if amount > 0:
					var restored: int = mini(amount, soldier.max_hp - soldier.hp)
					soldier.hp += restored
					if restored > 0: _log("%s #재생: 체력 %d 회복" % [soldier.name, restored])

func _prepare_round() -> void:
	phase = "준비"
	cost = max_cost
	selected_card = -1
	mode = "card"
	_regenerate_soldiers()
	_draw_hand()
	_generate_parties()
	_refresh()

func _generate_parties() -> void:
	parties.clear()
	var count := 1 if round_number < 3 else (2 if round_number < 11 else 3)
	for p in range(count):
		var units := []
		var enemy_count := mini(4, 2 + int(round_number / 6))
		for i in range(enemy_count):
			var role: String = ["방패병", "검투사", "마법사", "궁수"][rng.randi_range(0, 3)]
			var hp: int = 10 + int(round_number / 3) * 2 + (5 if role == "방패병" else 0)
			var atk: int = 3 + int(round_number / 7) + (1 if role == "검투사" else 0)
			units.append({"name":role, "hp":hp, "max_hp":hp, "attack":atk})
		if round_number % 5 == 0 and p == 0:
			units[0] = {"name":"보스", "hp":24 + round_number * 2, "max_hp":24 + round_number * 2, "attack":5 + int(round_number / 5)}
		parties.append({"lane":rng.randi_range(0, 1), "units":units, "pos":-1, "done":false})
	selected_party = 0

func _set_mode(value: String) -> void:
	if phase != "준비": return
	moving_soldier.clear()
	selected_order.clear()
	mode = value
	selected_card = -1
	_refresh()

func _unique_in_play(name_value: String) -> bool:
	var data: Dictionary = card_defs[name_value]
	var group: String = data.get("unique_group", name_value)
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room:
				var other: Dictionary = card_defs[soldier.name]
				if soldier.hp > 0 and other.get("unique_group", soldier.name) == group and (data.get("unique", false) or other.get("unique", false)): return true
	for entry in reserves:
		var other: Dictionary = card_defs[entry.soldier.name]
		if entry.soldier.hp > 0 and other.get("unique_group", entry.soldier.name) == group and (data.get("unique", false) or other.get("unique", false)): return true
	return false

func _front_allowed(name_value: String, room: Array) -> bool:
	return not card_defs[name_value].get("front_only", false) or room.is_empty() or not card_defs[room[0].name].get("front_only", false)

func _put_soldier(room: Array, soldier: Dictionary) -> void:
	if card_defs[soldier.name].get("front_only", false): room.push_front(soldier)
	else: room.append(soldier)

func _select_card(index: int) -> void:
	if phase != "준비" or index < 0 or index >= hand.size(): return
	if _unique_in_play(hand[index].name):
		_log("#고유: %s이(가) 이미 배치 또는 휴식 중입니다." % hand[index].name)
		return
	moving_soldier.clear()
	selected_order.clear()
	mode = "card"
	selected_card = index
	_refresh()

func _select_party(index: int) -> void:
	selected_party = index
	_refresh()

func _soldier_pressed(lane: int, slot: int, index: int) -> void:
	if phase != "준비" or (mode != "move" and mode != "rest" and mode != "order"): return
	var soldiers: Array = lanes[lane].rooms[slot]
	if index < 0 or index >= soldiers.size(): return
	var soldier: Dictionary = soldiers[index]
	if mode == "order":
		if selected_order.is_empty() or selected_order.lane != lane or selected_order.slot != slot:
			selected_order = {"lane":lane, "slot":slot, "index":index}
			_log("%s 선택: 같은 방에서 원하는 순서의 병사를 선택하세요." % soldier.name)
		else:
			var old_index: int = selected_order.index
			if old_index != index:
				if (old_index == 0 or index == 0) and card_defs[soldiers[0].name].get("front_only", false):
					_log("%s은(는) 선두에 고정됩니다." % soldiers[0].name)
					selected_order.clear()
					_refresh()
					return
				var moved: Dictionary = soldiers.pop_at(old_index)
				soldiers.insert(index, moved)
				_log("%s 순서 변경: %d번 → %d번" % [moved.name, old_index + 1, index + 1])
			else:
				_log("병사 순서 선택을 취소했습니다.")
			selected_order.clear()
	elif mode == "rest":
		if soldier.placed_round == round_number:
			_log("이번 라운드에 새로 배치한 병사는 회수 모드로 취소할 수 있습니다.")
			return
		soldiers.remove_at(index)
		reserves.append({"soldier":soldier, "ready_round":round_number + 1, "healed":false})
		_log("%s 휴식: 이번 웨이브 종료 후 최대 체력의 30%% 회복" % soldier.name)
	else:
		moving_soldier = {"source":"room", "lane":lane, "slot":slot, "index":index}
		_log("%s 선택: 이동할 방을 클릭하세요." % soldier.name)
	_refresh()

func _reserve_pressed(index: int) -> void:
	if phase != "준비" or index < 0 or index >= reserves.size(): return
	var entry: Dictionary = reserves[index]
	if not entry.healed and entry.ready_round != round_number + 1: return
	mode = "move"
	selected_order.clear()
	selected_card = -1
	moving_soldier = {"source":"reserve", "index":index}
	_log("%s 선택: 배치할 방을 클릭하세요." % entry.soldier.name)
	_refresh()

func _remove_trap(lane: int, slot: int, index: int) -> void:
	if phase != "준비" or mode != "remove": return
	var traps: Array = lanes[lane].traps[slot]
	if index < 0 or index >= traps.size(): return
	var trap: Dictionary = traps.pop_at(index)
	if trap.placed_round == round_number:
		cost += card_defs[trap.name].cost
		discard_pile.erase(trap.card)
		hand.append(trap.card)
		cards_used -= 1
		_log("%s 배치 취소: 카드와 코스트 반환" % trap.name)
	else:
		_log("%s 철거: 이전 라운드 배치로 환급 없음 (덱은 유지)" % trap.name)
	_refresh()

func _slot_pressed(lane: int, slot: int, is_room: bool) -> void:
	if phase != "준비": return
	var placements: Array = lanes[lane]["rooms" if is_room else "traps"][slot]
	if mode == "move":
		if not is_room:
			_log("병사는 방에만 이동할 수 있습니다.")
			return
		if moving_soldier.is_empty():
			_log("방 아래의 병사 버튼을 먼저 선택하세요.")
			return
		var source: Array
		if moving_soldier.source == "room":
			source = lanes[moving_soldier.lane].rooms[moving_soldier.slot]
			if moving_soldier.lane == lane and moving_soldier.slot == slot:
				moving_soldier.clear()
				_refresh()
				return
		else:
			source = reserves
		if placements.size() >= 4:
			_log("방에는 최대 4명을 배치할 수 있습니다.")
			return
		var entry: Dictionary = source[moving_soldier.index]
		var soldier: Dictionary = entry.soldier if moving_soldier.source == "reserve" else entry
		if not _front_allowed(soldier.name, placements):
			_log("선두 고정 병사는 같은 방에 둘 수 없습니다.")
			return
		source.pop_at(moving_soldier.index)
		if moving_soldier.source == "reserve": soldier.placed_round = round_number - 1
		_put_soldier(placements, soldier)
		moving_soldier.clear()
		_log("%s 무료 이동: 체력 %d/%d" % [soldier.name, soldier.hp, soldier.max_hp])
	elif mode == "rest":
		_log("방 아래의 병사 버튼을 선택하면 휴식시킬 수 있습니다.")
	elif mode == "order":
		_log("지도 아래의 병사 버튼을 선택해 순서를 바꾸세요.")
	elif mode == "remove":
		if placements.is_empty(): return
		if not is_room:
			_remove_trap(lane, slot, placements.size() - 1)
			return
		var target_index := -1
		for i in range(placements.size() - 1, -1, -1):
			if placements[i].placed_round == round_number:
				target_index = i
				break
		if target_index < 0:
			_log("이전 라운드의 병사는 병사 휴식으로 회수하세요.")
			return
		var target: Dictionary = placements.pop_at(target_index)
		cost += card_defs[target.name].cost
		discard_pile.erase(target.card)
		hand.append(target.card)
		cards_used -= 1
		_log("%s 회수: 코스트 반환" % target.name)
	elif mode == "rearm":
		if is_room or placements.is_empty(): return
		# Rearm the first inactive trap on this tile; repeat for other slots.
		for trap in placements:
			if not trap.active:
				var price: int = 5 * maxi(1, trap.hits)
				if gold < price:
					_log("골드가 부족합니다. 재장전 비용 %dG" % price)
					return
				gold -= price
				trap.active = true
				trap.hits = 0
				_log("%s 재장전: %dG" % [trap.name, price])
				_refresh()
				return
		_log("재장전할 함정이 없습니다.")
	else:
		if selected_card < 0 or selected_card >= hand.size():
			_log("먼저 손패의 카드를 선택하세요.")
			return
		var card: Dictionary = hand[selected_card]
		var data: Dictionary = card_defs[card.name]
		if _unique_in_play(card.name):
			_log("#고유: 같은 병사를 중복 배치할 수 없습니다.")
			return
		if (data.type == "soldier") != is_room:
			_log("병사는 방에, 함정은 통로에 배치합니다.")
			return
		if cost < data.cost:
			_log("코스트가 부족합니다.")
			return
		if is_room and placements.size() >= 4:
			_log("방에는 최대 4명을 배치합니다.")
			return
		if is_room and not _front_allowed(card.name, placements):
			_log("선두 고정 병사는 같은 방에 둘 수 없습니다.")
			return
		if not is_room:
			for existing in placements:
				if card_defs[existing.name].slot == data.slot:
					_log("같은 설치면에는 함정을 하나만 놓을 수 있습니다.")
					return
		var placed := {"name":card.name, "card":card, "placed_round":round_number}
		if is_room:
			placed["hp"] = data.hp
			placed["max_hp"] = data.hp
		else:
			placed["active"] = true
			placed["hits"] = 0
		if is_room: _put_soldier(placements, placed)
		else: placements.append(placed)
		cost -= data.cost
		cards_used += 1
		hand.remove_at(selected_card)
		discard_pile.append(card)
		selected_card = -1
		_log("%s 배치" % card.name)
	_refresh()

func _log(value: String) -> void:
	log_lines.append(value)
	if log_lines.size() > 250: log_lines.pop_front()
	if log_box: log_box.text = "\n".join(log_lines)

func _refresh() -> void:
	if not summary: return
	summary.text = "%d / 20 라운드   |   %s   |   코스트 %d / %d   |   골드 %d   |   드로우 %d장 · 버린 더미 %d장" % [round_number, phase, cost, max_cost, gold, draw_pile.size(), discard_pile.size()]
	var instructions := {"card":"손패 선택 → 칸 클릭", "remove":"지도 아래 함정 선택해 철거 · 새 배치는 환급", "move":"병사 선택 → 이동할 방 클릭", "order":"병사 선택 → 같은 방의 원하는 순서 선택", "rest":"병사 선택 → 한 웨이브 휴식", "rearm":"재장전 모드: 비활성 함정 클릭"}
	status_label.text = "%s   |   속도 %s   |   방 정원 4명 · 재장전 발동당 5G · 휴식 시 최대 체력의 30%% 회복" % [instructions[mode], "빠름" if speed < 0.4 else "보통"]
	start_button.disabled = phase != "준비"
	_clear(party_box)
	for i in range(parties.size()):
		var party: Dictionary = parties[i]
		var descriptions: Array[String] = []
		for unit in party.units:
			descriptions.append("%s HP%d 공격%d" % [unit.name, unit.hp, unit.attack])
		var location := "처치" if party.done else ("입구 대기" if party.pos < 0 else ("통로 %d" % (int(party.pos / 2) + 1) if party.pos % 2 == 0 else "방 %d" % (int(party.pos / 2) + 1)))
		var label_value := "%s파티 %d → %s 경로 · %s | %s" % ["▶ " if i == selected_party else "", i + 1, "위" if party.lane == 0 else "아래", location, " / ".join(descriptions)]
		party_box.add_child(_button(label_value, _select_party.bind(i)))
	_clear(board_box)
	var map_view = preload("res://map_art.gd").new()
	map_view.game = self
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_child(map_view)
	if mode == "move" or mode == "rest" or mode == "order":
		for lane in range(2):
			var unit_row := HBoxContainer.new()
			board_box.add_child(unit_row)
			var unit_label := _label("%s 병사 선택:" % ("위" if lane == 0 else "아래"))
			unit_label.custom_minimum_size.x = 125
			unit_row.add_child(unit_label)
			for slot in range(2):
				for i in range(lanes[lane].rooms[slot].size()):
					var soldier: Dictionary = lanes[lane].rooms[slot][i]
					var picked: bool = mode == "order" and not selected_order.is_empty() and selected_order.lane == lane and selected_order.slot == slot and selected_order.index == i
					var soldier_button := _button("%s방%d · %d번\n%s HP%d/%d" % ["▶ " if picked else "", slot + 1, i + 1, soldier.name, soldier.hp, soldier.max_hp], _soldier_pressed.bind(lane, slot, i))
					soldier_button.custom_minimum_size.x = 130
					unit_row.add_child(soldier_button)
	if mode == "remove":
		for lane in range(2):
			var trap_row := HBoxContainer.new()
			board_box.add_child(trap_row)
			var trap_label := _label("%s 함정 철거:" % ("위" if lane == 0 else "아래"))
			trap_label.custom_minimum_size.x = 125
			trap_row.add_child(trap_label)
			for slot in range(2):
				for i in range(lanes[lane].traps[slot].size()):
					var trap: Dictionary = lanes[lane].traps[slot][i]
					var state := "이번 배치·환급" if trap.placed_round == round_number else "기존·환급 없음"
					trap_row.add_child(_button("통로%d %s\n%s" % [slot + 1, trap.name, state], _remove_trap.bind(lane, slot, i)))
	_clear(reserves_box)
	reserves_box.add_child(_label("휴식 병사 · 회복 완료 또는 휴식 취소 후 무료 재배치", 16))
	var reserve_row := HBoxContainer.new()
	reserves_box.add_child(reserve_row)
	if reserves.is_empty():
		var empty_label := _label("없음", 14)
		empty_label.custom_minimum_size.x = 60
		reserve_row.add_child(empty_label)
	for i in range(reserves.size()):
		var entry: Dictionary = reserves[i]
		var state := "회복 완료" if entry.healed else "이번 웨이브 휴식 예정"
		reserve_row.add_child(_button("%s %d/%d · %s" % [entry.soldier.name, entry.soldier.hp, entry.soldier.max_hp, state], _reserve_pressed.bind(i)))
	_clear(hand_box)
	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var data: Dictionary = card_defs[card.name]
		var text_value: String = "%s%s\n비용 %d\n%s" % ["▶" if selected_card == i else "", card.name, data.cost, data.description]
		if data.type == "trap": text_value += "\n" + data.slot
		var card_button := _button(text_value, _select_card.bind(i))
		var keyword_help := ""
		if data.get("consumable", false): keyword_help += "#소모성: 발동 후 재장전 전까지 다시 발동하지 않습니다.\n"
		if data.get("regen", 0) > 0: keyword_help += "#재생: 매 라운드 준비 시작 시 표시된 만큼 회복합니다.\n"
		if data.get("lifesteal", 0) > 0: keyword_help += "#흡혈: 공격할 때 표시된 만큼 회복합니다.\n"
		if data.get("blur", false): keyword_help += "#흐릿함: 다른 병사가 있으면 단일 공격의 대상이 되지 않습니다.\n"
		if data.get("poison", 0) > 0: keyword_help += "#중독: 대상이 행동할 때 표시된 만큼 피해를 입습니다.\n"
		if data.get("bleed", 0) > 0: keyword_help += "#출혈: 대상이 피해를 입을 때 표시된 만큼 추가 피해를 입습니다.\n"
		if data.get("unique", false): keyword_help += "#고유: 같은 병사가 배치 또는 휴식 중이면 배치할 수 없습니다.\n"
		card_button.tooltip_text = keyword_help
		if _unique_in_play(card.name):
			card_button.disabled = true
		card_button.custom_minimum_size = Vector2(120, 158)
		if card_icons.has(card.name):
			card_button.icon = card_icons[card.name]
			card_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			card_button.add_theme_constant_override("icon_max_width", 88)
		hand_box.add_child(card_button)

func _toggle_speed() -> void:
	speed = 0.04 if speed >= 0.4 else 0.4
	_refresh()

func _damage_enemy(unit: Dictionary, amount: int, source: String) -> void:
	var actual: int = mini(unit.hp, amount)
	unit.hp -= actual
	damage_total += actual
	battle_notice = "%s → %s · %d 피해" % [source, unit.name, actual]
	_log("%s → %s %d 피해 (HP %d)" % [source, unit.name, actual, unit.hp])
	if actual > 0 and unit.hp > 0 and unit.get("bleed", 0) > 0:
		var extra: int = mini(unit.hp, unit.bleed)
		unit.hp -= extra
		damage_total += extra
		_log("%s #출혈 %d 피해 (HP %d)" % [unit.name, extra, unit.hp])

func _soldier_hit_enemy(unit: Dictionary, amount: int, ally: Dictionary) -> void:
	_damage_enemy(unit, amount, ally.name)
	if unit.hp <= 0 or amount <= 0: return
	var data: Dictionary = card_defs[ally.name]
	for keyword in ["poison", "bleed"]:
		var strength: int = data.get(keyword, 0)
		if strength > 0:
			unit[keyword] = unit.get(keyword, 0) + strength
			_log("%s에게 #%s%d 적용" % [unit.name, KEYWORD_NAMES[keyword], unit[keyword]])

func _live_enemies(party: Dictionary) -> Array:
	return party.units.filter(func(unit): return unit.hp > 0)

func _single_target_soldier(soldiers: Array) -> Dictionary:
	for soldier in soldiers:
		if not card_defs[soldier.name].get("blur", false): return soldier
	return soldiers.front()

func _apply_traps(party: Dictionary, slot: int) -> void:
	for trap in lanes[party.lane].traps[slot]:
		if not trap.active: continue
		var targets := _live_enemies(party)
		if targets.is_empty(): break
		trap.hits += 1
		if card_defs[trap.name].get("consumable", false):
			trap.active = false
		var damage: int = card_defs[trap.name].damage + trap_bonus
		if trap.name == "낙석":
			for unit in targets: _damage_enemy(unit, damage, trap.name)
		elif trap.name == "화살":
			for i in range(maxi(0, targets.size() - 2), targets.size()):
				_damage_enemy(targets[i], damage, trap.name)
		else:
			_damage_enemy(targets.front(), damage, trap.name)

func _fight(party: Dictionary, slot: int) -> void:
	var soldiers: Array = lanes[party.lane].rooms[slot]
	if soldiers.is_empty() or _live_enemies(party).is_empty(): return
	var fight_token := wave_token
	_log("%s 경로 방 %d 전투 시작" % ["위" if party.lane == 0 else "아래", slot + 1])
	# Each cycle snapshots actors. A dead actor loses its turn; surviving actors act once.
	while not soldiers.is_empty() and not _live_enemies(party).is_empty():
		var allies := soldiers.duplicate()
		var enemies := _live_enemies(party).duplicate()
		for i in range(maxi(allies.size(), enemies.size())):
			if i < allies.size() and allies[i].hp > 0 and not _live_enemies(party).is_empty():
				var ally: Dictionary = allies[i]
				var attack: int = card_defs[ally.name].attack + soldier_bonus
				if card_defs[ally.name].get("area_attack", false):
					for enemy in _live_enemies(party): _soldier_hit_enemy(enemy, attack, ally)
				else:
					_soldier_hit_enemy(_live_enemies(party).front(), attack, ally)
				var lifesteal: int = card_defs[ally.name].get("lifesteal", 0)
				if lifesteal > 0:
					var restored: int = mini(lifesteal, ally.max_hp - ally.hp)
					ally.hp += restored
					if restored > 0: _log("%s #흡혈: 체력 %d 회복" % [ally.name, restored])
				if phase == "웨이브":
					_refresh()
					await get_tree().create_timer(speed * 0.7).timeout
					if fight_token != wave_token: return
			if i < enemies.size() and enemies[i].hp > 0 and not soldiers.is_empty():
				var enemy: Dictionary = enemies[i]
				if enemy.get("poison", 0) > 0:
					_damage_enemy(enemy, enemy.poison, "#중독")
					if enemy.hp <= 0: continue
				var targets: Array = soldiers.duplicate() if enemy.get("area_attack", false) else [_single_target_soldier(soldiers)]
				for target in targets:
					target.hp = maxi(0, target.hp - enemy.attack)
					battle_notice = "%s → %s · %d 피해" % [enemy.name, target.name, enemy.attack]
					_log("%s → %s %d 피해 (HP %d)" % [enemy.name, target.name, enemy.attack, target.hp])
					if target.hp <= 0:
						soldiers.erase(target)
						_log("%s 전사" % target.name)
				if phase == "웨이브":
					_refresh()
					await get_tree().create_timer(speed * 0.7).timeout
					if fight_token != wave_token: return
			if soldiers.is_empty() or _live_enemies(party).is_empty(): break

func _start_wave() -> void:
	if phase != "준비": return
	_discard_hand()
	moving_soldier.clear()
	selected_order.clear()
	phase = "웨이브"
	selected_card = -1
	wave_token += 1
	var my_token := wave_token
	_log("=== %d라운드 웨이브 시작 ===" % round_number)
	_refresh()
	while true:
		var remaining := false
		for p in range(parties.size()):
			var party: Dictionary = parties[p]
			if party.done: continue
			remaining = true
			# Same-lane parties queue: only move into an unoccupied segment.
			var next_pos: int = party.pos + 1
			var occupied := false
			for j in range(p):
				if not parties[j].done and parties[j].lane == party.lane and parties[j].pos == next_pos:
					occupied = true
			if occupied: continue
			party.pos = next_pos
			if next_pos >= 4:
				_finish(false)
				return
			_log("파티 %d: %s 경로 %s %d" % [p + 1, "위" if party.lane == 0 else "아래", "통로" if next_pos % 2 == 0 else "방", int(next_pos / 2) + 1])
			if next_pos % 2 == 0: _apply_traps(party, int(next_pos / 2))
			else:
				await _fight(party, int(next_pos / 2))
				if my_token != wave_token: return
			if _live_enemies(party).is_empty():
				party.done = true
				_log("파티 %d 격파" % (p + 1))
			_refresh()
			await get_tree().create_timer(speed).timeout
			if my_token != wave_token: return
		if not remaining: break
	_wave_won()

func _wave_won() -> void:
	played_rounds = round_number
	gold += 10
	_log("%d라운드 방어 성공 · 수입 10G" % round_number)
	for entry in reserves:
		if not entry.healed and entry.ready_round == round_number + 1:
			var soldier: Dictionary = entry.soldier
			var restored: int = mini(ceili(soldier.max_hp * REST_HEAL_RATE), soldier.max_hp - soldier.hp)
			soldier.hp += restored
			entry.healed = true
			_log("%s 휴식 완료 · 체력 %d 회복" % [soldier.name, restored])
	for lane in lanes:
		for tile in lane.traps:
			for trap in tile:
				if trap.active and trap.hits > 0:
					trap.active = false
	if round_number == 20:
		_finish(true)
		return
	pending_event = round_number % 2 == 0
	if round_number % 5 == 0:
		_show_rewards()
	elif pending_event:
		_show_event()
	else:
		_next_round()

func _show_rewards() -> void:
	phase = "보스 보상"
	_clear(options_box)
	var choices := []
	for reward in REWARDS:
		if not rewards_used.has(reward): choices.append(reward)
	for i in range(mini(3, choices.size())):
		var index := rng.randi_range(0, choices.size() - 1)
		var reward: String = choices.pop_at(index)
		options_box.add_child(_button(reward, _choose_reward.bind(reward)))
	_log("보스 격파! 보상 하나를 선택하세요.")
	_refresh()

func _choose_reward(reward: String) -> void:
	if phase != "보스 보상": return
	rewards_used.append(reward)
	match reward:
		"최대 코스트 +1": max_cost += 1
		"최대 코스트 +2": max_cost += 2
		"모든 병사 공격력 +2": soldier_bonus += 2
		"모든 병사 공격력 +1": soldier_bonus += 1
		"모든 함정 피해 +2": trap_bonus += 2
		"골드 +12": gold += 12
		"모든 병사 체력 10 회복": _heal_all(10)
		"언데드 골렘 카드 획득": _add_card("언데드 골렘")
		"덱에 낙석 2장 추가":
			_add_card("낙석")
			_add_card("낙석")
	_log("보상 선택: " + reward)
	_clear(options_box)
	if pending_event: _show_event()
	else: _next_round()

func _heal_all(amount: int) -> void:
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room:
				soldier.hp = mini(soldier.max_hp, soldier.hp + amount)
	for entry in reserves:
		var soldier: Dictionary = entry.soldier
		soldier.hp = mini(soldier.max_hp, soldier.hp + amount)

func _eligible_events() -> Array:
	var eligible: Array = []
	for event_name in TEST_EVENTS:
		if not seen_events.has(event_name): eligible.append(event_name)
	if round_number <= 10 and not seen_events.has(VAMPIRE_EVENT):
		eligible.append(VAMPIRE_EVENT)
	return eligible

func _random_event(eligible: Array):
	if eligible.is_empty(): return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]

func _research_candidates() -> Array:
	return deck.filter(func(card): return card_defs[card.name].type == "soldier")

func _start_research() -> void:
	if phase != "이벤트" or current_event != "가능성 연구": return
	if gold < RESEARCH_PRICE:
		_log("골드가 부족합니다. 가능성 연구에는 70G가 필요합니다.")
		return
	if _research_candidates().size() < 2:
		_log("덱에 병사 카드가 2장 이상 필요합니다.")
		return
	research_selected.clear()
	_show_research_choices()

func _show_research_choices() -> void:
	_clear(options_box)
	var panel := VBoxContainer.new()
	options_box.add_child(panel)
	panel.add_child(_label("덱에서 병사 카드 2장 선택 (%d/2)" % research_selected.size(), 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for card in _research_candidates():
		var data: Dictionary = card_defs[card.name]
		var selected := research_selected.has(card.id)
		var label := "%s%s · 코스트 %d\n%s" % ["✓ " if selected else "", card.name, data.cost, data.description]
		list.add_child(_button(label, _select_research_card.bind(card.id)))
	if research_selected.size() == 2:
		panel.add_child(_button("선택한 두 장 합성 (70G)", _finish_research))
	panel.add_child(_button("취소", _cancel_research))

func _select_research_card(card_id: int) -> void:
	if phase != "이벤트" or current_event != "가능성 연구": return
	if research_selected.has(card_id): research_selected.erase(card_id)
	elif research_selected.size() < 2 and _research_candidates().any(func(card): return card.id == card_id): research_selected.append(card_id)
	_show_research_choices()

func _cancel_research() -> void:
	research_selected.clear()
	_clear(options_box)
	options_box.add_child(_button("병사 카드 2장 합성 (70G)", _start_research))
	options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))

func _finish_research() -> void:
	if phase != "이벤트" or current_event != "가능성 연구" or gold < RESEARCH_PRICE or research_selected.size() != 2: return
	var materials: Array = _research_candidates().filter(func(card): return research_selected.has(card.id))
	if materials.size() != 2: return
	var a: Dictionary = card_defs[materials[0].name]
	var b: Dictionary = card_defs[materials[1].name]
	var name_value := "키메라 #%d" % next_card_id
	var result := {"type":"soldier", "cost":roundi((a.cost + b.cost) / 2.0), "hp":a.hp + b.hp, "attack":a.attack + b.attack}
	for keyword in ["regen", "lifesteal", "poison", "bleed"]:
		var amount: int = a.get(keyword, 0) + b.get(keyword, 0)
		if amount > 0: result[keyword] = amount
	if a.get("front_only", false) or b.get("front_only", false): result["front_only"] = true
	if a.get("blur", false) or b.get("blur", false): result["blur"] = true
	var description := "HP %d · 공격 %d" % [result.hp, result.attack]
	if result.get("regen", 0) > 0: description += "\n#재생%d" % result.regen
	if result.get("lifesteal", 0) > 0: description += " #흡혈%d" % result.lifesteal
	if result.get("blur", false): description += " #흐릿함"
	if result.get("poison", 0) > 0: description += " #중독%d" % result.poison
	if result.get("bleed", 0) > 0: description += " #출혈%d" % result.bleed
	if result.get("front_only", false): description += " 선두 고정"
	result["description"] = description
	card_defs[name_value] = result
	card_icons[name_value] = card_icons["고블린"]
	sprite_icons[name_value] = sprite_icons["고블린"]
	for card in materials:
		deck.erase(card)
		hand.erase(card)
		draw_pile.erase(card)
		discard_pile.erase(card)
	gold -= RESEARCH_PRICE
	_add_card(name_value)
	research_selected.clear()
	_log("가능성 연구: %s + %s → %s · 70G" % [materials[0].name, materials[1].name, name_value])
	_clear(options_box)
	_next_round()

func _ritual_keyword_candidates(data: Dictionary) -> Array:
	var missing: Array = []
	for keyword in RITUAL_KEYWORDS:
		if not data.get(keyword, false if keyword == "blur" else 0): missing.append(keyword)
	if not missing.is_empty(): return missing
	return ["regen", "lifesteal", "poison", "bleed"]

func _apply_ritual() -> bool:
	var candidates := _research_candidates()
	if candidates.is_empty():
		_log("덱에 강화할 병사 카드가 없습니다.")
		return false
	var card: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var old_name: String = card.name
	var data: Dictionary = card_defs[old_name].duplicate(true)
	var choices := _ritual_keyword_candidates(data)
	var keyword: String = choices[rng.randi_range(0, choices.size() - 1)]
	var amount: int = RITUAL_KEYWORDS[keyword]
	if keyword == "blur": data[keyword] = true
	else: data[keyword] = data.get(keyword, 0) + amount
	data["unique_group"] = data.get("unique_group", old_name)
	var new_name := "%s [강화 #%d]" % [old_name, card.id]
	var keyword_label: String = "#%s%s" % [KEYWORD_NAMES[keyword], str(amount) if keyword != "blur" else ""]
	data["description"] += "\n추가 " + keyword_label
	card_defs[new_name] = data
	if card_icons.has(old_name): card_icons[new_name] = card_icons[old_name]
	if sprite_icons.has(old_name): sprite_icons[new_name] = sprite_icons[old_name]
	card.name = new_name
	_log("강화 의식: %s 카드에 %s 부여" % [old_name, keyword_label])
	return true

func _show_event() -> void:
	var eligible := _eligible_events()
	pending_event = false
	if eligible.is_empty():
		_log("등장 가능한 시험 이벤트가 없어 다음 라운드로 진행합니다.")
		_next_round()
		return
	phase = "이벤트"
	var event_name: String = _random_event(eligible)
	seen_events.append(event_name)
	current_event = event_name
	event_index += 1
	_clear(options_box)
	if current_event == VAMPIRE_EVENT:
		options_box.add_child(_button("녹티스 카드 영입 (30G · 임시)", _choose_event.bind("noctis")))
		options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))
	else:
		match current_event:
			"가능성 연구": options_box.add_child(_button("병사 카드 2장 합성 (70G)", _start_research))
			"강화 의식": options_box.add_child(_button("무작위 병사 강화 (0G)", _choose_event.bind("ritual")))
			"시험 이벤트 3": options_box.add_child(_button("오크 카드 영입 (4G · 시험)", _choose_event.bind("card")))
			"시험 이벤트 4": options_box.add_child(_button("화살 함정 카드 획득 (시험)", _choose_event.bind("arrow")))
		options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))
	_log("이벤트: %s · 선택지 하나를 고르세요." % event_name)
	_refresh()

func _choose_event(choice: String) -> void:
	if phase != "이벤트": return
	if current_event == "흡혈귀와의 만남" and choice not in ["noctis", "leave"]: return
	if current_event != VAMPIRE_EVENT:
		var allowed := {"강화 의식":"ritual", "시험 이벤트 3":"card", "시험 이벤트 4":"arrow"}
		if choice != "leave" and choice != allowed.get(current_event, ""): return
	if choice == "card" and gold < 4:
		_log("골드가 부족합니다. 다른 선택지를 고르세요.")
		return
	if choice == "noctis" and gold < NOCTIS_PRICE:
		_log("골드가 부족합니다. 돌아가기를 선택하세요.")
		return
	if choice == "ritual" and not _apply_ritual(): return
	match choice:
		"gold": gold += 5
		"heal": _heal_all(8)
		"card":
			gold -= 4
			_add_card("오크")
		"noctis":
			gold -= NOCTIS_PRICE
			_add_card("녹티스")
		"arrow": _add_card("화살")
	_log("이벤트 선택: " + {"gold":"골드 5 획득", "heal":"병사 전원 8 회복", "card":"오크 카드 영입", "arrow":"화살 함정 카드 획득", "noctis":"녹티스 카드 획득", "ritual":"강화 의식", "leave":"돌아가기"}[choice])
	_clear(options_box)
	_next_round()

func _next_round() -> void:
	round_number += 1
	_prepare_round()
	_log("%d라운드 준비. 발동한 함정은 골드로 재장전하세요." % round_number)

func _finish(won: bool) -> void:
	phase = "클리어" if won else "패배"
	var score: int = played_rounds * 100 + damage_total + gold * 2 + cards_used * 5
	_log("%s · 점수 %d | 클리어 %d라운드 · 피해 %d · 골드 %d · 사용 카드 %d" % [phase, score, played_rounds, damage_total, gold, cards_used])
	var record := {"result":phase, "score":score, "rounds":played_rounds, "damage":damage_total, "gold":gold, "cards":cards_used, "time":Time.get_datetime_string_from_system()}
	var records := []
	if FileAccess.file_exists(record_path):
		var file := FileAccess.open(record_path, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array: records = parsed
	records.append(record)
	var out := FileAccess.open(record_path, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(records, "\t"))
		_log("플레이 기록 저장 완료 (%d회)" % records.size())
	else:
		_log("플레이 기록 저장 실패")
	_refresh()
