extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game(42)
	# Bait costs 10, on both success and failure, and rejects insufficient gold.
	game.phase = "이벤트"
	game.current_event = game.WOUNDED_EVENT
	game.gold = 9
	game._choose_event("bait")
	assert(game.phase == "이벤트" and game.gold == 9)
	game.gold = 10
	game._choose_event("bait")
	assert(game.phase == "준비" and game.gold == 0)
	# Ritual pays only on successful confirmation, never on opening or cancel.
	game._new_game(42)
	game.phase = "이벤트"
	game.current_event = "강화 의식"
	game.gold = 29
	game._choose_event("ritual")
	assert(game.phase == "이벤트" and game.gold == 29 and game.selected_event_card == -1)
	game.gold = 30
	game._choose_event("ritual")
	var soldier_card: Dictionary = game.deck.filter(func(card): return game.card_defs[card.name].type == "soldier")[0]
	game._select_event_card(soldier_card.id)
	game._cancel_card_event()
	assert(game.gold == 30)
	game._choose_event("ritual")
	game._select_event_card(soldier_card.id)
	game._finish_card_event()
	assert(game.gold == 0 and game.phase == "준비" and soldier_card.name.contains("강화"))
	# Only a living reloader re-arms adjacent spent consumables, without gold.
	game._new_game(42)
	game._generate_map(10)
	var before := {"name":"낙석", "active":false, "hits":1}
	var after := {"name":"낙석", "active":false, "hits":1}
	var distant := {"name":"낙석", "active":false, "hits":1}
	var connected := {"name":"낙석", "active":false, "hits":1}
	game.map_crossings = [{"after":1, "top":0}]
	game.lanes[0].traps[0].append(before)
	game.lanes[0].traps[1].append(after)
	game.lanes[0].traps[2].append(distant)
	game.lanes[1].traps[1].append(connected)
	var technician := {"name":"코볼트 정비사", "hp":12, "max_hp":12, "placed_round":1}
	game.lanes[0].rooms[0].append(technician)
	var old_gold: int = game.gold
	technician.hp = 0
	game._rearm_adjacent_traps()
	assert(not before.active and not after.active)
	technician.hp = 12
	game._rearm_adjacent_traps()
	assert(before.active and after.active and connected.active and not distant.active and before.hits == 0 and game.gold == old_gold)
	# The rune blocks healing of affected targets and a cleanse removes the status.
	game._new_game(42)
	var rune := {"name":"치유 봉인 룬", "active":true, "hits":0}
	game.lanes[0].traps[0].append(rune)
	var saint = game._make_enemy("성녀")
	saint.hp = 20
	var guard := {"name":"적", "hp":5, "max_hp":20, "attack":1}
	var party := {"lane":0, "units":[saint, guard]}
	game._apply_traps(party, 0)
	assert(saint.heal_blocked and guard.heal_blocked and not rune.active)
	game.card_defs["고블린"].attack = 0
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":1, "max_hp":1})
	await game._fight(party, 0)
	assert(saint.hp == 20 and guard.hp == 5)
	game._clear_enemy_status(saint)
	assert(not saint.has("heal_blocked"))
	# The new enemy targets the two rear defenders.
	game._new_game(42)
	var allies := [{"name":"고블린", "hp":20, "max_hp":20}, {"name":"고블린", "hp":20, "max_hp":20}, {"name":"고블린", "hp":20, "max_hp":20}]
	game.lanes[0].rooms[0].append_array(allies)
	var archer = game._make_enemy("그림자 사수")
	archer.hp = 6
	await game._fight({"lane":0, "units":[archer]}, 0)
	assert(allies[0].hp == 20 and allies[1].hp == 12 and allies[2].hp == 12)
	# Early events can appear only at the selected 2/4 round slot, with high probability.
	var slot_counts := {2:0, 4:0}
	var early_count := 0
	var kinds := {}
	for seed_value in range(200):
		game._new_game(seed_value)
		var trigger: int = game.early_event_after
		slot_counts[trigger] += 1
		game.round_number = trigger
		game._show_event()
		if game.current_event in game.EARLY_EVENTS:
			early_count += 1
			kinds[game.current_event] = true
	assert(slot_counts[2] > 0 and slot_counts[4] > 0 and early_count > 130 and early_count < 190 and kinds.size() == 4)
	for seed_value in range(20):
		game._new_game(seed_value)
		game.round_number = 4 if game.early_event_after == 2 else 2
		game._show_event()
		assert(game.current_event not in game.EARLY_EVENTS)
	# Chosen card replaces a normal draw without changing deck size or duplicating cards.
	game._new_game(42)
	game._discard_hand()
	game.round_number = 2
	game.phase = "이벤트"
	game.current_event = "맞춤 준비"
	var chosen: Dictionary = game.deck[0]
	game._choose_event("early_choose")
	game._select_event_card(chosen.id)
	game._finish_card_event()
	assert(game.phase == "준비" and game.round_number == 3 and game.hand.has(chosen) and game.hand.size() == 5 and game.deck.size() == 8)
	assert(game.hand.size() + game.draw_pile.size() + game.discard_pile.size() == game.deck.size())
	# Two extra draws occur in the next preparation, once.
	game._new_game(42)
	game._discard_hand()
	game.phase = "이벤트"
	game.current_event = "작전 회의"
	game._choose_event("early_draw")
	assert(game.hand.size() == 7 and game.next_bonus_draw == 0)
	print("CHECK PASSED: prices, support, anti-heal, rear pressure and early events")
	quit()
