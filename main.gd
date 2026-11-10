extends Control

# Prototype values; see README for the assumptions behind them.
const CARDS = {
	"가시": {"type":"trap", "slot":"바닥", "targeting":"front", "cost":1, "damage":6, "consumable":false, "description":"선두 1명 6 피해"},
	"화살": {"type":"trap", "slot":"벽", "targeting":"rear", "cost":1, "damage":7, "consumable":true, "description":"#소모성\n후방 2명 각 7 피해"},
	"낙석": {"type":"trap", "slot":"천장", "targeting":"all", "cost":2, "damage":8, "consumable":true, "description":"#소모성\n적 전체 각 8 피해"},
	"고블린": {"type":"soldier", "cost":1, "hp":14, "attack":3, "description":"HP 14 · 선두 3 피해"},
	"고블린 궁수": {"type":"soldier", "cost":1, "hp":8, "attack":6, "description":"HP 8 · 선두 6 피해"},
	"언데드 골렘": {"type":"soldier", "cost":3, "hp":30, "attack":4, "regen":10, "description":"HP 30 · 공격 4\n#재생10"},
	"오크": {"type":"soldier", "cost":2, "hp":30, "attack":5, "front_only":true, "description":"HP 30 · 공격 5\n선두 고정"},
	"녹티스": {"type":"soldier", "cost":2, "hp":20, "attack":8, "unique":true, "lifesteal":3, "description":"HP 20 · 공격 8\n#고유 #흡혈3"},
	"마법사": {"type":"soldier", "cost":2, "hp":14, "attack":4, "area_attack":true, "description":"HP 14 · 전체 4 피해"},
	"모험가": {"type":"soldier", "cost":1, "hp":15, "attack":5, "unique":true, "event_only":true, "versatile":true, "rarity":"특급", "description":"HP 15 · 공격 5\n#이벤트 #고유 #만능 · 방 이동 무료"},
	"용인전사": {"type":"soldier", "cost":1, "hp":15, "attack":5, "rarity":"상급", "description":"HP 15 · 공격 5"},
	"치명적인 독소": {"type":"skill", "cost":2, "toxins":5, "rarity":"특급", "description":"이번 웨이브의 모든 병사와 적에게 #중독5"},
	"유연한 사고": {"type":"skill", "cost":1, "draw":2, "discard":1, "rarity":"상급", "description":"카드 2장 드로우 후 1장 버리기"},
	"임프": {"type":"soldier", "cost":0, "hp":4, "attack":3, "rarity":"일반", "description":"HP 4 · 공격 3"},
	"슬라임": {"type":"soldier", "cost":1, "hp":13, "attack":5, "regen":4, "rarity":"상급", "description":"HP 13 · 공격 5\n#재생4"},
	"가고일": {"type":"soldier", "cost":2, "hp":26, "attack":7, "rarity":"일반", "description":"HP 26 · 공격 7"},
	"드래곤": {"type":"soldier", "cost":3, "hp":30, "attack":12, "area_attack":true, "rarity":"특급", "description":"HP 30 · 적 전체 12 피해"},
	"하피": {"type":"soldier", "cost":1, "hp":7, "attack":3, "targeting":"rear", "rarity":"일반", "description":"HP 7 · 후열 3 피해"},
	"사령술사": {"type":"soldier", "cost":6, "hp":25, "attack":5, "area_attack":true, "death_discount":true, "rarity":"상급", "description":"HP 25 · 전체 5 피해\n직전 아군 전사당 비용 -1"},
	"아라크네": {"type":"soldier", "cost":2, "hp":25, "attack":11, "targeting":"highest_attack", "rarity":"상급", "description":"HP 25 · 공격력 최고 적에게 11 피해"},
}
const ENEMY_TYPES = {
	"기사": {"hp":18, "attack":6, "enemy_cost":1, "targeting":"front", "description":"선두 병사 공격"},
	"저격수": {"hp":6, "attack":12, "enemy_cost":1, "targeting":"highest_attack", "requires_party":true, "description":"공격력이 가장 높은 병사 우선 공격 · 혼자 등장 불가"},
	"도적": {"hp":8, "attack":11, "enemy_cost":1, "targeting":"rear", "description":"후열 병사 우선 공격"},
	"방패병": {"hp":42, "attack":4, "enemy_cost":2, "targeting":"front", "taunt":true, "description":"각 방 첫 공격에 도발 · 방 전투 동안 자신에게 단일 공격 유도"},
	"동국의 검사": {"hp":60, "attack":10, "enemy_cost":3, "targeting":"front", "attack_count":0, "attack_boost_interval":3, "attack_boost":5, "description":"세 번째 공격마다 공격력 +5 후 공격"},
	"마법사": {"hp":15, "attack":9, "enemy_cost":2, "area_attack":true, "requires_party":true, "min_round":6, "description":"모든 병사 범위 공격 · 6라운드부터 · 혼자 등장 불가"},
	"회복술사": {"hp":10, "attack":10, "enemy_cost":1, "heal":true, "description":"공격 대신 체력이 부족한 아군을 공격력만큼 회복"},
	"검신 알론드": {"hp":200, "attack":40, "enemy_cost":10, "targeting":"front", "boss_only":true, "cleanse_every":3, "attacks_since_cleanse":0, "description":"3회 공격 후 다음 행동 전, 또는 방의 병사 전멸 시 상태 이상 회복"},
}
const ENEMY_BUDGETS := [1, 2, 2, 2, 5, 3, 3, 4, 4, 8, 5, 5, 6, 6, 10, 7, 7, 8, 8, 20]
const BOSS_PARTIES = {5:[["기사", "동국의 검사", "저격수"]], 15:[["검신 알론드"]]}
const COST_DRAW_RELIC = "유물(임시): 최대 코스트 +1 · 드로우 -1"
const REWARDS = ["최대 코스트 +1", "모든 병사 공격력 +2", "모든 함정 피해 +2", "골드 +12", "모든 병사 체력 10 회복", "언데드 골렘 카드 획득", "최대 코스트 +2", "모든 병사 공격력 +1", COST_DRAW_RELIC]
const STARTER_ONLY_CARDS = ["고블린", "고블린 궁수", "가시", "화살", "낙석"]
const ROUND_CARD_POOL = ["오크", "임프", "슬라임", "가고일", "드래곤", "하피", "사령술사", "아라크네", "용인전사", "치명적인 독소", "유연한 사고"]
const TEST_EVENTS = ["가능성 연구", "강화 의식", "넌 필요없어!!", "그냥 처음에 보여준거로 해주세요"]
const MADNESS_EVENT = "살을주고 목을친다"
const VAMPIRE_EVENT = "흡혈귀와의 만남"
const WOUNDED_EVENT = "상처입은 모험가"
const DRAGON_EVENT = "용족의 비술"
const NOCTIS_PRICE := 30
const RITUAL_KEYWORDS = {"regen":5, "lifesteal":2, "blur":0, "poison":5, "bleed":3}
const KEYWORD_NAMES = {"regen":"재생", "lifesteal":"흡혈", "blur":"흐릿함", "poison":"중독", "bleed":"출혈"}
const RESEARCH_PRICE := 70
const REST_HEAL_RATE := 0.30
const MAP_STAGES = [
	{"type":"trap", "slot":0}, {"type":"room", "slot":0},
	{"type":"trap", "slot":1}, {"type":"trap", "slot":2},
	{"type":"room", "slot":1}, {"type":"trap", "slot":3},
	{"type":"room", "slot":2}, {"type":"trap", "slot":4},
]
var rng := RandomNumberGenerator.new()
var seed_rng := RandomNumberGenerator.new()
var card_defs: Dictionary = CARDS.duplicate(true)
var research_selected: Array = []
var selected_event_card := -1
var madness_relic := false
var draw_penalty := 0
var dragon_pendant := false
var toxin_power := 0
var pending_skill_discards := 0
var deck: Array = []
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var lanes: Array = []
var map_seed := 0
var map_crossings: Array = []
var parties: Array = []
var reserves: Array = []
var moving_soldier: Dictionary = {}
var selected_order: Dictionary = {}
var phase := "준비"
var round_number := 1
var max_cost := 3
var cost := 3
var gold := 30
var soldier_bonus := 0
var trap_bonus := 0
var damage_total := 0
var cards_used := 0
var deaths_this_wave := 0
var previous_wave_deaths := 0
var selected_card := -1
var mode := "card"
var selected_party := 0
var previous_parties: Array = []
var previous_round := 0
var selected_previous_party := 0
var showing_previous := false
var offered_cards: Array = []
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
var seed_input: LineEdit
var party_box: VBoxContainer
var enemy_detail_box: VBoxContainer
var deck_view_box: VBoxContainer
var showing_deck := false
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
	seed_rng.randomize()
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
	for kind in ["마법사", "고블린", "고블린 궁수", "언데드 골렘", "오크", "녹티스", "임프", "슬라임", "가고일", "드래곤", "하피", "사령술사", "아라크네", "모험가", "용인전사", "치명적인 독소", "유연한 사고"]:
		card_icons[kind] = pixel_art.make_card(kind)
		sprite_icons[kind] = pixel_art.make_sprite(kind)
	for kind in ["도적", "방패병", "저격수", "기사", "동국의 검사", "검신 알론드", "마법사", "회복술사", "보스"]:
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
	var seed_row := HBoxContainer.new()
	root.add_child(seed_row)
	var seed_label := _label("게임 시드:", 15)
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_label.custom_minimum_size.x = 85
	seed_row.add_child(seed_label)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "숫자 시드"
	seed_input.custom_minimum_size = Vector2(160, 36)
	seed_row.add_child(seed_input)
	var seed_button := _button("시드로 새 게임", _start_seeded_game)
	seed_button.custom_minimum_size.x = 145
	seed_row.add_child(seed_button)
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
	action_box.add_child(_button("함정 순서", _set_mode.bind("trap_order")))
	start_button = _button("웨이브 시작", _start_wave)
	action_box.add_child(start_button)
	action_box.add_child(_button("속도 변경", _toggle_speed))
	action_box.add_child(_button("전체 덱 보기", _toggle_deck_view))
	music_button = _button("배경음: 켬", _toggle_music)
	action_box.add_child(music_button)
	action_box.add_child(_button("새 게임", _new_game))
	var details_row := HBoxContainer.new()
	root.add_child(details_row)
	var left_details := VBoxContainer.new()
	left_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_row.add_child(left_details)
	var enemy_panel := PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(320, 260)
	details_row.add_child(enemy_panel)
	enemy_detail_box = VBoxContainer.new()
	enemy_detail_box.add_theme_constant_override("separation", 5)
	enemy_panel.add_child(enemy_detail_box)
	reserves_box = VBoxContainer.new()
	left_details.add_child(reserves_box)
	options_box = HBoxContainer.new()
	left_details.add_child(options_box)
	deck_view_box = VBoxContainer.new()
	left_details.add_child(deck_view_box)
	left_details.add_child(_label("손패 · 각 카드를 누른 뒤 배치할 칸을 누르세요", 19))
	hand_box = HBoxContainer.new()
	left_details.add_child(hand_box)
	root.add_child(_label("진행 및 전투 기록", 19))
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size = Vector2(0, 230)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	root.add_child(log_box)

