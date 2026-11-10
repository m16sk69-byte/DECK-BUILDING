extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://chaos-test-%d.json" % Time.get_ticks_usec()
	game._new_game(123)
	game.round_number = 10
	game._generate_parties()
	assert(game.parties.size() == 1)
	var bosses: Array = game.parties[0].units
	assert(bosses.map(func(unit): return unit.name) == ["피에 굶주린자", "피를 원하는자"])
	assert(bosses[0].hp == 70 and bosses[0].attack == 15 and bosses[0].inflicts_bleed == 5)
	assert(bosses[1].hp == 40 and bosses[1].attack == 20 and bosses[1].inflicts_bleed == 5 and bosses[1].targeting == "rear")
	# Bleed applies after the first attack and adds damage on later hits.
	game._new_game(123)
	game.card_defs["고블린"].attack = 10
	var front := {"name":"고블린", "hp":100, "max_hp":100}
	game.lanes[0].rooms[0].append(front)
	var boss = game._make_enemy("피에 굶주린자")
	boss.hp = 30
	await game._fight({"lane":0, "units":[boss]}, 0)
	assert(front.hp == 65 and front.bleed == 10)
	game._prepare_round()
	assert(not front.has("bleed"))
	# Rear targeting and bleeding damage from poison use the same rules.
	game._new_game(123)
	var first := {"name":"고블린", "hp":100, "max_hp":100}
	var rear := {"name":"고블린", "hp":100, "max_hp":100}
	game.lanes[0].rooms[0].append_array([first, rear])
	boss = game._make_enemy("피를 원하는자")
	boss.hp = 6
	await game._fight({"lane":0, "units":[boss]}, 0)
	assert(first.hp == 100 and rear.hp == 80 and rear.bleed == 5)
	game._damage_soldier(rear, 2, "#중독", game.lanes[0].rooms[0])
	assert(rear.hp == 73)
	# Leaving has no effect on the deck or relic.
	game._new_game(17)
	var names: Array = game.deck.map(func(card): return card.name)
	game.phase = "이벤트"
	game.current_event = game.CHAOS_EVENT
	game._choose_event("leave")
	assert(not game.chaos_mask and game.deck.map(func(card): return card.name) == names)
	# All cards transform in place, without introducing restricted cards.
	game._new_game(17)
	game._add_card("녹티스")
	game._add_card("모험가")
	var ids: Array = game.deck.map(func(card): return card.id)
	game._discard_hand()
	game.phase = "이벤트"
	game.current_event = game.CHAOS_EVENT
	game._choose_event("chaos")
	assert(game.chaos_mask and game.deck.map(func(card): return card.id) == ids)
	for card in game.deck:
		assert(not game.STARTER_ONLY_CARDS.has(card.name) and card.name not in ["녹티스", "모험가"])
		assert(game.hand.has(card) or game.draw_pile.has(card) or game.discard_pile.has(card))
	for card in game.hand: assert(card.chaos_cost >= 1 and card.chaos_cost <= 3)
	# Every draw rolls per copy; the necromancer discount comes after the roll.
	game._new_game(42)
	game.chaos_mask = true
	var imp := {"id":9000, "name":"임프"}
	var necro := {"id":9001, "name":"사령술사"}
	game.hand.clear()
	game.draw_pile = [imp, necro]
	game.discard_pile.clear()
	game.previous_wave_deaths = 2
	game._draw_hand(2)
	assert(game._card_cost("임프", imp) == imp.chaos_cost and imp.chaos_cost >= 1)
	assert(game._card_cost("사령술사", necro) == maxi(0, necro.chaos_cost - 2))
	var rolls := {}
	for i in range(50):
		game.hand.clear()
		game.draw_pile = [imp]
		game._draw_hand(1)
		rolls[imp.chaos_cost] = true
	assert(rolls.size() == 3)
	# A skill uses its randomized cost, including when the cost exceeds its printed value.
	game._new_game(42)
	game.chaos_mask = true
	var skill := {"id":9003, "name":"유연한 사고", "chaos_cost":3}
	game.hand = [skill]
	game.cost = 2
	game._play_skill(0)
	assert(game.cost == 2 and game.hand.has(skill))
	game.cost = 3
	game._play_skill(0)
	assert(game.cost == 0 and game.discard_pile.has(skill))
	# A new run with the same seed and draws reproduces the same rolls.
	game._new_game(999)
	game.chaos_mask = true
	var first_rolls: Array = []
	for i in range(10): first_rolls.append(game.chaos_rng.randi_range(1, 3))
	game._new_game(999)
	game.chaos_mask = true
	var replay_rolls: Array = []
	for i in range(10): replay_rolls.append(game.chaos_rng.randi_range(1, 3))
	assert(first_rolls == replay_rolls)
	# A placed trap refunds the cost actually paid, not its printed cost.
	game._new_game(42)
	game.chaos_mask = true
	var trap := {"id":9002, "name":"가시", "chaos_cost":3}
	game.hand = [trap]
	game.cost = 3
	game._select_card(0)
	game._slot_pressed(0, 0, false)
	assert(game.cost == 0)
	game._set_mode("remove")
	game._remove_trap(0, 0, 0)
	assert(game.cost == 3 and game.hand.has(trap) and game._card_cost("가시", trap) == 3)
	print("CHECK PASSED: chaos event, per-draw costs, refunds, bosses and bleed")
	quit()
