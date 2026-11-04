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
	assert(game.gold == 30)
	assert(game.card_icons.size() == 10 and game.music_player.stream != null)
	assert(game.CARDS["고블린"].hp == 20 and game.CARDS["고블린"].attack == 5 and game.CARDS["고블린"].cost == 1)
	assert(game.CARDS["고블린 궁수"].hp == 10 and game.CARDS["고블린 궁수"].attack == 8 and game.CARDS["고블린 궁수"].cost == 1)
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
	click.position = Vector2(195 if game.CARDS[selected.name].type == "trap" else 420, 82) * (board.size.x / 1200.0)
	board._gui_input(click)
	assert(game.hand.size() == 4)
	game._set_mode("remove")
	game._slot_pressed(0, 0, game.CARDS[selected.name].type == "soldier")
	assert(game.hand.size() == 5 and game.cost == 5)
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
	assert(game.cost == 5 and tank.hp == 24 and backline.hp == 14)
	game.log_lines.clear()
	game._fight({"lane":0, "units":[{"name":"적", "hp":20, "attack":1}]}, 0)
	assert(game.log_lines[2].begins_with("적 → 고블린"))
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
	assert(game.cost == 4 and game.hand.size() == 4)
	game._set_mode("remove")
	game._slot_pressed(0, 0, true)
	assert(game.cost == 5 and game.hand.size() == 5 and game.lanes[0].rooms[0].is_empty())
	assert(game.deck.size() == 10)
	var enemy_units = []
	for i in range(2): enemy_units.append({"name":"적%d" % (i + 1), "hp":100, "attack":1})
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
	for i in range(4): enemy_units.append({"name":"적%d" % (i + 1), "hp":100, "attack":1})
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
	assert(trap.hits == 2 and test_party.units[0].hp == 92)
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
	var nearly_full = {"name":"궁수", "hp":15, "max_hp":16, "placed_round":1}
	game.reserves.append({"soldier":nearly_full, "ready_round":3, "healed":false})
	game.speed = 0.001
	game.parties = [{"lane":0, "units":[{"name":"적", "hp":1, "attack":1}], "pos":-1, "done":false}]
	game.lanes[0].traps[0][0].active = true
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "이벤트" and game.reserves[0].healed and survivor.hp == 21)
	assert(game.reserves[1].healed and nearly_full.hp == 16)
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
	assert(first_party.units[0].hp == 20 and first_party.units[1].hp == 12 and first_party.units[2].hp == 12)
	assert(not arrows.active and arrows.hits == 1)
	game._apply_traps(second_party, 0)
	assert(second_party.units[0].hp == 20 and arrows.hits == 1)
	game._set_mode("rearm")
	game._slot_pressed(0, 0, false)
	assert(arrows.active and arrows.hits == 0 and game.gold == 25)
	game._apply_traps(second_party, 0)
	assert(second_party.units[0].hp == 12 and not arrows.active)
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
	assert(game.round_number == 2 and game.lanes[0].rooms[0][0].hp == 23)
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
	game.round_number = 10
	assert(game._eligible_events().size() == 5 and game._eligible_events().has(game.VAMPIRE_EVENT))
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
	game._show_event()
	assert(not game._eligible_events().has(game.current_event) and game._eligible_events().size() == 4)
	game.round_number = 12
	assert(not game._eligible_events().has(game.VAMPIRE_EVENT))
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
	# The remaining three temporary events apply their own effects.
	game._new_game()
	game.gold = 10
	var wounded = {"name":"고블린", "hp":10, "max_hp":20, "placed_round":0}
	game.lanes[0].rooms[0].append(wounded)
	for event in [["시험 이벤트 2", "heal"], ["시험 이벤트 3", "card"], ["시험 이벤트 4", "arrow"]]:
		game.phase = "이벤트"
		game.current_event = event[0]
		game._choose_event(event[1])
	assert(game.gold == 6 and wounded.hp == 18)
	assert(game.deck.any(func(card): return card.name == "오크"))
	assert(game.deck.filter(func(card): return card.name == "화살").size() == 2)
	# Research keeps the deck and gold untouched until two distinct cards are confirmed.
	game._new_game()
	game._add_card("언데드 골렘")
	game._add_card("녹티스")
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
	assert(chimera_data.regen == 10 and chimera_data.lifesteal == 3 and chimera_data.unique)
	# A generated card remains deployable with its calculated stats.
	if not game.hand.has(chimera):
		game.draw_pile.erase(chimera)
		game.discard_pile.erase(chimera)
		game.hand.append(chimera)
	game._select_card(game.hand.find(chimera))
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0][0].max_hp == 50)
	var chimera_unit: Dictionary = game.lanes[0].rooms[0][0]
	assert(game._unique_in_play(chimera.name))
	chimera_unit.hp = 30
	game._regenerate_soldiers()
	assert(chimera_unit.hp == 40)
	game._fight({"lane":0, "units":[{"name":"적", "hp":12, "attack":0}]}, 0)
	assert(chimera_unit.hp == 43)
	game._new_game()
	for round_index in range(1, 21):
		assert(game.round_number == round_index)
		game._discard_hand()
		game._wave_won()
		if game.phase == "보스 보상":
			if round_index == 10: assert(game.pending_event)
			game._choose_reward(game.REWARDS.filter(func(r): return not game.rewards_used.has(r))[0])
			if round_index == 10: assert(game.phase == "이벤트")
		if game.phase == "이벤트": game._choose_event("leave")
	assert(game.phase == "클리어" and game.round_number == 20 and game.event_index == 5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.record_path))
	print("CHECK PASSED: deck and discard cycling, trap rearming, regeneration, lifesteal, unique units, front locking, rest and 20-round flow")
	quit()