func _starter_only(name_value: String) -> bool:
	if name_value in STARTER_ONLY_CARDS: return true
	return card_defs.has(name_value) and card_defs[name_value].get("unique_group", name_value) in STARTER_ONLY_CARDS

func _add_card(name_value: String, initial := false) -> void:
	if not initial and _starter_only(name_value):
		_log("%s은(는) 시작 덱 전용 카드입니다." % name_value)
		return
	var card := {"id":next_card_id, "name":name_value}
	deck.append(card)
	if initial: draw_pile.append(card)
	else: discard_pile.append(card)
	next_card_id += 1

func _soldier_stats(name_value: String) -> Dictionary:
	var data: Dictionary = card_defs[name_value]
	var hp: int = data.hp
	var attack: int = data.attack
	if madness_relic:
		var reduced_hp := maxi(1, ceili(hp / 2.0))
		attack += int((hp - reduced_hp) / 2.0)
		hp = reduced_hp
	return {"hp":hp, "attack":attack}

func _card_cost(name_value: String) -> int:
	var data: Dictionary = card_defs[name_value]
	return maxi(0, data.cost - previous_wave_deaths) if data.get("death_discount", false) else data.cost

func _display_card_description(name_value: String) -> String:
	var data: Dictionary = card_defs[name_value]
	var description: String = data.description
	if data.has("rarity"): description = "#%s\n%s" % [data.rarity, description]
	if data.get("death_discount", false):
		description += "\n기본 %d · 직전 전사 %d" % [data.cost, previous_wave_deaths]
	if data.type != "soldier" or not madness_relic: return description
	var stats := _soldier_stats(name_value)
	return "유물 적용: HP %d · 공격 %d\n기본: %s" % [stats.hp, stats.attack, description]

func _gain_madness_relic() -> void:
	if madness_relic: return
	madness_relic = true
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room: _apply_madness_to_unit(soldier)
	for entry in reserves: _apply_madness_to_unit(entry.soldier)
	_log("유물 획득: 광기의 집념")

func _apply_madness_to_unit(soldier: Dictionary) -> void:
	var new_max := maxi(1, ceili(soldier.max_hp / 2.0))
	soldier.max_hp = new_max
	soldier.hp = mini(soldier.hp, new_max)

func _shuffle_draw_pile() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp

func _start_seeded_game() -> void:
	var value := seed_input.text.strip_edges()
	if not value.is_valid_int() or value.to_int() < 0:
		_log("0 이상의 정수 시드를 입력하세요.")
		return
	_new_game(value.to_int())

func _generate_map(seed_value: int) -> void:
	map_seed = seed_value
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = map_seed
	var lane_count := map_rng.randi_range(2, 3)
	map_crossings.clear()
	# Crossings start only at rooms.
	var available_boundaries := [1, 4, 6] if lane_count == 2 else [1, 4]
	var crossing_count := map_rng.randi_range(2, available_boundaries.size())
	for i in range(crossing_count):
		var boundary: int = available_boundaries.pop_at(map_rng.randi_range(0, available_boundaries.size() - 1))
		map_crossings.append({"after":boundary, "top":map_rng.randi_range(0, lane_count - 2)})
	map_crossings.sort_custom(func(a, b): return a.after < b.after)
	lanes.clear()
	var extra_trap_lane := map_rng.randi_range(0, lane_count - 1) if lane_count == 3 else -1
	for lane in range(lane_count):
		if lane_count == 2:
			lanes.append({"traps":[[], [], [], [], []], "rooms":[[], [], []], "stages":MAP_STAGES.duplicate(true)})
		else:
			# Across three lanes: six rooms and ten corridors.
			var extra := lane == extra_trap_lane
			var stages := [
				{"type":"trap", "slot":0}, {"type":"room", "slot":0},
				{"type":"trap", "slot":1}, {"type":"trap", "slot":2} if extra else {"type":"path"},
				{"type":"room", "slot":1}, {"type":"trap", "slot":3 if extra else 2},
				{"type":"path"}, {"type":"path"},
			]
			var traps := [[], [], [], []] if extra else [[], [], []]
			lanes.append({"traps":traps, "rooms":[[], []], "stages":stages})

func _map_stage(lane: int, step: int) -> Dictionary:
	return lanes[lane].stages[step]

func _crossing_destination(lane: int, after: int) -> int:
	for crossing in map_crossings:
		if crossing.after == after:
			if lane == crossing.top: return lane + 1
			if lane == crossing.top + 1: return lane - 1
	return lane

func _seeded_rng(domain: String, round_value: int) -> RandomNumberGenerator:
	var stream := RandomNumberGenerator.new()
	stream.seed = ("%d:%s:%d" % [map_seed, domain, round_value]).hash()
	return stream

func _sample_options(pool: Array, count: int, stream: RandomNumberGenerator) -> Array:
	var remaining := pool.duplicate()
	var result: Array = []
	for i in range(mini(count, remaining.size())):
		result.append(remaining.pop_at(stream.randi_range(0, remaining.size() - 1)))
	return result

func _make_party_route(start_lane: int, route_rng: RandomNumberGenerator = null) -> Array:
	var route: Array = []
	var current := start_lane
	var stream: RandomNumberGenerator = route_rng if route_rng else rng
	for stage in range(MAP_STAGES.size()):
		route.append(current)
		var neighbor := _crossing_destination(current, stage)
		if neighbor != current and stream.randi_range(0, 1) == 1: current = neighbor
	return route

