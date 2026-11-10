extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.CARDS["모험가"].cost == 1 and game.CARDS["모험가"].hp == 15 and game.CARDS["모험가"].attack == 5)
	assert(game.CARDS["모험가"].unique and game.CARDS["모험가"].event_only and game.CARDS["모험가"].versatile)
	assert(not game._card_transform_candidates("오크").has("모험가"))
	assert(game.ROUND_CARD_POOL.has("용인전사") and game.ROUND_CARD_POOL.has("유연한 사고") and game.ROUND_CARD_POOL.has("치명적인 독소"))
	assert(game._eligible_events(9).has(game.WOUNDED_EVENT) and not game._eligible_events(11).has(game.WOUNDED_EVENT))
	assert(game._eligible_events(3).has(game.DRAGON_EVENT) and game._eligible_events(19).has(game.DRAGON_EVENT))
	# Bait consumes 50 gold in both outcomes, and both seeded outcomes exist.
	var outcomes := {}
	for seed_value in range(1, 50):
		game._new_game(seed_value)
		game.round_number = 2
		var roll: int = game._seeded_rng("wounded_outcome", 3).randi_range(0, 1)
		if outcomes.has(roll): continue
		game.phase = "이벤트"
		game.current_event = game.WOUNDED_EVENT
		game.gold = 49
		game._choose_event("bait")
		assert(game.phase == "이벤트" and game.gold == 49)
		game.gold = 50
		game._choose_event("bait")
		assert(game.gold == 0 and game.phase == "준비")
		assert(game.deck.any(func(card): return card.name == "모험가") == (roll == 0))
		outcomes[roll] = true
		if outcomes.size() == 2: break
	assert(outcomes.size() == 2)
	game._new_game(1)
	game.phase = "이벤트"
	game.current_event = game.WOUNDED_EVENT
	game.gold = 0
	game._choose_event("kill")
	assert(game.gold == 30 and game.phase == "준비")
	# Dragon trade removes the selected exact card, not other cards in the deck.
	game._new_game(1)
	game._add_card("용인전사")
	var warrior: Dictionary = game.deck[-1]
	var prior_count: int = game.deck.size()
	game.phase = "이벤트"
	game.current_event = game.DRAGON_EVENT
	game._start_card_event()
	game._select_event_card(warrior.id)
	game._finish_card_event()
	assert(not game.deck.has(warrior) and game.deck.size() == prior_count)
	assert(game.deck.any(func(card): return card.name == "드래곤"))
	game._new_game(1)
	game.phase = "이벤트"
	game.current_event = game.DRAGON_EVENT
	game.gold = 49
	game._choose_event("pendant")
	assert(game.phase == "이벤트" and not game.dragon_pendant and game.gold == 49)
	game.gold = 50
	game._choose_event("pendant")
	assert(game.dragon_pendant and game.gold == 0 and game.phase == "준비")
	for party in game.parties:
		for enemy in party.units: assert(enemy.hp == maxi(0, enemy.max_hp - 4))
	# Versatile movement is free and is retained when fusing without #unique.
	game._new_game(42)
	game.round_number = 2
	var adventurer := {"name":"모험가", "hp":15, "max_hp":15, "placed_round":1}
	game.lanes[0].rooms[0].append(adventurer)
	var before_cost: int = game.cost
	game._set_mode("move")
	game._soldier_pressed(0, 0, 0)
	game._slot_pressed(0, 1, true)
	assert(game.lanes[0].rooms[1].has(adventurer) and game.cost == before_cost)
	game._new_game(42)
	game._add_card("모험가")
	var material_a: Dictionary = game.deck[-1]
	game._add_card("용인전사")
	var material_b: Dictionary = game.deck[-1]
	game.phase = "이벤트"
	game.current_event = "가능성 연구"
	game.gold = 70
	game.research_selected = [material_a.id, material_b.id]
	game._finish_research()
	var fusion: Dictionary = game.card_defs[game.deck[-1].name]
	assert(fusion.versatile and not fusion.get("unique", false))
	# Draw two, require choosing one card, and block starting the wave until chosen.
	game._new_game(42)
	var flexible := {"id":9001, "name":"유연한 사고"}
	var card_a := {"id":9002, "name":"고블린"}
	var card_b := {"id":9003, "name":"오크"}
	game.deck = [flexible, card_a, card_b]
	game.hand = [flexible]
	game.draw_pile = [card_a, card_b]
	game.discard_pile.clear()
	game.cost = 3
	game._select_card(0)
	assert(game.cost == 2 and game.hand.size() == 2 and game.pending_skill_discards == 1)
	assert(game.start_button.disabled and game.discard_pile.has(flexible))
	game._start_wave()
	assert(game.phase == "준비")
	game._select_card(0)
	assert(game.pending_skill_discards == 0 and game.hand.size() == 1 and game.discard_pile.size() == 2)
	# Toxin applies to both sides for the wave; it clears on the next preparation.
	game._new_game(42)
	game.speed = 0.001
	var toxin := {"id":9004, "name":"치명적인 독소"}
	game.hand.append(toxin)
	var ally := {"name":"고블린", "hp":14, "max_hp":14, "placed_round":1}
	game.lanes[0].rooms[0].append(ally)
	var enemy := {"name":"적", "hp":8, "max_hp":8, "attack":0}
	game.parties = [{"lane":0, "route":[0,0,0,0,0,0,0,0], "units":[enemy], "pos":-1, "done":false}]
	game._select_card(game.hand.find(toxin))
	assert(game.toxin_power == 5 and game.cost == 1)
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "카드 보상" and ally.hp == 9 and enemy.hp == 0 and ally.poison == 5)
	game._choose_card_reward("")
	assert(game.phase == "준비" and not ally.has("poison") and game.toxin_power == 0)
	# An ally killed by toxin loses its action and counts as a wave death.
	game._new_game(42)
	game.phase = "웨이브"
	game.speed = 0.001
	var doomed := {"name":"고블린", "hp":5, "max_hp":14, "poison":5}
	var survivor_enemy := {"name":"적", "hp":10, "max_hp":10, "attack":1}
	game.lanes[0].rooms[0].append(doomed)
	await game._fight({"lane":0, "units":[survivor_enemy]}, 0)
	assert(game.lanes[0].rooms[0].is_empty() and survivor_enemy.hp == 10 and game.deaths_this_wave == 1)
	print("CHECK PASSED: new events, movement, trade, relic and skills")
	quit()
