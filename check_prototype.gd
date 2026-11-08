extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://prototype-test-%d.json" % Time.get_ticks_usec()
	assert(game.hand.size() == 5)
	assert(game.deck.size() == 10)
	for starter_name in game.STARTER_ONLY_CARDS:
		assert(not game.ROUND_CARD_POOL.has(starter_name))
		assert(not game._card_transform_candidates("오크").has(starter_name))
		var before_starter_add: int = game.deck.size()
		game._add_card(starter_name)
		assert(game.deck.size() == before_starter_add)
	game.card_defs["강화 고블린 시험"] = game.card_defs["고블린"].duplicate(true)
	game.card_defs["강화 고블린 시험"]["unique_group"] = "고블린"
	assert(not game._card_transform_candidates("오크").has("강화 고블린 시험"))
	game._add_card("강화 고블린 시험")
	assert(game.deck.size() == 10)
	game.card_defs.erase("강화 고블린 시험")
	assert(not game.REWARDS.has("덱에 낙석 2장 추가"))
	assert(game.gold == 30)
	assert(game.card_icons.size() == 9 and game.music_player.stream != null)
	assert(game.CARDS["고블린"].hp == 14 and game.CARDS["고블린"].attack == 3 and game.CARDS["고블린"].cost == 1)
	assert(game.CARDS["고블린 궁수"].hp == 8 and game.CARDS["고블린 궁수"].attack == 6 and game.CARDS["고블린 궁수"].cost == 1)
	assert(game.CARDS["오크"].hp == 30 and game.CARDS["오크"].attack == 5 and game.CARDS["오크"].cost == 2 and game.CARDS["오크"].front_only)
	game._toggle_music()
	assert(not game.music_enabled)
	game._toggle_music()
	assert(game.music_enabled)
	# The illustrated board forwards clicks to the existing placement rules.
	var selected = game.hand[0]
	game._select_card(0)
	await process_frame
	var board = game.board_box.get_child(0)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(150 if game.CARDS[selected.name].type == "trap" else 275, board._lane_y(0)) * (board.size.x / 1200.0)
	board._gui_input(click)
	assert(game.hand.size() == 4)
	game._set_mode("remove")
	game._slot_pressed(0, 0, game.CARDS[selected.name].type == "soldier")
	assert(game.hand.size() == 5 and game.cost == 3 and game.max_cost == 3)
	# A spent trap from an earlier round can be removed without an improper refund.
	game._new_game()
	if not game.hand.any(func(card): return game.CARDS[card.name].type == "trap"):
		for i in range(game.draw_pile.size()):
			if game.CARDS[game.draw_pile[i].name].type == "trap":
				var swap_card = game.hand[0]
				game.hand[0] = game.draw_pile[i]
				game.draw_pile[i] = swap_card
				break
	var trap_card_index = -1
	for i in range(game.hand.size()):
		if game.CARDS[game.hand[i].name].type == "trap":
			trap_card_index = i
			break
	assert(trap_card_index >= 0)
	var old_card = game.hand[trap_card_index]
	game._select_card(trap_card_index)
	game._slot_pressed(0, 0, false)
	game.lanes[0].traps[0][0].hits = 1
	game._wave_won()
	game._choose_card_reward("")
	var old_gold = game.gold
	var old_cost = game.cost
	var old_hand_size = game.hand.size()
	var old_deck_size = game.deck.size()
	var old_hand = game.hand.duplicate(true)
	var old_deck = game.deck.duplicate(true)
	game.lanes[0].traps[0].append({"name":"화살", "active":true, "hits":0, "placed_round":1})
	game._set_mode("remove")
	game._remove_trap(0, 0, 0)
	assert(game.lanes[0].traps[0].size() == 1 and game.lanes[0].traps[0][0].name == "화살")
	assert(game.gold == old_gold and game.cost == old_cost and game.hand.size() == old_hand_size and game.deck.size() == old_deck_size)
	assert(game.hand == old_hand and game.deck == old_deck)
	# Holding the same card allows a fresh placement using the normal cost.
	var redraw = -1
	for i in range(game.hand.size()):
		if game.hand[i].id == old_card.id: redraw = i
	if redraw < 0:
		game.hand.pop_back()
		game.hand.append(old_card)
		redraw = game.hand.size() - 1
	game._select_card(redraw)
	game._slot_pressed(1, 0, false)
	assert(game.lanes[1].traps[0].size() == 1 and game.cost == old_cost - game.CARDS[old_card.name].cost and game.gold == old_gold)
	game._new_game()
	var backline = {"name":"마법사", "hp":14, "max_hp":14, "placed_round":1}
	var tank = {"name":"고블린", "hp":24, "max_hp":24, "placed_round":1}
	game.lanes[0].rooms[0].append(backline)
	game.lanes[0].rooms[0].append(tank)
	game._set_mode("order")
	game._soldier_pressed(0, 0, 1)
	game._soldier_pressed(0, 0, 0)
	assert(game.lanes[0].rooms[0][0] == tank and game.lanes[0].rooms[0][1] == backline)
	assert(game.cost == 3 and tank.hp == 24 and backline.hp == 14)
	game.log_lines.clear()
	game._fight({"lane":0, "units":[{"name":"적", "hp":20, "attack":1}]}, 0)
	assert(game.log_lines.any(func(line): return line.begins_with("적 → 고블린")))
	game._new_game()
	if not game.hand.any(func(card): return card.name == "고블린"):
		for i in range(game.draw_pile.size()):
			if game.draw_pile[i].name == "고블린":
				var swap_card = game.hand[0]
				game.hand[0] = game.draw_pile[i]
				game.draw_pile[i] = swap_card
				break
	var original_hand = game.hand.duplicate()
	var index = -1
	for i in range(game.hand.size()):
		if game.hand[i].name == "고블린":
			index = i
			break
	assert(index >= 0)
	game._select_card(index)
	game._slot_pressed(0, 0, true)
	assert(game.cost == 2 and game.hand.size() == 4)
	game._set_mode("remove")
	game._slot_pressed(0, 0, true)
	assert(game.cost == 3 and game.hand.size() == 5 and game.lanes[0].rooms[0].is_empty())
	assert(game.deck.size() == 10)
	var enemy_units = []
	for i in range(2): enemy_units.append({"name":"적%d" % (i + 1), "hp":20, "attack":1})
	var soldiers = game.lanes[0].rooms[0]
	for i in range(4): soldiers.append({"name":"고블린", "hp":100, "max_hp":100})
	game.log_lines.clear()
	game._fight({"lane":0, "units":enemy_units}, 0)
	var log: Array = game.log_lines
	assert(log[1].begins_with("고블린 →"))
	assert(log[2].begins_with("적1 →"))
	assert(log[3].begins_with("고블린 →"))
	assert(log[4].begins_with("적2 →"))
	assert(log[5].begins_with("고블린 →"))
	assert(log[6].begins_with("고블린 →"))
	game._new_game()
	enemy_units = []
	for i in range(4): enemy_units.append({"name":"적%d" % (i + 1), "hp":20, "attack":1})
	soldiers = game.lanes[0].rooms[0]
	for i in range(2): soldiers.append({"name":"고블린", "hp":100, "max_hp":100})
	game.log_lines.clear()
	game._fight({"lane":0, "units":enemy_units}, 0)
	log = game.log_lines
	assert(log[1].begins_with("고블린 →"))
	assert(log[2].begins_with("적1 →"))
	assert(log[3].begins_with("고블린 →"))
	assert(log[4].begins_with("적2 →"))
	assert(log[5].begins_with("적3 →"))
	assert(log[6].begins_with("적4 →"))
	game._new_game()
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":100, "max_hp":100})
	var four_enemies := []
	for i in range(4): four_enemies.append({"name":"상대%d" % (i + 1), "hp":20, "attack":1})
	game.log_lines.clear()
	game._fight({"lane":0, "units":four_enemies}, 0)
	assert(game.log_lines[1].begins_with("고블린 →"))
	for i in range(4): assert(game.log_lines[i + 2].begins_with("상대%d →" % (i + 1)))
	# A unit killed by an earlier opposing action loses its scheduled turn.
	game._new_game()
	game.lanes[0].rooms[0].append_array([{"name":"고블린", "hp":10, "max_hp":10}, {"name":"고블린", "hp":10, "max_hp":10}])
	game.log_lines.clear()
	game._fight({"lane":0, "units":[{"name":"범위 적", "hp":100, "attack":99, "area_attack":true}]}, 0)
	assert(game.log_lines.filter(func(line): return line.begins_with("고블린 →")).size() == 1)
	# Regular enemy stats and the proposed 5th-round boss formation.
	game._new_game()
	assert(game.ENEMY_TYPES["도적"].hp == 10 and game.ENEMY_TYPES["도적"].attack == 8)
	assert(game.ENEMY_TYPES["방패병"].hp == 20 and game.ENEMY_TYPES["방패병"].attack == 2)
	assert(game.ENEMY_TYPES["저격수"].hp == 5 and game.ENEMY_TYPES["저격수"].attack == 15)
	assert(game.ENEMY_BUDGETS == [1, 2, 2, 2, 5, 3, 3, 4, 4, 8, 5, 5, 6, 6, 10, 7, 7, 8, 8, 20])
	for test_round in range(1, 21):
		game.round_number = test_round
		for trial in range(20):
			game._generate_map(1000 + trial)
			game._generate_parties()
			var total_cost := 0
			assert(game.parties.size() >= 1 and game.parties.size() <= 3)
			for party in game.parties:
				assert(party.units.size() >= 1 and party.units.size() <= 4)
				for unit in party.units: total_cost += unit.enemy_cost
			assert(total_cost == game.ENEMY_BUDGETS[test_round - 1])
	game.round_number = 5
	game._generate_parties()
	assert(game.parties.size() == 1)
	var boss_units: Array = game.parties[0].units
	assert(boss_units.map(func(unit): return unit.name) == ["기사", "기사", "동국의 검사"])
	assert(boss_units[0].hp == 24 and boss_units[0].attack == 6)
	assert(boss_units[2].hp == 50 and boss_units[2].attack == 10)
	# Rear and highest-attack targeting respect blur and deterministic front-order ties.
	var front := {"name":"고블린", "hp":20}
	var strong := {"name":"오크", "hp":30}
	var rear := {"name":"고블린 궁수", "hp":10}
	game.card_defs["오크"].attack = 10
	assert(game._single_target_soldier([front, strong, rear], "rear") == rear)
	assert(game._single_target_soldier([front, strong, rear], "highest_attack") == strong)
	game.card_defs["오크"]["blur"] = true
	assert(game._single_target_soldier([front, strong, rear], "highest_attack") == rear)
	game.card_defs["고블린 궁수"]["blur"] = true
	assert(game._single_target_soldier([front, strong, rear], "rear") == front)
	# Exercise the target selection through combat, including the enemy's actual damage.
	game._new_game()
	front = {"name":"고블린", "hp":20, "max_hp":20}
	rear = {"name":"고블린 궁수", "hp":10, "max_hp":10}
	game.lanes[0].rooms[0].append_array([front, rear])
	game._fight({"lane":0, "units":[{"name":"도적", "hp":9, "attack":8, "targeting":"rear"}]}, 0)
	assert(front.hp == 20 and rear.hp == 2)
	game._new_game()
	front = {"name":"고블린", "hp":20, "max_hp":20}
	strong = {"name":"오크", "hp":30, "max_hp":30}
	game.card_defs["고블린"].attack = 4
	game.lanes[0].rooms[0].append_array([front, strong])
	game._fight({"lane":0, "units":[{"name":"저격수", "hp":10, "attack":15, "targeting":"highest_attack"}]}, 0)
	assert(front.hp == 20 and strong.hp == 15)
	# Units defeated before their own slot do not act.
	game._new_game()
	game.lanes[0].rooms[0].append_array([{"name":"고블린", "hp":20, "max_hp":20}, {"name":"고블린", "hp":20, "max_hp":20}])
	game.log_lines.clear()
	game._fight({"lane":0, "units":[{"name":"적", "hp":6, "attack":99}]}, 0)
	assert(game.lanes[0].rooms[0].size() == 1)
	assert(game.log_lines.any(func(line): return line.begins_with("적 →")))
	# The swordsman gains +5 before attacks 2, 4 and 6, retaining the bonus.
	game._new_game()
	game.card_defs["시험 병사"] = game.card_defs["고블린"].duplicate(true)
	game.card_defs["시험 병사"]["attack"] = 3
	var durable := {"name":"시험 병사", "hp":1000, "max_hp":1000}
	var swordsman := {"name":"동국의 검사", "hp":20, "attack":10, "attack_count":0, "attack_boost_interval":2, "attack_boost":5}
	game.lanes[0].rooms[0].append(durable)
	game._fight({"lane":0, "units":[swordsman]}, 0)
	assert(swordsman.attack_count == 6 and swordsman.attack == 25 and durable.hp == 895)
	game._new_game()
	var trap = {"name":"가시", "card":{"name":"가시", "id":999}, "placed_round":1, "active":false, "hits":3}
	game.lanes[0].traps[0].append(trap)
	game.gold = 14
	game.cost = 5
	game._set_mode("rearm")
	game._slot_pressed(0, 0, false)
	assert(not trap.active and trap.hits == 3 and game.gold == 14 and game.cost == 5)
	game.gold = 15
	game._slot_pressed(0, 0, false)
	assert(trap.active and trap.hits == 0 and game.gold == 0 and game.cost == 5)
	var test_party = {"lane":0, "units":[{"name":"적", "hp":100, "attack":1}]}
	game._apply_traps(test_party, 0)
	game._apply_traps(test_party, 0)
	assert(trap.hits == 2 and test_party.units[0].hp == 88)
	trap.active = false
	game.gold = 10
	game._slot_pressed(0, 0, false)
	assert(trap.active and game.gold == 0 and game.cost == 5)
	trap.active = false
	trap.hits = 1
	game.gold = 5
	game._slot_pressed(0, 0, false)
	assert(trap.active and game.gold == 0 and game.cost == 5)
	game._apply_traps(test_party, 0)
	var unused_trap = {"name":"가시", "card":{"name":"가시", "id":998}, "placed_round":1, "active":true, "hits":0}
	var depleted_trap = {"name":"화살", "card":{"name":"화살", "id":997}, "placed_round":1, "active":false, "hits":2}
	game.lanes[1].traps[0].append(unused_trap)
	game.lanes[1].traps[0].append(depleted_trap)
	var before = game.deck.size()
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":13, "max_hp":24, "placed_round":1})
	game._discard_hand()
	game._wave_won()
	game._choose_card_reward("")
	assert(game.round_number == 2 and game.lanes[0].rooms[0][0].hp == 13 and game.deck.size() == before)
	assert(not trap.active and game.hand.size() == 5)
	assert(game.gold == 10 and unused_trap.active and unused_trap.hits == 0)
	assert(not depleted_trap.active and depleted_trap.hits == 2)
	# Move and rest an actual survivor; resting does not heal until a wave ends.
	var survivor = game.lanes[0].rooms[0][0]
	game._set_mode("move")
	game._soldier_pressed(0, 0, 0)
	for i in range(4): game.lanes[1].rooms[0].append({"name":"고블린", "hp":24, "max_hp":24, "placed_round":1})
	game._slot_pressed(1, 0, true)
	assert(game.lanes[0].rooms[0].size() == 1 and game.lanes[1].rooms[0].size() == 4)
	game.lanes[1].rooms[0].clear()
	game._slot_pressed(1, 1, true)
	assert(game.lanes[0].rooms[0].is_empty() and game.lanes[1].rooms[1][0] == survivor)
	assert(game.cost == game.max_cost and survivor.hp == 13 and game.deck.size() == before)
	game._set_mode("rest")
	game._soldier_pressed(1, 1, 0)
	assert(game.lanes[1].rooms[1].is_empty() and game.reserves.size() == 1 and survivor.hp == 13)
	# A pending rest can be cancelled without receiving free healing.
	game._reserve_pressed(0)
	game._slot_pressed(1, 0, true)
	assert(game.reserves.is_empty() and survivor.hp == 13)
	game._set_mode("rest")
	game._soldier_pressed(1, 0, 0)
	var nearly_full = {"name":"마법사", "hp":13, "max_hp":14, "placed_round":1}
	game.reserves.append({"soldier":nearly_full, "ready_round":3, "healed":false})
	game.speed = 0.001
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":1, "attack":1}], "pos":-1, "done":false}]
	game.lanes[0].traps[0][0].active = true
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	game._choose_card_reward("")
	assert(game.phase == "이벤트" and game.reserves[0].healed and survivor.hp == 21)
	assert(game.reserves[1].healed and nearly_full.hp == 14)
	assert(game.lanes[1].rooms[0].is_empty() and game.deck.size() == before)
	game._choose_event("leave")
	assert(game.round_number == 3)
	game._reserve_pressed(0)
	game._slot_pressed(1, 0, true)
	assert(game.reserves.size() == 1 and game.lanes[1].rooms[0][0].hp == 21 and game.cost == game.max_cost)
	# Death removes the field unit, but the card stays in the deck.
	var dead_card = game.deck[0]
	var original_deck_size = game.deck.size()
	var doomed = {"name":"고블린", "hp":1, "max_hp":24, "placed_round":2, "card":dead_card}
	game.lanes[0].rooms[0].append(doomed)
	game._fight({"lane":0, "units":[{"name":"적", "hp":100, "attack":99}]}, 0)
	assert(game.lanes[0].rooms[0].is_empty() and game.deck.size() == original_deck_size and game.deck.has(dead_card))
	# Consumable traps fire once across parties, then work again after rearming.
	game._new_game()
	var arrows = {"name":"화살", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0].append(arrows)
	var first_party = {"lane":0, "units":[{"name":"앞", "hp":20}, {"name":"중간", "hp":20}, {"name":"뒤", "hp":20}]}
	var second_party = {"lane":0, "units":[{"name":"혼자", "hp":20}]}
	game._apply_traps(first_party, 0)
	assert(first_party.units[0].hp == 20 and first_party.units[1].hp == 13 and first_party.units[2].hp == 13)
	assert(not arrows.active and arrows.hits == 1)
	game._apply_traps(second_party, 0)
	assert(second_party.units[0].hp == 20 and arrows.hits == 1)
	game._set_mode("rearm")
	game._slot_pressed(0, 0, false)
	assert(arrows.active and arrows.hits == 0 and game.gold == 25)
	game._apply_traps(second_party, 0)
	assert(second_party.units[0].hp == 13 and not arrows.active)
	var rocks = {"name":"낙석", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[1].append(rocks)
	var rock_party = {"lane":0, "units":[{"name":"앞", "hp":20}, {"name":"뒤", "hp":20}]}
	game._apply_traps(rock_party, 1)
	game._apply_traps(rock_party, 1)
	assert(rock_party.units[0].hp == 12 and rock_party.units[1].hp == 12 and rocks.hits == 1 and not rocks.active)
	# A real wave must finish while showing the individual combat actions.
	game._new_game()
	game.speed = 0.001
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":24, "max_hp":24, "placed_round":1})
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":10, "max_hp":10, "attack":1}], "pos":-1, "done":false}]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	game._choose_card_reward("")
	assert(game.round_number == 2 and game.lanes[0].rooms[0][0].hp == 21)
	# Starting a new game during the animated fight must cancel the old wave.
	game._new_game()
	game.speed = 0.02
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":24, "max_hp":24, "placed_round":1})
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":100, "max_hp":100, "attack":1}], "pos":-1, "done":false}]
	game._start_wave()
	await create_timer(0.06).timeout
	game._new_game()
	await create_timer(0.12).timeout
	assert(game.phase == "준비" and game.round_number == 1 and game.lanes[0].rooms[0].is_empty())
	game.speed = 0.001
	game._new_game()
	game.speed = 0.001
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":100, "attack":1}], "pos":-1, "done":false}]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "패배")
	assert(FileAccess.file_exists(game.record_path))
	# Starting deck, five-card draws and reshuffling only after the draw pile empties.
	game._new_game()
	assert(game.deck.size() == 10 and game.hand.size() == 5 and game.draw_pile.size() == 5 and game.discard_pile.is_empty())
	var counts := {}
	for card in game.deck: counts[card.name] = counts.get(card.name, 0) + 1
	assert(counts == {"가시":3, "화살":1, "낙석":1, "고블린":4, "고블린 궁수":1})
	var next_ids := []
	for card in game.draw_pile: next_ids.append(card.id)
	game._discard_hand()
	game._draw_hand(5)
	assert(game.draw_pile.is_empty() and game.discard_pile.size() == 5)
	for card in game.hand: assert(next_ids.has(card.id))
	game._discard_hand()
	game._draw_hand(5)
	assert(game.hand.size() == 5 and game.draw_pile.size() == 5 and game.discard_pile.is_empty())
	var all_ids := []
	for card in game.hand + game.draw_pile: all_ids.append(card.id)
	all_ids.sort()
	assert(all_ids == [0,1,2,3,4,5,6,7,8,9])
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":100, "attack":1}], "pos":-1, "done":false}]
	game.speed = 1.0
	game._start_wave()
	assert(game.hand.is_empty() and game.discard_pile.size() == 5 and game.draw_pile.size() == 5)
	# Used consumable cards go to the discard pile and a cancelled placement returns the same card.
	game._new_game()
	var arrow_card = {"id":9999, "name":"화살"}
	game.hand.append(arrow_card)
	game._select_card(game.hand.size() - 1)
	game._slot_pressed(0, 0, false)
	assert(game.discard_pile.has(arrow_card) and game.lanes[0].traps[0].size() == 1)
	game._set_mode("remove")
	game._slot_pressed(0, 0, false)
	assert(game.hand.has(arrow_card) and not game.discard_pile.has(arrow_card))
	# Regeneration happens at preparation start for deployed units, capped at max HP.
	game._new_game()
	var golem = {"name":"언데드 골렘", "hp":22, "max_hp":30, "placed_round":1}
	game.lanes[0].rooms[0].append(golem)
	game._prepare_round()
	assert(golem.hp == 30)
	# Orcs take the front and cannot be displaced or share a room with another front-only unit.
	game._new_game()
	game.cost = 10
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":20, "max_hp":20, "placed_round":0})
	game.hand.append({"id":9001, "name":"오크"})
	game._select_card(game.hand.size() - 1)
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0][0].name == "오크")
	game._set_mode("order")
	game._soldier_pressed(0, 0, 1)
	game._soldier_pressed(0, 0, 0)
	assert(game.lanes[0].rooms[0][0].name == "오크")
	game.hand.append({"id":9002, "name":"오크"})
	game._select_card(game.hand.size() - 1)
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0].size() == 2)
	game._slot_pressed(1, 0, true)
	assert(game.lanes[1].rooms[0][0].name == "오크")
	# Unique applies across all rooms and while resting, and no longer blocks after removal.
	game._new_game()
	game.hand.append({"id":9003, "name":"녹티스"})
	game.hand.append({"id":9004, "name":"녹티스"})
	game._select_card(game.hand.size() - 1)
	game._slot_pressed(0, 0, true)
	assert(game._unique_in_play("녹티스"))
	var duplicate_index = game.hand.size() - 1
	assert(game.hand_box.get_child(duplicate_index).disabled)
	game._select_card(duplicate_index)
	game._slot_pressed(1, 0, true)
	assert(game.lanes[1].rooms[0].is_empty())
	game.lanes[0].rooms[0][0].placed_round = 0
	game._set_mode("rest")
	game._soldier_pressed(0, 0, 0)
	assert(game._unique_in_play("녹티스"))
	game.reserves.clear()
	assert(not game._unique_in_play("녹티스"))
	# Lifesteal restores the stated amount on each attack, capped at max HP.
	game._new_game()
	var noctis = {"name":"녹티스", "hp":10, "max_hp":20, "placed_round":1}
	game.lanes[0].rooms[0].append(noctis)
	game._fight({"lane":0, "units":[{"name":"적", "hp":12, "attack":1}]}, 0)
	assert(noctis.hp == 15)
	# Vampire event eligibility, no repeats, and purchase with exact or insufficient funds.
	game._new_game()
	game.round_number = 9
	assert(game._eligible_events(game.round_number).size() == 5 and not game._eligible_events(game.round_number).has(game.MADNESS_EVENT))
	game.round_number = 10
	assert(game._eligible_events(game.round_number).size() == 6 and game._eligible_events(game.round_number).has(game.VAMPIRE_EVENT) and game._eligible_events(game.round_number).has(game.MADNESS_EVENT))
	assert(game._eligible_events(9).has(game.VAMPIRE_EVENT) and not game._eligible_events(9).has(game.MADNESS_EVENT))
	assert(not game._eligible_events(11).has(game.VAMPIRE_EVENT) and game._eligible_events(11).has(game.MADNESS_EVENT))
	# Check selection with the current and larger candidate pools.
	game.rng.seed = 143
	for pool_size in [5, 19, 20]:
		var pool := []
		var sample_counts := []
		for i in range(pool_size):
			pool.append(i)
			sample_counts.append(0)
		for i in range(20000): sample_counts[game._random_event(pool)] += 1
		for count in sample_counts: assert(absf(float(count) - 20000.0 / pool_size) < 20000.0 / pool_size * 0.2)
	assert(game._random_event([]) == null)
	game.round_number = 9
	game._show_event()
	assert(not game._eligible_events(10).has(game.current_event) and game._eligible_events(10).size() == 5)
	assert(game.summary.text.begins_with("10 / 20 라운드   |   대기 · 이벤트"))
	game.round_number = 12
	assert(not game._eligible_events(game.round_number).has(game.VAMPIRE_EVENT))
	game._new_game()
	game.phase = "이벤트"
	game.current_event = game.VAMPIRE_EVENT
	game.gold = 29
	var deck_before_purchase: int = game.deck.size()
	game._choose_event("noctis")
	assert(game.phase == "이벤트" and game.gold == 29 and game.deck.size() == deck_before_purchase)
	game.gold = 30
	game._choose_event("noctis")
	assert(game.gold == 0 and game.deck.size() == deck_before_purchase + 1)
	assert(game.deck.any(func(card): return card.name == "녹티스"))
	# Removing and transforming operate on one selected card and can be cancelled.
	game._new_game()
	game.phase = "이벤트"
	game.current_event = "넌 필요없어!!"
	var selected_for_removal: Dictionary = game.hand[0]
	var size_before_remove: int = game.deck.size()
	game._start_card_event()
	game._select_event_card(selected_for_removal.id)
	game._cancel_card_event()
	assert(game.deck.size() == size_before_remove and game.hand.has(selected_for_removal))
	game._start_card_event()
	game._select_event_card(selected_for_removal.id)
	game._finish_card_event()
	assert(game.deck.size() == size_before_remove - 1 and not game.deck.has(selected_for_removal))
	assert(not game.hand.has(selected_for_removal) and not game.draw_pile.has(selected_for_removal) and not game.discard_pile.has(selected_for_removal))
	game._new_game()
	game.phase = "이벤트"
	game.current_event = "그냥 처음에 보여준거로 해주세요"
	var selected_for_transform: Dictionary = game.deck[0]
	var old_name: String = selected_for_transform.name
	var old_id: int = selected_for_transform.id
	var size_before_transform: int = game.deck.size()
	game.card_defs["시험 키메라"] = game.card_defs["고블린"].duplicate(true)
	assert(game._card_transform_candidates(old_name).has("시험 키메라"))
	assert(not game.CARDS.has("궁수") and not game._card_transform_candidates(old_name).has("궁수"))
	game.card_defs.erase("시험 키메라")
	game._start_card_event()
	game._select_event_card(old_id)
	game._finish_card_event()
	assert(game.deck.size() == size_before_transform and selected_for_transform.id == old_id)
	assert(selected_for_transform.name != old_name and game.CARDS.has(selected_for_transform.name))
	# Madness affects living units and future cards; damaged units never heal when it is gained.
	game._new_game()
	game.round_number = 9
	assert(not game._eligible_events(game.round_number).has(game.MADNESS_EVENT))
	game.round_number = 10
	assert(game._eligible_events(game.round_number).has(game.MADNESS_EVENT))
	var field_soldier := {"name":"고블린", "hp":13, "max_hp":14}
	var resting_soldier := {"name":"고블린 궁수", "hp":3, "max_hp":8}
	game.lanes[0].rooms[0].append(field_soldier)
	game.reserves.append({"soldier":resting_soldier, "ready_round":11, "healed":false})
	game._gain_madness_relic()
	assert(field_soldier.hp == 7 and field_soldier.max_hp == 7)
	assert(resting_soldier.hp == 3 and resting_soldier.max_hp == 4)
	assert(game._soldier_stats("고블린").hp == 7 and game._soldier_stats("고블린").attack == 6)
	assert(game._soldier_stats("오크").hp == 15 and game._soldier_stats("오크").attack == 12)
	game._gain_madness_relic()
	assert(field_soldier.max_hp == 7)
	game.log_lines.clear()
	game._fight({"lane":0, "units":[{"name":"적", "hp":16, "attack":0}]}, 0)
	assert(game.log_lines.any(func(line): return line.begins_with("고블린 → 적 6 피해")))
	game._add_card("고블린", true)
	var new_soldier_card: Dictionary = game.deck[-1]
	game.draw_pile.erase(new_soldier_card)
	game.hand.append(new_soldier_card)
	game._select_card(game.hand.find(new_soldier_card))
	game._slot_pressed(1, 0, true)
	assert(game.lanes[1].rooms[0][0].max_hp == 7)
	game.card_defs["고블린"].hp = 15
	assert(game._soldier_stats("고블린").hp == 8 and game._soldier_stats("고블린").attack == 6)
	# The boss relic changes maximum cost and the next round's draw.
	game._new_game()
	game._discard_hand()
	game.phase = "보스 보상"
	game.pending_event = false
	game._choose_reward(game.COST_DRAW_RELIC)
	game._choose_card_reward("")
	assert(game.max_cost == 4 and game.cost == 4 and game.hand.size() == 4)
	assert(game.rewards_used.has(game.COST_DRAW_RELIC) and game.draw_penalty == 1)
	# Ritual upgrades the selected deck card with a random keyword.
	game._new_game()
	game._add_card("녹티스")
	var unique_card: Dictionary = game.deck[-1]
	game.deck = [unique_card]
	game.phase = "이벤트"
	game.current_event = "강화 의식"
	game.gold = 0
	game._choose_event("ritual")
	assert(game.selected_event_card == -1 and unique_card.name == "녹티스")
	game._select_event_card(unique_card.id)
	game._finish_card_event()
	assert(game.gold == 0 and game.deck.size() == 1 and unique_card.name != "녹티스")
	var upgraded: Dictionary = game.card_defs[unique_card.name]
	assert(upgraded.unique and upgraded.unique_group == "녹티스")
	assert(upgraded.lifesteal == 3)
	assert(upgraded.get("regen", 0) == 5 or upgraded.get("blur", false) or upgraded.get("poison", 0) == 5 or upgraded.get("bleed", 0) == 3)
	assert(game._ritual_keyword_candidates({}).size() == 5)
	assert(not game._ritual_keyword_candidates({"regen":5}).has("regen"))
	var all_keywords := {"regen":5, "lifesteal":2, "blur":true, "poison":5, "bleed":3}
	assert(game._ritual_keyword_candidates(all_keywords).size() == 4 and not game._ritual_keyword_candidates(all_keywords).has("blur"))
	game.lanes[0].rooms[0].append({"name":"녹티스", "hp":20})
	assert(game._unique_in_play(unique_card.name))
	game._new_game()
	var initial_card: Dictionary = game.deck.filter(func(card): return card.name == "고블린")[0]
	var other_card: Dictionary = game.deck.filter(func(card): return card.name == "고블린")[1]
	game.deck = [initial_card, other_card]
	assert(game._apply_ritual(initial_card.id))
	var changed: Array = game.deck.filter(func(card): return card.name != "고블린")
	assert(changed.size() == 1 and changed[0].id == initial_card.id and other_card.name == "고블린")
	assert(not game.card_defs[changed[0].name].get("unique", false))
	game.deck.clear()
	assert(not game._apply_ritual(initial_card.id))
	# A missing keyword is selected first; with all five, only one numeric value increases.
	game._new_game()
	var complete_data := {"regen":5, "lifesteal":2, "blur":true, "poison":5, "bleed":3}
	assert(game._ritual_keyword_candidates({"regen":5, "lifesteal":2, "poison":5, "bleed":3}) == ["blur"])
	game.card_defs["고블린"].merge(complete_data, true)
	var complete_card: Dictionary = game.deck.filter(func(card): return card.name == "고블린")[0]
	game.deck = [complete_card]
	assert(game._apply_ritual(complete_card.id))
	var raised: Dictionary = game.card_defs[complete_card.name]
	var increases := 0
	for keyword in ["regen", "lifesteal", "poison", "bleed"]:
		var delta: int = raised[keyword] - complete_data[keyword]
		assert(delta == 0 or delta == game.RITUAL_KEYWORDS[keyword])
		if delta > 0: increases += 1
	assert(increases == 1 and raised.blur)
	# Blur postpones single-target attacks but does not avoid area attacks.
	game._new_game()
	game.card_defs["흐릿한 병사"] = game.card_defs["고블린"].duplicate(true)
	game.card_defs["흐릿한 병사"]["blur"] = true
	var hidden := {"name":"흐릿한 병사", "hp":10, "max_hp":10}
	var visible := {"name":"고블린", "hp":10, "max_hp":10}
	assert(game._single_target_soldier([hidden, visible]) == visible)
	assert(game._single_target_soldier([hidden]) == hidden)
	game.lanes[0].rooms[0].append_array([hidden, visible])
	game._fight({"lane":0, "units":[{"name":"광역 적", "hp":9, "attack":3, "area_attack":true}]}, 0)
	assert(hidden.hp == 7 and visible.hp == 7)
	# Poison hits before actions; bleed adds damage without recursively triggering itself.
	game._new_game()
	game.card_defs["상태이상 병사"] = game.card_defs["고블린"].duplicate(true)
	game.card_defs["상태이상 병사"]["attack"] = 5
	game.card_defs["상태이상 병사"]["poison"] = 5
	game.card_defs["상태이상 병사"]["bleed"] = 3
	var status_ally := {"name":"상태이상 병사", "hp":20, "max_hp":20}
	var status_enemy := {"name":"적", "hp":20, "attack":1}
	game.lanes[0].rooms[0].append(status_ally)
	game._fight({"lane":0, "units":[status_enemy]}, 0)
	assert(status_enemy.hp == 0 and status_ally.hp == 19)
	assert(status_enemy.poison == 5 and status_enemy.bleed == 3)
	# Repeated applications add both effects; bleeding reacts once to each hit.
	var stacking_enemy := {"name":"적", "hp":100, "attack":1}
	game._soldier_hit_enemy(stacking_enemy, 5, status_ally)
	assert(stacking_enemy.hp == 95 and stacking_enemy.poison == 5 and stacking_enemy.bleed == 3)
	game._soldier_hit_enemy(stacking_enemy, 5, status_ally)
	assert(stacking_enemy.hp == 87 and stacking_enemy.poison == 10 and stacking_enemy.bleed == 6)
	game._damage_enemy(stacking_enemy, stacking_enemy.poison, "#중독")
	assert(stacking_enemy.hp == 71 and stacking_enemy.poison == 10 and stacking_enemy.bleed == 6)
	game._new_game()
	game.card_defs["독 병사"] = game.card_defs["고블린"].duplicate(true)
	game.card_defs["독 병사"]["attack"] = 5
	game.card_defs["독 병사"]["poison"] = 5
	var poison_ally := {"name":"독 병사", "hp":20, "max_hp":20}
	var poison_enemy := {"name":"적", "hp":10, "attack":99}
	game.lanes[0].rooms[0].append(poison_ally)
	game._fight({"lane":0, "units":[poison_enemy]}, 0)
	assert(poison_enemy.hp == 0 and poison_ally.hp == 20)
	# Research keeps the deck and gold untouched until two distinct cards are confirmed.
	game._new_game()
	game._add_card("언데드 골렘")
	game._add_card("녹티스")
	game.card_defs["언데드 골렘"]["poison"] = 5
	game.card_defs["녹티스"]["poison"] = 5
	game.card_defs["녹티스"]["bleed"] = 3
	game.card_defs["녹티스"]["blur"] = true
	var material_a: Dictionary = game.deck[-2]
	var material_b: Dictionary = game.deck[-1]
	game.discard_pile.erase(material_a)
	game.draw_pile.append(material_a)
	game.phase = "이벤트"
	game.current_event = "가능성 연구"
	game.gold = 69
	game._start_research()
	assert(game.research_selected.is_empty())
	game.gold = 70
	var research_size: int = game.deck.size()
	game._start_research()
	game._select_research_card(material_a.id)
	game._select_research_card(material_b.id)
	game._cancel_research()
	assert(game.gold == 70 and game.deck.size() == research_size and game.research_selected.is_empty())
	game._start_research()
	game._select_research_card(material_a.id)
	game._select_research_card(material_b.id)
	game._finish_research()
	assert(game.gold == 0 and game.deck.size() == research_size - 1)
	assert(not game.deck.has(material_a) and not game.draw_pile.has(material_a) and not game.discard_pile.has(material_b))
	var chimera: Dictionary = game.deck[-1]
	var chimera_data: Dictionary = game.card_defs[chimera.name]
	assert(chimera_data.cost == 3 and chimera_data.hp == 50 and chimera_data.attack == 12)
	assert(chimera_data.regen == 10 and chimera_data.lifesteal == 3 and not chimera_data.get("unique", false))
	assert(chimera_data.poison == 10 and chimera_data.bleed == 3 and chimera_data.blur)
	assert(not "#고유" in chimera_data.description)
	# A generated card remains deployable with its calculated stats.
	if not game.hand.has(chimera):
		game.draw_pile.erase(chimera)
		game.discard_pile.erase(chimera)
		game.hand.append(chimera)
	game._select_card(game.hand.find(chimera))
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0][0].max_hp == 50)
	var chimera_unit: Dictionary = game.lanes[0].rooms[0][0]
	assert(not game._unique_in_play(chimera.name))
	chimera_unit.hp = 30
	game._regenerate_soldiers()
	assert(chimera_unit.hp == 40)
	game._fight({"lane":0, "units":[{"name":"적", "hp":12, "attack":0}]}, 0)
	assert(chimera_unit.hp == 43)
	# A second copy of the resulting non-unique chimera can be deployed.
	game._add_card(chimera.name)
	var second_chimera: Dictionary = game.deck[-1]
	game.discard_pile.erase(second_chimera)
	game.hand.append(second_chimera)
	game.cost = game.max_cost
	game._select_card(game.hand.find(second_chimera))
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0].size() == 2)
	# Front-target traps fire before rear/all traps for a multi-unit party.
	game._new_game()
	var rear_trap = {"name":"화살", "active":true, "hits":0, "placed_round":1}
	var front_trap = {"name":"가시", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0] = [rear_trap, front_trap]
	var priority_party = {"lane":0, "units":[{"name":"앞", "hp":6, "max_hp":6, "attack":1}, {"name":"뒤", "hp":15, "max_hp":15, "attack":1}]}
	game.log_lines.clear()
	game._apply_traps(priority_party, 0)
	assert(game.log_lines[0].begins_with("가시 → 앞") and game.log_lines[1].begins_with("화살 → 뒤"))
	assert(priority_party.units[0].hp == 0 and priority_party.units[1].hp == 8)
	# If earlier front traps defeat everyone, the remaining trap stays loaded for free.
	game._new_game()
	var unused_arrow = {"name":"화살", "active":true, "hits":0, "placed_round":1}
	var spike_one = {"name":"가시", "active":true, "hits":0, "placed_round":1}
	var spike_two = {"name":"가시", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0] = [unused_arrow, spike_one, spike_two]
	var doomed_party = {"lane":0, "units":[{"name":"앞", "hp":6, "attack":1}, {"name":"뒤", "hp":6, "attack":1}]}
	game._apply_traps(doomed_party, 0)
	assert(unused_arrow.active and unused_arrow.hits == 0 and spike_one.hits == 1 and spike_two.hits == 1)
	# Player-selected order controls traps of equal priority and all traps against one enemy.
	game._new_game()
	game.card_defs["시험 선두"] = {"type":"trap", "slot":"벽", "targeting":"front", "damage":12}
	var small_trap = {"name":"가시", "active":true, "hits":0, "placed_round":1}
	var large_trap = {"name":"시험 선두", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0] = [small_trap, large_trap]
	game._set_mode("trap_order")
	game._move_trap_order(0, 0, 1, -1)
	assert(game.lanes[0].traps[0][0] == large_trap)
	game._apply_traps({"lane":0, "units":[{"name":"적", "hp":6, "attack":1}]}, 0)
	assert(large_trap.hits == 1 and small_trap.hits == 0)
	# The snapshot survives the transition to the next round, and the chosen reward goes to discard.
	game._new_game()
	game.parties = [{"lane":0, "pos":1, "done":true, "units":[{"name":"도적", "hp":0, "max_hp":10, "attack":8}]}]
	game._wave_won()
	assert(game.phase == "카드 보상" and game.offered_cards == ["오크"] and game.showing_previous)
	assert(game.offered_cards.duplicate().filter(func(name): return name == game.offered_cards[0]).size() == 1)
	assert(not game.offered_cards.has("녹티스") and not game.offered_cards.has("언데드 골렘"))
	var chosen_reward: String = game.offered_cards[0]
	var reward_deck_size = game.deck.size()
	game._choose_card_reward(chosen_reward)
	assert(game.deck.size() == reward_deck_size + 1 and game.discard_pile.any(func(card): return card.name == chosen_reward))
	assert(game.round_number == 2 and game.previous_round == 1 and game.previous_parties[0].units[0].hp == 0)
	game._show_current_party()
	game._select_previous_party(0)
	assert(game.showing_previous and game.enemy_detail_box.get_child_count() >= 4)
	var hp_bar: ProgressBar = game.enemy_detail_box.get_child(3).get_child(1).get_child(1).get_child(0)
	assert(hp_bar.value == 0 and hp_bar.max_value == 10)
	# The complete deck viewer includes cards in the hand, draw pile and discard pile during a reward.
	game._new_game()
	game._discard_hand()
	game._show_card_reward()
	var before_view = game.deck.duplicate(true)
	game._toggle_deck_view()
	assert(game.showing_deck and game.deck_view_box.visible and game.deck_view_box.get_child_count() == 2)
	assert(game.deck_view_box.get_child(0).text.contains("총 10장"))
	assert(game.hand.size() == 0 and game.draw_pile.size() == 5 and game.discard_pile.size() == 5)
	assert(game.deck == before_view and game.phase == "카드 보상")
	game._toggle_deck_view()
	assert(not game.showing_deck and not game.deck_view_box.visible and game.deck == before_view)
	# A data-defined draw skill resolves before entering discard, so it cannot draw itself.
	game._new_game()
	game.card_defs["테스트 드로우"] = {"type":"skill", "cost":1, "draw":2, "description":"카드 2장 드로우"}
	var skill_card := {"id":8001, "name":"테스트 드로우"}
	var draw_card := {"id":8002, "name":"오크"}
	var discard_card := {"id":8003, "name":"언데드 골렘"}
	game.deck = [skill_card, draw_card, discard_card]
	game.hand = [skill_card]
	game.draw_pile = [draw_card]
	game.discard_pile = [discard_card]
	game.cost = 3
	game._select_card(0)
	assert(game.cost == 2 and game.hand.size() == 2 and game.hand.has(draw_card) and game.hand.has(discard_card))
	assert(game.discard_pile == [skill_card] and game.draw_pile.is_empty())
	game.discard_pile.clear()
	game.hand.append(skill_card)
	game.cost = 0
	game._select_card(game.hand.size() - 1)
	assert(game.hand.has(skill_card) and game.cost == 0 and game.discard_pile.is_empty())
	# Empty reward pools remain skippable rather than blocking progress.
	game._new_game()
	game.card_defs.erase("오크")
	game._show_card_reward()
	assert(game.offered_cards.is_empty() and game.phase == "카드 보상")
	game._choose_card_reward("")
	assert(game.phase == "준비" and game.round_number == 2)
	# The event after round 18 belongs to round 19; round 20 has no normal event.
	game._new_game()
	game.round_number = 18
	game._wave_won()
	game._choose_card_reward("")
	assert(game.phase == "이벤트" and game.summary.text.begins_with("19 / 20 라운드   |   대기 · 이벤트"))
	assert(game.party_box.get_child_count() == 1)
	var events_before_twenty: int = game.event_index
	game._choose_event("leave")
	assert(game.phase == "준비" and game.round_number == 19)
	game._wave_won()
	game._choose_card_reward("")
	assert(game.phase == "준비" and game.round_number == 20 and game.event_index == events_before_twenty)
	game._new_game()
	for round_index in range(1, 21):
		assert(game.round_number == round_index)
		game._discard_hand()
		game._wave_won()
		if game.phase == "보스 보상":
			if round_index == 10: assert(game.pending_event)
			game._choose_reward(game.REWARDS.filter(func(r): return not game.rewards_used.has(r))[0])
		if game.phase == "카드 보상":
			assert(game.offered_cards == ["오크"])
			game._choose_card_reward("")
			if round_index == 10: assert(game.phase == "이벤트")
		if game.phase == "이벤트": game._choose_event("leave")
	assert(game.phase == "클리어" and game.round_number == 20 and game.event_index >= 5 and game.event_index <= 6)
	assert(game.offered_cards.is_empty() and game.options_box.get_child_count() == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.record_path))
	print("CHECK PASSED: deck and discard cycling, trap rearming, regeneration, lifesteal, unique units, front locking, rest and 20-round flow")
	quit()