func _lane_name(index: int) -> String:
	if lanes.size() == 2: return "위" if index == 0 else "아래"
	return ["위", "가운데", "아래"][clampi(index, 0, 2)]

func _new_game(seed_value: int = -1) -> void:
	wave_token += 1
	map_seed = int(seed_rng.randi()) if seed_value < 0 else seed_value
	rng.seed = ("%d:game:0" % map_seed).hash()
	battle_notice = ""
	phase = "준비"
	round_number = 1
	max_cost = 3
	cost = 3
	gold = 30
	soldier_bonus = 0
	trap_bonus = 0
	madness_relic = false
	draw_penalty = 0
	dragon_pendant = false
	toxin_power = 0
	pending_skill_discards = 0
	selected_event_card = -1
	damage_total = 0
	cards_used = 0
	deaths_this_wave = 0
	previous_wave_deaths = 0
	played_rounds = 0
	selected_card = -1
	selected_party = 0
	previous_parties.clear()
	previous_round = 0
	selected_previous_party = 0
	showing_previous = false
	showing_deck = false
	offered_cards.clear()
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
	for card_name in ["가시", "화살", "낙석", "고블린", "고블린", "고블린", "고블린 궁수", "고블린 궁수"]:
		_add_card(card_name, true)
	_shuffle_draw_pile()
	_generate_map(map_seed)
	if seed_input: seed_input.text = str(map_seed)
	log_lines.clear()
	_clear(options_box)
	_prepare_round()
	_log("새 게임 · 게임 시드 %d. 적 경로를 확인하고 방어선을 배치하세요." % map_seed)

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
	toxin_power = 0
	pending_skill_discards = 0
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room: soldier.erase("poison")
	for entry in reserves: entry.soldier.erase("poison")
	cost = max_cost
	selected_card = -1
	mode = "card"
	_regenerate_soldiers()
	_draw_hand(maxi(0, 5 - draw_penalty))
	_generate_parties()
	if dragon_pendant:
		for party in parties:
			for enemy in _live_enemies(party): _damage_enemy(enemy, 4, "용족의 팬던트")
			if _live_enemies(party).is_empty(): party.done = true
	showing_previous = false
	_refresh()

func _make_enemy(role: String) -> Dictionary:
	var enemy: Dictionary = ENEMY_TYPES[role].duplicate(true)
	enemy["name"] = role
	enemy["max_hp"] = enemy.hp
	return enemy

func _generate_enemy_group(budget: int, slots: int, stream: RandomNumberGenerator, has_companion := false) -> Array:
	var units: Array = []
	var remaining := budget
	while remaining > 0 and units.size() < slots:
		var candidates: Array = []
		var slots_after: int = slots - units.size() - 1
		for role in ENEMY_TYPES:
			var data: Dictionary = ENEMY_TYPES[role]
			if data.get("boss_only", false) or round_number < data.get("min_round", 1): continue
			var price: int = data.enemy_cost
			if price > remaining or remaining - price > slots_after * 3: continue
			if data.get("requires_party", false) and units.is_empty() and not has_companion and remaining - price < 1: continue
			candidates.append(role)
		if candidates.is_empty(): break
		var role: String = candidates[stream.randi_range(0, candidates.size() - 1)]
		var unit := _make_enemy(role)
		units.append(unit)
		remaining -= unit.enemy_cost
	return units

func _order_enemy_group(units: Array, stream: RandomNumberGenerator) -> Array:
	# Shuffle first so ties and the middle positions are seeded but varied.
	var pool := units.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := stream.randi_range(0, i)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	if pool.size() <= 1: return pool
	var first := 0
	for i in range(1, pool.size()):
		if pool[i].max_hp > pool[first].max_hp: first = i
	var front: Dictionary = pool.pop_at(first)
	var last := 0
	for i in range(1, pool.size()):
		if pool[i].attack > pool[last].attack: last = i
	var rear: Dictionary = pool.pop_at(last)
	return [front] + pool + [rear]

func _append_enemy_party(units: Array, stream: RandomNumberGenerator) -> void:
	var initial_lane := stream.randi_range(0, lanes.size() - 1)
	parties.append({"lane":initial_lane, "start_lane":initial_lane, "route":_make_party_route(initial_lane, stream), "units":units, "pos":-1, "done":false})

func _generate_parties() -> void:
	parties.clear()
	var encounter_rng := _seeded_rng("enemy", round_number)
	var budget: int = ENEMY_BUDGETS[clampi(round_number, 1, 20) - 1]
	if BOSS_PARTIES.has(round_number):
		var choices: Array = BOSS_PARTIES[round_number]
		var names: Array = choices[encounter_rng.randi_range(0, choices.size() - 1)]
		var boss_units: Array = []
		for role in names: boss_units.append(_make_enemy(role))
		_append_enemy_party(boss_units, encounter_rng)
	elif round_number % 5 == 0:
		# 10/20 boss parties are placeholders until the user defines them.
		var boss := {"name":"보스", "hp":24 + round_number * 2, "max_hp":24 + round_number * 2, "attack":5 + int(round_number / 5), "enemy_cost":4, "description":"임시 보스"}
		var units := [boss]
		units.append_array(_generate_enemy_group(mini(budget - 4, 9), 3, encounter_rng, true))
		_append_enemy_party(_order_enemy_group(units, encounter_rng), encounter_rng)
	else:
		var remaining := budget
		while remaining > 0 and parties.size() < 3:
			var parties_after: int = 2 - parties.size()
			var minimum := maxi(1, remaining - parties_after * 12)
			var maximum := mini(remaining, 12)
			var party_budget := encounter_rng.randi_range(minimum, maximum)
			var units := _generate_enemy_group(party_budget, 4, encounter_rng)
			if units.is_empty(): break
			var spent := 0
			for unit in units: spent += unit.enemy_cost
			remaining -= spent
			_append_enemy_party(_order_enemy_group(units, encounter_rng), encounter_rng)
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
	if pending_skill_discards > 0:
		var discarded: Dictionary = hand.pop_at(index)
		discard_pile.append(discarded)
		pending_skill_discards -= 1
		_log("유연한 사고: %s 버림" % discarded.name)
		_refresh()
		return
	if card_defs[hand[index].name].type == "skill":
		_play_skill(index)
		return
	if _unique_in_play(hand[index].name):
		_log("#고유: %s이(가) 이미 배치 또는 휴식 중입니다." % hand[index].name)
		return
	moving_soldier.clear()
	selected_order.clear()
	mode = "card"
	selected_card = index
	_refresh()

func _play_skill(index: int) -> void:
	if phase != "준비" or index < 0 or index >= hand.size(): return
	var card: Dictionary = hand[index]
	var data: Dictionary = card_defs[card.name]
	if data.type != "skill": return
	if data.get("draw", 0) <= 0 and data.get("toxins", 0) <= 0:
		_log("%s: 아직 사용할 수 없는 스킬 효과입니다." % card.name)
		return
	if cost < data.cost:
		_log("코스트가 부족합니다.")
		return
	moving_soldier.clear()
	selected_order.clear()
	selected_card = -1
	mode = "card"
	hand.remove_at(index)
	cost -= data.cost
	cards_used += 1
	var hand_before := hand.size()
	_draw_hand(data.get("draw", 0))
	discard_pile.append(card)
	if data.get("toxins", 0) > 0:
		toxin_power += data.toxins
		_log("%s 사용: 이번 웨이브 모든 유닛에게 #중독%d" % [card.name, data.toxins])
	else:
		_log("%s 사용: 카드 %d장 드로우" % [card.name, hand.size() - hand_before])
	pending_skill_discards = mini(data.get("discard", 0), hand.size())
	if pending_skill_discards > 0: _log("손패에서 버릴 카드 %d장을 선택하세요." % pending_skill_discards)
	_refresh()

func _select_party(index: int) -> void:
	selected_party = index
	showing_previous = false
	_refresh()

func _select_previous_party(index: int) -> void:
	if index < 0 or index >= previous_parties.size(): return
	selected_previous_party = index
	showing_previous = true
	_refresh()

func _show_current_party() -> void:
	showing_previous = false
	_refresh()

