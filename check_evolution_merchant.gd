extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game(42)
	assert(not game._eligible_events(9).has(game.EVOLUTION_EVENT))
	assert(game._eligible_events(11).has(game.EVOLUTION_EVENT) and game._eligible_events(19).has(game.EVOLUTION_EVENT))
	assert(game._eligible_events(3).has(game.MERCHANT_EVENT) and game._eligible_events(19).has(game.MERCHANT_EVENT))
	assert(not game.ROUND_CARD_POOL.has("생존 본능") and game.CARDS["생존 본능"].event_only)
	# Two complete rounds use two less cost; the relic is awarded on the second win.
	game.round_number = 12
	game.phase = "이벤트"
	game.current_event = game.EVOLUTION_EVENT
	game._choose_event("wisdom")
	assert(game.round_number == 13 and game.cost == 1 and game.evolution_rounds_remaining == 2 and not game.wisdom_relic)
	game._wave_won()
	assert(game.evolution_rounds_remaining == 1 and not game.wisdom_relic)
	game._choose_card_reward("")
	assert(game.round_number == 14 and game.cost == 1)
	game._wave_won()
	assert(game.evolution_rounds_remaining == 0 and game.wisdom_relic and game.max_cost == 4)
	# Skill route grants the card after the same delay.
	game._new_game(42)
	game.round_number = 12
	game.phase = "이벤트"
	game.current_event = game.EVOLUTION_EVENT
	game._choose_event("instinct")
	game._wave_won()
	assert(not game.deck.any(func(card): return card.name == "생존 본능"))
	game._choose_card_reward("")
	game._wave_won()
	assert(game.deck.any(func(card): return card.name == "생존 본능"))
	# Buff only the actual cards in hand; repeat uses stack and survive redraw.
	game._new_game(42)
	game._add_card("생존 본능")
	var skill: Dictionary = game.deck[-1]
	var goblin: Dictionary = game.deck.filter(func(card): return card.name == "고블린")[0]
	var other: Dictionary = game.deck.filter(func(card): return card.name == "고블린")[1]
	game.hand = [skill, goblin]
	game.cost = 3
	game._play_skill(0)
	assert(goblin.hp_bonus == 10 and not other.has("hp_bonus"))
	game.hand = [skill, goblin]
	game._play_skill(0)
	assert(goblin.hp_bonus == 20 and game._soldier_stats(goblin.name, goblin).hp == 34)
	game.hand = [goblin]
	game.cost = 3
	game.selected_card = 0
	game._slot_pressed(0, 0, true)
	assert(game.lanes[0].rooms[0][0].max_hp == 34 and game.discard_pile.has(goblin))
	game.hand.clear()
	game.draw_pile = [goblin]
	game._draw_hand(1)
	assert(game.hand[0].hp_bonus == 20)
	# Repeated purchases remain on screen and never sell an owned relic; no money lost on exhaustion.
	game._new_game(71)
	game.phase = "이벤트"
	game.current_event = game.MERCHANT_EVENT
	game.gold = 300
	for i in range(5):
		game._choose_event("buy_relic")
		assert(game.phase == "이벤트" and game.gold == 300 - (i + 1) * 50)
	assert(game.RELIC_POOL.all(func(relic): return game._has_relic(relic)))
	game._choose_event("buy_relic")
	assert(game.gold == 50)
	var before: int = game.deck.size()
	game._choose_event("buy_card")
	assert(game.phase == "이벤트" and game.gold == 20 and game.deck.size() == before + 1)
	assert(game.ROUND_CARD_POOL.has(game.deck[-1].name))
	game._choose_event("buy_card")
	assert(game.gold == 20 and game.deck.size() == before + 1)
	game._choose_event("leave")
	assert(game.phase == "준비")
	print("CHECK PASSED: evolution timing, persistent stacking and merchant purchases")
	quit()