func _move_trap_order(lane: int, slot: int, index: int, direction: int) -> void:
	if phase != "준비" or mode != "trap_order": return
	var traps: Array = lanes[lane].traps[slot]
	var target := index + direction
	if index < 0 or index >= traps.size() or target < 0 or target >= traps.size(): return
	var trap: Dictionary = traps.pop_at(index)
	traps.insert(target, trap)
	_log("%s 함정 발동 순서 변경" % trap.name)
	_refresh()

func _soldier_pressed(lane: int, slot: int, index: int) -> void:
	if phase != "준비" or mode not in ["move", "rest", "order", "remove"]: return
	var soldiers: Array = lanes[lane].rooms[slot]
	if index < 0 or index >= soldiers.size(): return
	var soldier: Dictionary = soldiers[index]
	if mode == "remove":
		_remove_soldier(lane, slot, index)
		return
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
		reserves.append({"soldier":soldier, "ready_round":round_number + 1, "healed":false, "origin_lane":lane, "origin_slot":slot})
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

func _remove_soldier(lane: int, slot: int, index: int) -> void:
	if phase != "준비" or mode != "remove": return
	var soldiers: Array = lanes[lane].rooms[slot]
	if index < 0 or index >= soldiers.size(): return
	var soldier: Dictionary = soldiers.pop_at(index)
	if soldier.placed_round == round_number:
		cost += soldier.get("paid_cost", card_defs[soldier.name].cost)
		discard_pile.erase(soldier.card)
		hand.append(soldier.card)
		cards_used -= 1
		_log("%s 배치 취소: 카드와 코스트 반환" % soldier.name)
	else:
		_log("%s 제거: 병사 개체만 사라지고 카드는 덱에 유지됩니다." % soldier.name)
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
		var changed_room := true
		if moving_soldier.source == "reserve":
			changed_room = entry.get("origin_lane", lane) != lane or entry.get("origin_slot", slot) != slot
		var move_cost := 1 if soldier.placed_round < round_number and changed_room and not card_defs[soldier.name].get("versatile", false) else 0
		if cost < move_cost:
			_log("이전 라운드 병사를 다른 방으로 옮기려면 코스트 1이 필요합니다.")
			return
		cost -= move_cost
		source.pop_at(moving_soldier.index)
		if moving_soldier.source == "reserve": soldier.placed_round = round_number - 1
		_put_soldier(placements, soldier)
		moving_soldier.clear()
		_log("%s 이동: 코스트 %d · 체력 %d/%d" % [soldier.name, move_cost, soldier.hp, soldier.max_hp])
	elif mode == "rest":
		_log("방 아래의 병사 버튼을 선택하면 휴식시킬 수 있습니다.")
	elif mode == "order":
		_log("지도 아래의 병사 버튼을 선택해 순서를 바꾸세요.")
	elif mode == "trap_order":
		_log("지도 아래에서 함정의 화살표 버튼으로 순서를 바꾸세요.")
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
			_log("지도 아래에서 제거할 기존 병사를 직접 선택하세요.")
			return
		_remove_soldier(lane, slot, target_index)
		return
	elif mode == "rearm":
		if is_room or placements.is_empty(): return
		# Rearm the first inactive trap on this tile; repeat for other slots.
		for trap in placements:
			if not trap.active and card_defs[trap.name].get("consumable", false):
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
		if data.type == "skill":
			_log("스킬 카드는 손패에서 클릭해 사용하세요.")
			return
		if _unique_in_play(card.name):
			_log("#고유: 같은 병사를 중복 배치할 수 없습니다.")
			return
		if (data.type == "soldier") != is_room:
			_log("병사는 방에, 함정은 통로에 배치합니다.")
			return
		var placement_cost := _card_cost(card.name)
		if cost < placement_cost:
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
		var placed := {"name":card.name, "card":card, "placed_round":round_number, "paid_cost":placement_cost}
		if is_room:
			var stats := _soldier_stats(card.name)
			placed["hp"] = stats.hp
			placed["max_hp"] = stats.hp
		else:
			placed["active"] = true
			placed["hits"] = 0
		if is_room: _put_soldier(placements, placed)
		else: placements.append(placed)
		cost -= placement_cost
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
	var displayed_round := round_number + 1 if phase == "이벤트" else round_number
	var displayed_phase := "대기 · 이벤트" if phase == "이벤트" else phase
	summary.text = "%d / 20 라운드   |   %s   |   코스트 %d / %d   |   골드 %d   |   드로우 %d장 · 버린 더미 %d장" % [displayed_round, displayed_phase, cost, max_cost, gold, draw_pile.size(), discard_pile.size()]
	if madness_relic: summary.text += "   |   유물: 광기의 집념"
	if dragon_pendant: summary.text += "   |   유물: 용족의 팬던트"
	if draw_penalty > 0: summary.text += "   |   턴 드로우 %d장" % maxi(0, 5 - draw_penalty)
	var instructions := {"card":"손패 선택 → 칸 클릭", "remove":"아래 병사·함정 선택: 기존 제거 / 새 배치는 환급", "move":"병사 선택 → 이동할 방 클릭 · 기존 병사는 코스트 1", "order":"병사 선택 → 같은 방의 원하는 순서 선택", "rest":"병사 선택 → 한 웨이브 휴식", "rearm":"재장전 모드: 비활성 함정 클릭", "trap_order":"함정 순서: 아래 화살표로 조정 · 적 2명 이상이면 선두 함정 우선"}
	status_label.text = "%s   |   속도 %s   |   방 정원 4명 · 소모성 재장전 발동당 5G · 휴식 시 최대 체력의 30%% 회복" % [instructions[mode], "빠름" if speed < 0.4 else "보통"]
	if pending_skill_discards > 0: status_label.text = "손패에서 버릴 카드 %d장을 선택하세요" % pending_skill_discards
	start_button.disabled = phase != "준비" or pending_skill_discards > 0
	_clear(party_box)
	if phase in ["이벤트", "카드 보상", "보스 보상"]:
		party_box.add_child(_label("다음 라운드 준비 시 적 정보가 표시됩니다.", 16))
	for i in range(0 if phase in ["이벤트", "카드 보상", "보스 보상"] else parties.size()):
		var party: Dictionary = parties[i]
		var descriptions: Array[String] = []
		for unit in party.units:
			var detail: String = " · " + unit.description if unit.has("description") else ""
			descriptions.append("%s HP%d 공격%d%s" % [unit.name, unit.hp, unit.attack, detail])
		var location := "처치" if party.done else "입구 대기"
		if not party.done and party.pos >= MAP_STAGES.size(): location = "코어 도달"
		if not party.done and party.pos >= 0 and party.pos < MAP_STAGES.size():
			var stage: Dictionary = _map_stage(party.lane, party.pos)
			location = "이동 중" if stage.type == "path" else "%s %d" % ["통로" if stage.type == "trap" else "방", stage.slot + 1]
		var label_value := "%s파티 %d → %s 경로 · %s | %s" % ["▶ " if i == selected_party else "", i + 1, _lane_name(party.lane), location, " / ".join(descriptions)]
		party_box.add_child(_button(label_value, _select_party.bind(i)))
	_refresh_enemy_details()
	_refresh_deck_view()
	_clear(board_box)
	var map_view = preload("res://map_art.gd").new()
	map_view.game = self
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_child(map_view)
	if mode in ["move", "rest", "order", "remove"]:
		for lane in range(lanes.size()):
			for slot in range(lanes[lane].rooms.size()):
				if lanes[lane].rooms[slot].is_empty(): continue
				var unit_row := HBoxContainer.new()
				board_box.add_child(unit_row)
				var unit_label := _label("%s 방%d 병사:" % [_lane_name(lane), slot + 1])
				unit_label.custom_minimum_size.x = 125
				unit_row.add_child(unit_label)
				for i in range(lanes[lane].rooms[slot].size()):
					var soldier: Dictionary = lanes[lane].rooms[slot][i]
					var picked: bool = mode == "order" and not selected_order.is_empty() and selected_order.lane == lane and selected_order.slot == slot and selected_order.index == i
					var removal_note := ("\n새 배치 취소" if soldier.placed_round == round_number else "\n기존 병사 제거") if mode == "remove" else ""
					var soldier_button := _button("%s방%d · %d번\n%s HP%d/%d%s" % ["▶ " if picked else "", slot + 1, i + 1, soldier.name, soldier.hp, soldier.max_hp, removal_note], _soldier_pressed.bind(lane, slot, i))
					soldier_button.custom_minimum_size.x = 130
					unit_row.add_child(soldier_button)
	if mode == "remove":
		for lane in range(lanes.size()):
			for slot in range(lanes[lane].traps.size()):
				if lanes[lane].traps[slot].is_empty(): continue
				var trap_row := HBoxContainer.new()
				board_box.add_child(trap_row)
				var trap_label := _label("%s 통로%d 함정:" % [_lane_name(lane), slot + 1])
				trap_label.custom_minimum_size.x = 125
				trap_row.add_child(trap_label)
				for i in range(lanes[lane].traps[slot].size()):
					var trap: Dictionary = lanes[lane].traps[slot][i]
					var state := "이번 배치·환급" if trap.placed_round == round_number else "기존·환급 없음"
					trap_row.add_child(_button("통로%d %s\n%s" % [slot + 1, trap.name, state], _remove_trap.bind(lane, slot, i)))
	if mode == "trap_order":
		for lane in range(lanes.size()):
			for slot in range(lanes[lane].traps.size()):
				var trap_list: Array = lanes[lane].traps[slot]
				if trap_list.is_empty(): continue
				var trap_row := HBoxContainer.new()
				board_box.add_child(trap_row)
				trap_row.add_child(_label("%s 통로%d:" % [_lane_name(lane), slot + 1], 14))
				for i in range(trap_list.size()):
					var trap: Dictionary = trap_list[i]
					var priority := "선두 우선" if card_defs[trap.name].get("targeting", "front") == "front" else "일반"
					trap_row.add_child(_label("%d. %s (%s)" % [i + 1, trap.name, priority], 14))
					var earlier := _button("←", _move_trap_order.bind(lane, slot, i, -1))
					earlier.custom_minimum_size = Vector2(36, 36)
					earlier.disabled = i == 0
					trap_row.add_child(earlier)
					var later := _button("→", _move_trap_order.bind(lane, slot, i, 1))
					later.custom_minimum_size = Vector2(36, 36)
					later.disabled = i == trap_list.size() - 1
					trap_row.add_child(later)
	_clear(reserves_box)
	reserves_box.add_child(_label("휴식 병사 · 같은 방 무료 / 다른 방 코스트 1", 16))
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
		var text_value: String = "%s%s\n비용 %d\n%s" % ["▶" if selected_card == i else "", card.name, _card_cost(card.name), _display_card_description(card.name)]
		if data.type == "trap": text_value += "\n함정 · " + data.slot
		elif data.type == "soldier": text_value += "\n병사"
		elif data.type == "skill": text_value += "\n스킬 · 클릭해 사용"
		var card_button := _button(text_value, _select_card.bind(i))
		var keyword_help := _display_card_description(card.name) + "\n"
		if data.get("consumable", false): keyword_help += "#소모성: 발동 후 재장전 전까지 다시 발동하지 않습니다.\n"
		if data.get("regen", 0) > 0: keyword_help += "#재생: 매 라운드 준비 시작 시 표시된 만큼 회복합니다.\n"
		if data.get("lifesteal", 0) > 0: keyword_help += "#흡혈: 공격할 때 표시된 만큼 회복합니다.\n"
		if data.get("blur", false): keyword_help += "#흐릿함: 다른 병사가 있으면 단일 공격의 대상이 되지 않습니다.\n"
		if data.get("poison", 0) > 0: keyword_help += "#중독: 대상이 행동할 때 표시된 만큼 피해를 입습니다.\n"
		if data.get("bleed", 0) > 0: keyword_help += "#출혈: 대상이 피해를 입을 때 표시된 만큼 추가 피해를 입습니다.\n"
		if data.get("unique", false): keyword_help += "#고유: 같은 병사가 배치 또는 휴식 중이면 배치할 수 없습니다.\n"
		card_button.tooltip_text = keyword_help
		if pending_skill_discards == 0 and _unique_in_play(card.name):
			card_button.disabled = true
		card_button.custom_minimum_size = Vector2(120, 158)
		if card_icons.has(card.name):
			card_button.icon = card_icons[card.name]
			card_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			card_button.add_theme_constant_override("icon_max_width", 88)
		hand_box.add_child(card_button)

func _toggle_deck_view() -> void:
	showing_deck = not showing_deck
	_refresh()

func _refresh_deck_view() -> void:
	_clear(deck_view_box)
	deck_view_box.visible = showing_deck
	if not showing_deck: return
	deck_view_box.add_child(_label("전체 덱 · 총 %d장 (손패·드로우·버린 더미 포함)" % deck.size(), 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_view_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var counts := {}
	for card in deck:
		counts[card.name] = counts.get(card.name, 0) + 1
	for card_name in counts:
		var data: Dictionary = card_defs[card_name]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(245, 75)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		panel.add_child(_label("%s × %d · 코스트 %d\n%s" % [card_name, counts[card_name], _card_cost(card_name), _display_card_description(card_name)], 14))

func _refresh_enemy_details() -> void:
	_clear(enemy_detail_box)
	enemy_detail_box.add_child(_label("적 파티 정보", 18))
	if phase in ["이벤트", "카드 보상", "보스 보상"]:
		enemy_detail_box.add_child(_label("다음 라운드 준비 시 적 파티가 표시됩니다.", 14))
		return
	if parties.is_empty() or selected_party < 0 or selected_party >= parties.size():
		enemy_detail_box.add_child(_label("표시할 적 파티가 없습니다.", 14))
		return
	var party: Dictionary = parties[selected_party]
	var party_title := "현재 · 파티 %d · %s 경로" % [selected_party + 1, _lane_name(party.lane)]
	enemy_detail_box.add_child(_label(party_title, 14))
	for unit in party.units:
		var row := HBoxContainer.new()
		enemy_detail_box.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = sprite_icons.get("enemy_" + str(unit.name), sprite_icons.get("enemy_보스"))
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var hp: int = maxi(0, unit.hp)
		var max_hp: int = maxi(1, unit.get("max_hp", unit.hp))
		info.add_child(_label("%s · 공격 %d%s" % [unit.name, unit.attack, " · 처치" if hp <= 0 else ""], 14))
		var ability: String = unit.get("description", "선두 병사 공격")
		var ability_label := _label("능력: " + ability, 13)
		ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(ability_label)
		var health_row := HBoxContainer.new()
		info.add_child(health_row)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = max_hp
		bar.value = hp
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("dc716e")
		bar.add_theme_stylebox_override("fill", fill)
		health_row.add_child(bar)
		var hp_label := _label("%d/%d" % [hp, max_hp], 13)
		hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		hp_label.custom_minimum_size.x = 62
		health_row.add_child(hp_label)

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

func _single_target_soldier(soldiers: Array, targeting := "front") -> Dictionary:
	var candidates: Array = []
	for soldier in soldiers:
		if not card_defs[soldier.name].get("blur", false): candidates.append(soldier)
	if candidates.is_empty(): candidates = soldiers
	if targeting == "rear": return candidates.back()
	if targeting == "highest_attack":
		var selected: Dictionary = candidates.front()
		for soldier in candidates:
			if _soldier_stats(soldier.name).attack > _soldier_stats(selected.name).attack: selected = soldier
		return selected
	return candidates.front()

func _single_target_enemy(enemies: Array, targeting: String, taunters: Array) -> Dictionary:
	var forced: Dictionary = {}
	for taunter in taunters:
		if taunter.hp > 0 and enemies.has(taunter): forced = taunter
	if not forced.is_empty(): return forced
	if targeting == "rear": return enemies.back()
	var chosen: Dictionary = enemies.front()
	if targeting == "highest_attack":
		for enemy in enemies:
			if enemy.attack > chosen.attack: chosen = enemy
	return chosen

func _apply_traps(party: Dictionary, slot: int) -> void:
	var traps: Array = lanes[party.lane].traps[slot]
	var ordered: Array = []
	if _live_enemies(party).size() >= 2:
		for trap in traps:
			if card_defs[trap.name].get("targeting", "front") == "front": ordered.append(trap)
		for trap in traps:
			if card_defs[trap.name].get("targeting", "front") != "front": ordered.append(trap)
	else:
		ordered = traps.duplicate()
	for trap in ordered:
		if not trap.active: continue
		var targets := _live_enemies(party)
		if targets.is_empty(): break
		trap.hits += 1
		if card_defs[trap.name].get("consumable", false):
			trap.active = false
		var damage: int = card_defs[trap.name].damage + trap_bonus
		var targeting: String = card_defs[trap.name].get("targeting", "front")
		if targeting == "all":
			for unit in targets: _damage_enemy(unit, damage, trap.name)
		elif targeting == "rear":
			for i in range(maxi(0, targets.size() - 2), targets.size()):
				_damage_enemy(targets[i], damage, trap.name)
		else:
			_damage_enemy(targets.front(), damage, trap.name)

func _clear_enemy_status(enemy: Dictionary) -> void:
	enemy.erase("poison")
	enemy.erase("bleed")
	enemy["attacks_since_cleanse"] = 0
	_log("%s 상태 이상 회복" % enemy.name)

func _soldier_attack(ally: Dictionary, party: Dictionary, taunters: Array) -> void:
	var attack: int = _soldier_stats(ally.name).attack + soldier_bonus
	if card_defs[ally.name].get("area_attack", false):
		for enemy in _live_enemies(party): _soldier_hit_enemy(enemy, attack, ally)
	else:
		var living := _live_enemies(party)
		var target := _single_target_enemy(living, card_defs[ally.name].get("targeting", "front"), taunters)
		_soldier_hit_enemy(target, attack, ally)
	var lifesteal: int = card_defs[ally.name].get("lifesteal", 0)
	if lifesteal > 0:
		var restored: int = mini(lifesteal, ally.max_hp - ally.hp)
		ally.hp += restored
		if restored > 0: _log("%s #흡혈: 체력 %d 회복" % [ally.name, restored])

func _fight(party: Dictionary, slot: int) -> void:
	var soldiers: Array = lanes[party.lane].rooms[slot]
	if soldiers.is_empty() or _live_enemies(party).is_empty(): return
	var fight_token := wave_token
	_log("%s 경로 방 %d 전투 시작" % [_lane_name(party.lane), slot + 1])
	var taunters: Array = []
	var seen_states := {}
	# Snapshot both sides once per cycle; a unit killed before its slot cannot act.
	while not soldiers.is_empty() and not _live_enemies(party).is_empty():
		var state := JSON.stringify([soldiers, party.units, taunters])
		if seen_states.has(state):
			_log("전투 교착: 회복과 공격이 반복되어 전투를 진행할 수 없습니다.")
			if phase == "웨이브":
				phase = "교착"
				battle_notice = "전투 교착 · 새 게임으로 다시 시작"
				_refresh()
			return
		seen_states[state] = true
		var allies := soldiers.duplicate()
		var enemies := _live_enemies(party).duplicate()
		for i in range(maxi(allies.size(), enemies.size())):
			if i < allies.size() and allies[i].hp > 0 and not _live_enemies(party).is_empty():
				var ally: Dictionary = allies[i]
				if ally.get("poison", 0) > 0:
					var poison_damage: int = mini(ally.hp, ally.poison)
					ally.hp -= poison_damage
					_log("%s #중독 %d 피해 (HP %d)" % [ally.name, poison_damage, ally.hp])
					if ally.hp <= 0:
						soldiers.erase(ally)
						if phase == "웨이브": deaths_this_wave += 1
						_log("%s 전사" % ally.name)
				if ally.hp > 0:
					_soldier_attack(ally, party, taunters)
				if phase == "웨이브":
					_refresh()
					await get_tree().create_timer(speed * 0.7).timeout
					if fight_token != wave_token: return
			if i < enemies.size() and enemies[i].hp > 0 and not soldiers.is_empty():
				var enemy: Dictionary = enemies[i]
				if enemy.get("cleanse_every", 0) > 0 and enemy.get("attacks_since_cleanse", 0) >= enemy.cleanse_every:
					_clear_enemy_status(enemy)
				if enemy.get("poison", 0) > 0:
					_damage_enemy(enemy, enemy.poison, "#중독")
					if enemy.hp <= 0: continue
				var interval: int = enemy.get("attack_boost_interval", 0)
				if interval > 0:
					enemy["attack_count"] = enemy.get("attack_count", 0) + 1
					if enemy.attack_count % interval == 0:
						enemy.attack += enemy.get("attack_boost", 0)
						_log("%s 공격력 +%d (공격력 %d)" % [enemy.name, enemy.attack_boost, enemy.attack])
				if enemy.get("heal", false):
					var injured: Dictionary = {}
					for friend in _live_enemies(party):
						if friend.hp < friend.get("max_hp", friend.hp):
							injured = friend
							break
					if injured.is_empty():
						_log("%s 치유: 회복할 아군 없음" % enemy.name)
					else:
						var restored: int = mini(enemy.attack, injured.max_hp - injured.hp)
						injured.hp += restored
						battle_notice = "%s → %s · %d 회복" % [enemy.name, injured.name, restored]
						_log("%s → %s 체력 %d 회복 (HP %d)" % [enemy.name, injured.name, restored, injured.hp])
				else:
					if enemy.get("taunt", false) and not taunters.has(enemy):
						taunters.append(enemy)
						_log("%s #도발: 이 방의 병사가 자신을 우선 공격" % enemy.name)
					if enemy.get("cleanse_every", 0) > 0:
						enemy["attacks_since_cleanse"] = enemy.get("attacks_since_cleanse", 0) + 1
					var targets: Array = soldiers.duplicate() if enemy.get("area_attack", false) else [_single_target_soldier(soldiers, enemy.get("targeting", "front"))]
					for target in targets:
						target.hp = maxi(0, target.hp - enemy.attack)
						battle_notice = "%s → %s · %d 피해" % [enemy.name, target.name, enemy.attack]
						_log("%s → %s %d 피해 (HP %d)" % [enemy.name, target.name, enemy.attack, target.hp])
						if target.hp <= 0:
							soldiers.erase(target)
							if phase == "웨이브": deaths_this_wave += 1
							_log("%s 전사" % target.name)
				if phase == "웨이브":
					_refresh()
					await get_tree().create_timer(speed * 0.7).timeout
					if fight_token != wave_token: return
			if soldiers.is_empty() or _live_enemies(party).is_empty(): break
	if soldiers.is_empty():
		for enemy in _live_enemies(party):
			if enemy.get("cleanse_every", 0) > 0: _clear_enemy_status(enemy)

func _start_wave() -> void:
	if phase != "준비" or pending_skill_discards > 0: return
	if toxin_power > 0:
		for lane in lanes:
			for room in lane.rooms:
				for soldier in room: soldier["poison"] = soldier.get("poison", 0) + toxin_power
		for entry in reserves: entry.soldier["poison"] = entry.soldier.get("poison", 0) + toxin_power
		for party in parties:
			for enemy in _live_enemies(party): enemy["poison"] = enemy.get("poison", 0) + toxin_power
	showing_previous = false
	_discard_hand()
	deaths_this_wave = 0
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
			# Parties merging onto the same cell queue without overlapping.
			var next_pos: int = party.pos + 1
			if next_pos >= MAP_STAGES.size():
				party.pos = next_pos
				_finish(false)
				return
			var next_lane: int = party.route[next_pos] if party.has("route") else party.lane
			var occupied := false
			for j in range(parties.size()):
				if j != p and not parties[j].done and parties[j].lane == next_lane and parties[j].pos == next_pos:
					occupied = true
			if occupied: continue
			party.pos = next_pos
			party.lane = next_lane
			var stage: Dictionary = _map_stage(next_lane, next_pos)
			if stage.type != "path":
				_log("파티 %d: %s 경로 %s %d" % [p + 1, _lane_name(next_lane), "통로" if stage.type == "trap" else "방", stage.slot + 1])
			if stage.type == "trap": _apply_traps(party, stage.slot)
			elif stage.type == "room":
				await _fight(party, stage.slot)
				if my_token != wave_token or phase != "웨이브": return
			if _live_enemies(party).is_empty():
				party.done = true
				_log("파티 %d 격파" % (p + 1))
			_refresh()
			await get_tree().create_timer(speed).timeout
			if my_token != wave_token: return
		if not remaining: break
	_wave_won()

func _wave_won() -> void:
	previous_wave_deaths = deaths_this_wave
	played_rounds = round_number
	previous_parties = parties.duplicate(true)
	previous_round = round_number
	selected_previous_party = clampi(selected_party, 0, maxi(0, previous_parties.size() - 1))
	showing_previous = not previous_parties.is_empty()
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
				if not card_defs[trap.name].get("consumable", false):
					trap.active = true
					trap.hits = 0
	if round_number == 20:
		_finish(true)
		return
	pending_event = round_number % 2 == 0 and round_number < 20
	if round_number % 5 == 0 and round_number < 20:
		_show_rewards()
	else:
		_show_card_reward()

func _show_card_reward() -> void:
	phase = "카드 보상"
	offered_cards.clear()
	var candidates: Array = ROUND_CARD_POOL.filter(func(card_name): return card_defs.has(card_name) and not _starter_only(card_name))
	offered_cards = _sample_options(candidates, 3, _seeded_rng("card_reward", round_number))
	_clear(options_box)
	var reward_heading := _label("라운드 카드 보상\n%d장 중 하나 선택" % offered_cards.size() if not offered_cards.is_empty() else "라운드 카드 보상\n선택할 카드 없음", 16)
	reward_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward_heading.custom_minimum_size.x = 150
	options_box.add_child(reward_heading)
	for card_name in offered_cards:
		var data: Dictionary = card_defs[card_name]
		var reward_button := _button("%s\n코스트 %d\n%s" % [card_name, _card_cost(card_name), _display_card_description(card_name)], _choose_card_reward.bind(card_name))
		reward_button.custom_minimum_size = Vector2(130, 105)
		if card_icons.has(card_name):
			reward_button.icon = card_icons[card_name]
			reward_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reward_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			reward_button.add_theme_constant_override("icon_max_width", 48)
		options_box.add_child(reward_button)
	options_box.add_child(_button("카드 받지 않기", _choose_card_reward.bind("")))
	_log("라운드 보상: 카드 %d장 중 선택하거나 건너뛰세요." % offered_cards.size())
	_refresh()

func _choose_card_reward(card_name: String) -> void:
	if phase != "카드 보상" or (not card_name.is_empty() and not offered_cards.has(card_name)): return
	if card_name.is_empty(): _log("카드 보상을 건너뛰었습니다.")
	else:
		_add_card(card_name)
		_log("카드 보상: %s 획득 · 버린 더미에 추가" % card_name)
	offered_cards.clear()
	_clear(options_box)
	if pending_event: _show_event()
	else: _next_round()

func _show_rewards() -> void:
	phase = "보스 보상"
	_clear(options_box)
	var choices := []
	for reward in REWARDS:
		if not rewards_used.has(reward): choices.append(reward)
	var selected_rewards := _sample_options(choices, 3, _seeded_rng("boss_reward", round_number))
	for reward in selected_rewards:
		options_box.add_child(_button(reward, _choose_reward.bind(reward)))
	_log("보스 격파! 보상 하나를 선택하세요.")
	_refresh()

func _choose_reward(reward: String) -> void:
	if phase != "보스 보상": return
	rewards_used.append(reward)
	match reward:
		"최대 코스트 +1": max_cost += 1
		COST_DRAW_RELIC:
			max_cost += 1
			draw_penalty += 1
		"최대 코스트 +2": max_cost += 2
		"모든 병사 공격력 +2": soldier_bonus += 2
		"모든 병사 공격력 +1": soldier_bonus += 1
		"모든 함정 피해 +2": trap_bonus += 2
		"골드 +12": gold += 12
		"모든 병사 체력 10 회복": _heal_all(10)
		"언데드 골렘 카드 획득": _add_card("언데드 골렘")
	_log("보상 선택: " + reward)
	_clear(options_box)
	_show_card_reward()

func _heal_all(amount: int) -> void:
	for lane in lanes:
		for room in lane.rooms:
			for soldier in room:
				soldier.hp = mini(soldier.max_hp, soldier.hp + amount)
	for entry in reserves:
		var soldier: Dictionary = entry.soldier
		soldier.hp = mini(soldier.max_hp, soldier.hp + amount)

func _eligible_events(event_round: int) -> Array:
	var eligible: Array = []
	for event_name in TEST_EVENTS:
		if not seen_events.has(event_name): eligible.append(event_name)
	if event_round >= 1 and event_round <= 10 and not seen_events.has(WOUNDED_EVENT): eligible.append(WOUNDED_EVENT)
	if event_round >= 1 and event_round <= 20 and not seen_events.has(DRAGON_EVENT): eligible.append(DRAGON_EVENT)
	if event_round >= 1 and event_round <= 10 and not seen_events.has(VAMPIRE_EVENT):
		eligible.append(VAMPIRE_EVENT)
	if event_round >= 10 and event_round <= 20 and not seen_events.has(MADNESS_EVENT):
		eligible.append(MADNESS_EVENT)
	return eligible

func _random_event(eligible: Array, event_rng: RandomNumberGenerator = null):
	if eligible.is_empty(): return null
	var stream: RandomNumberGenerator = event_rng if event_rng else rng
	return eligible[stream.randi_range(0, eligible.size() - 1)]

func _start_card_event() -> void:
	if phase != "이벤트" or current_event not in ["넌 필요없어!!", "그냥 처음에 보여준거로 해주세요", "강화 의식", DRAGON_EVENT]: return
	if current_event == DRAGON_EVENT and not deck.any(func(card): return card_defs[card.name].get("unique_group", card.name) == "용인전사"):
		_log("덱에 용인전사가 없습니다.")
		return
	if deck.is_empty() or (current_event == "강화 의식" and _research_candidates().is_empty()):
		_log("덱에 선택할 카드가 없습니다.")
		return
	selected_event_card = -1
	_show_card_event_choices()

func _show_card_event_choices() -> void:
	_clear(options_box)
	var panel := VBoxContainer.new()
	options_box.add_child(panel)
	panel.add_child(_label("강화할 병사 카드를 선택하세요" if current_event == "강화 의식" else "덱에서 카드 한 장을 선택하세요", 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for card in deck:
		if current_event == "강화 의식" and card_defs[card.name].type != "soldier": continue
		if current_event == DRAGON_EVENT and card_defs[card.name].get("unique_group", card.name) != "용인전사": continue
		var label := "%s%s · 코스트 %d\n%s" % ["✓ " if card.id == selected_event_card else "", card.name, card_defs[card.name].cost, _display_card_description(card.name)]
		list.add_child(_button(label, _select_event_card.bind(card.id)))
	if selected_event_card >= 0:
		var action := "용인전사 제거 · 드래곤 획득" if current_event == DRAGON_EVENT else ("선택한 카드 제거" if current_event == "넌 필요없어!!" else ("선택한 병사 강화" if current_event == "강화 의식" else "선택한 카드 무작위 변환"))
		panel.add_child(_button(action, _finish_card_event))
	panel.add_child(_button("취소", _cancel_card_event))

func _select_event_card(card_id: int) -> void:
	if phase != "이벤트" or current_event not in ["넌 필요없어!!", "그냥 처음에 보여준거로 해주세요", "강화 의식", DRAGON_EVENT]: return
	if not deck.any(func(card): return card.id == card_id): return
	if current_event == "강화 의식" and not _research_candidates().any(func(card): return card.id == card_id): return
	if current_event == DRAGON_EVENT and not deck.any(func(card): return card.id == card_id and card_defs[card.name].get("unique_group", card.name) == "용인전사"): return
	selected_event_card = card_id
	_show_card_event_choices()

func _cancel_card_event() -> void:
	selected_event_card = -1
	if current_event == DRAGON_EVENT:
		_show_dragon_choices()
		return
	_clear(options_box)
	var action := "카드 한 장 제거" if current_event == "넌 필요없어!!" else ("병사 한 장 선택해 강화 (0G)" if current_event == "강화 의식" else "카드 한 장 무작위 변환")
	options_box.add_child(_button(action, _start_card_event))
	options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))

func _card_transform_candidates(old_name: String) -> Array:
	return card_defs.keys().filter(func(name_value): return name_value != old_name and not _starter_only(name_value) and not card_defs[name_value].get("event_only", false) and card_defs[name_value].type in ["soldier", "trap", "skill"])

func _finish_card_event() -> void:
	if phase != "이벤트" or current_event not in ["넌 필요없어!!", "그냥 처음에 보여준거로 해주세요", "강화 의식", DRAGON_EVENT]: return
	var selected: Array = deck.filter(func(card): return card.id == selected_event_card)
	if selected.size() != 1: return
	var card: Dictionary = selected[0]
	var old_name: String = card.name
	if current_event == DRAGON_EVENT:
		if card_defs[card.name].get("unique_group", card.name) != "용인전사": return
		deck.erase(card)
		hand.erase(card)
		draw_pile.erase(card)
		discard_pile.erase(card)
		_add_card("드래곤")
		_log("용족의 비술: 용인전사 제거 · 드래곤 획득")
	elif current_event == "강화 의식":
		if not _apply_ritual(card.id): return
	elif current_event == "넌 필요없어!!":
		deck.erase(card)
		hand.erase(card)
		draw_pile.erase(card)
		discard_pile.erase(card)
		_log("카드 제거: %s" % old_name)
	else:
		var choices := _card_transform_candidates(old_name)
		if choices.is_empty():
			_log("변환할 카드 후보가 없습니다.")
			return
		card.name = choices[rng.randi_range(0, choices.size() - 1)]
		_log("카드 변환: %s → %s" % [old_name, card.name])
	selected_event_card = -1
	_clear(options_box)
	_next_round()

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
		var label := "%s%s · 코스트 %d\n%s" % ["✓ " if selected else "", card.name, data.cost, _display_card_description(card.name)]
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
	if a.get("versatile", false) or b.get("versatile", false): result["versatile"] = true
	if a.get("front_only", false) or b.get("front_only", false): result["front_only"] = true
	if a.get("blur", false) or b.get("blur", false): result["blur"] = true
	if a.get("area_attack", false) or b.get("area_attack", false): result["area_attack"] = true
	if a.get("death_discount", false) or b.get("death_discount", false): result["death_discount"] = true
	var targets := [a.get("targeting", "front"), b.get("targeting", "front")]
	if "highest_attack" in targets: result["targeting"] = "highest_attack"
	elif "rear" in targets: result["targeting"] = "rear"
	var description := "HP %d · 공격 %d" % [result.hp, result.attack]
	if result.get("regen", 0) > 0: description += "\n#재생%d" % result.regen
	if result.get("lifesteal", 0) > 0: description += " #흡혈%d" % result.lifesteal
	if result.get("blur", false): description += " #흐릿함"
	if result.get("poison", 0) > 0: description += " #중독%d" % result.poison
	if result.get("bleed", 0) > 0: description += " #출혈%d" % result.bleed
	if result.get("front_only", false): description += " 선두 고정"
	if result.get("versatile", false): description += " #만능 · 방 이동 무료"
	if result.get("area_attack", false): description += "\n적 전체 공격"
	if result.get("targeting", "") == "highest_attack": description += "\n최고 공격력 적 공격"
	elif result.get("targeting", "") == "rear": description += "\n후열 적 공격"
	if result.get("death_discount", false): description += "\n직전 아군 전사당 비용 -1"
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

func _apply_ritual(card_id: int) -> bool:
	var candidates := _research_candidates()
	var selected: Array = candidates.filter(func(card): return card.id == card_id)
	if selected.size() != 1:
		_log("덱에 강화할 병사 카드가 없습니다.")
		return false
	var card: Dictionary = selected[0]
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

func _show_dragon_choices() -> void:
	_clear(options_box)
	options_box.add_child(_label("용족이 거래를 제안합니다. 동족이 있다면 도와줄지도 모릅니다.", 15))
	options_box.add_child(_button("용인전사를 드래곤으로 교환", _start_card_event))
	options_box.add_child(_button("용족의 팬던트 획득 (50G)", _choose_event.bind("pendant")))
	options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))

func _show_event() -> void:
	var eligible := _eligible_events(round_number + 1)
	pending_event = false
	if eligible.is_empty():
		_log("등장 가능한 시험 이벤트가 없어 다음 라운드로 진행합니다.")
		_next_round()
		return
	phase = "이벤트"
	var event_name: String = _random_event(eligible, _seeded_rng("event", round_number + 1))
	seen_events.append(event_name)
	current_event = event_name
	event_index += 1
	_clear(options_box)
	if current_event == WOUNDED_EVENT:
		options_box.add_child(_label("상처 입은 모험가가 진짜인지 골드로 시험합니다.", 15))
		options_box.add_child(_button("50G 미끼 · 50% 모험가 획득", _choose_event.bind("bait")))
		options_box.add_child(_button("처치하고 30G 획득", _choose_event.bind("kill")))
	elif current_event == DRAGON_EVENT:
		_show_dragon_choices()
	elif current_event == VAMPIRE_EVENT:
		options_box.add_child(_button("녹티스 카드 영입 (30G · 임시)", _choose_event.bind("noctis")))
		options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))
	else:
		match current_event:
			"가능성 연구": options_box.add_child(_button("병사 카드 2장 합성 (70G)", _start_research))
			"강화 의식": options_box.add_child(_button("병사 한 장 선택해 강화 (0G)", _choose_event.bind("ritual")))
			"넌 필요없어!!": options_box.add_child(_button("카드 한 장 제거", _start_card_event))
			"그냥 처음에 보여준거로 해주세요": options_box.add_child(_button("카드 한 장 무작위 변환", _start_card_event))
			MADNESS_EVENT: options_box.add_child(_button("광기의 집념 획득\n병사 체력 절반 · 줄어든 체력의 절반만큼 공격력 증가", _choose_event.bind("madness")))
		options_box.add_child(_button("돌아가기", _choose_event.bind("leave")))
	_log("%d라운드 대기 이벤트: %s · 선택지 하나를 고르세요." % [round_number + 1, event_name])
	_refresh()

func _choose_event(choice: String) -> void:
	if phase != "이벤트": return
	if current_event == WOUNDED_EVENT and choice not in ["bait", "kill"]: return
	if current_event == DRAGON_EVENT and choice not in ["pendant", "leave"]: return
	if current_event == VAMPIRE_EVENT and choice not in ["noctis", "leave"]: return
	if current_event not in [VAMPIRE_EVENT, WOUNDED_EVENT, DRAGON_EVENT]:
		var allowed := {"강화 의식":"ritual", MADNESS_EVENT:"madness"}
		if choice != "leave" and choice != allowed.get(current_event, ""): return
	if choice == "bait" and gold < 50:
		_log("골드가 부족합니다. 미끼에는 50G가 필요합니다.")
		return
	if choice == "pendant" and gold < 50:
		_log("골드가 부족합니다. 용족의 팬던트에는 50G가 필요합니다.")
		return
	if choice == "noctis" and gold < NOCTIS_PRICE:
		_log("골드가 부족합니다. 돌아가기를 선택하세요.")
		return
	if choice == "ritual":
		_start_card_event()
		return
	match choice:
		"noctis":
			gold -= NOCTIS_PRICE
			_add_card("녹티스")
		"madness": _gain_madness_relic()
		"bait":
			gold -= 50
			if _seeded_rng("wounded_outcome", round_number + 1).randi_range(0, 1) == 0:
				_add_card("모험가")
				_log("상처입은 모험가: 시험 성공 · 모험가 카드 획득")
			else: _log("상처입은 모험가: 시험 실패 · 50G 소모")
		"kill": gold += 30
		"pendant":
			gold -= 50
			dragon_pendant = true
	_log("이벤트 선택: " + {"noctis":"녹티스 카드 획득", "ritual":"강화 의식", "madness":"광기의 집념 획득", "bait":"50G 미끼 사용", "kill":"30G 획득", "pendant":"용족의 팬던트 획득", "leave":"돌아가기"}[choice])
	_clear(options_box)
	_next_round()

func _next_round() -> void:
	round_number += 1
	_prepare_round()
	_log("%d라운드 준비. 발동한 #소모성 함정은 골드로 재장전하세요." % round_number)

func _finish(won: bool) -> void:
	if not won:
		previous_parties = parties.duplicate(true)
		previous_round = round_number
		selected_previous_party = clampi(selected_party, 0, maxi(0, previous_parties.size() - 1))
		showing_previous = not previous_parties.is_empty()
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
