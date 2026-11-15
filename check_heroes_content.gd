extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game(42)
	game.round_number = 20
	game._generate_parties()
	assert(game.parties.size() == 1)
	var heroes: Array = game.parties[0].units
	assert(heroes.map(func(unit): return unit.name) == ["전사", "용사", "성녀", "궁수"])
	assert(heroes[0].hp == 100 and heroes[0].attack == 50 and heroes[0].taunt)
	assert(heroes[1].hp == 90 and heroes[1].attack == 60)
	assert(heroes[2].hp == 50 and heroes[2].attack == 30 and heroes[2].heal_all)
	assert(heroes[3].hp == 80 and heroes[3].attack == 70 and heroes[3].targeting == "highest_attack")
	# Heals every living party member, including the saint, without attacking.
	game._new_game(42)
	game.card_defs["고블린"].attack = 0
	var defender := {"name":"고블린", "hp":1, "max_hp":1}
	game.lanes[0].rooms[0].append(defender)
	var saint = game._make_enemy("성녀")
	saint.hp = 10
	var wounded := {"name":"적", "hp":10, "max_hp":100, "attack":1}
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[saint, wounded]}, 0)
	assert(saint.hp == 40 and wounded.hp == 40)
	assert(not game.log_lines.any(func(line): return line.begins_with("성녀 → 고블린")))
	# A fallen instance returns to its room and original position at full HP.
	game._new_game(42)
	var old_front := {"name":"고블린", "hp":14, "max_hp":14, "placed_round":1}
	var skeleton := {"name":"스켈레톤", "hp":10, "max_hp":10, "placed_round":1}
	var old_rear := {"name":"고블린 궁수", "hp":8, "max_hp":8, "placed_round":1}
	var room: Array = game.lanes[0].rooms[0]
	room.append_array([old_front, skeleton, old_rear])
	game.phase = "웨이브"
	game._damage_soldier(skeleton, 10, "적", room)
	assert(room.size() == 2 and game.fallen_revivable.size() == 1 and game.deaths_this_wave == 1)
	game.round_number = 2
	game._prepare_round()
	assert(room.size() == 3 and is_same(room[1], skeleton) and skeleton.hp == skeleton.max_hp and game.fallen_revivable.is_empty())
	# Retry shuffles hand and discard into the draw pile but discards itself after resolution.
	game._new_game(42)
	var retry := {"id":9000, "name":"리트라이"}
	var a := {"id":9001, "name":"고블린"}
	var b := {"id":9002, "name":"오크"}
	var c := {"id":9003, "name":"가시"}
	var d := {"id":9004, "name":"임프"}
	game.hand = [retry, a, b]
	game.discard_pile = [c]
	game.draw_pile = [d]
	game.cost = 3
	game._play_skill(0)
	assert(game.cost == 2 and game.hand.size() == 4 and game.discard_pile == [retry])
	for card in [a, b, c, d]: assert(game.hand.has(card))
	# Loans stack and reduce only the next round's available cost.
	game._new_game(42)
	game.hand = [{"id":9005, "name":"융자신청"}, {"id":9006, "name":"융자신청"}]
	game._play_skill(0)
	game._play_skill(0)
	assert(game.cost == 5 and game.loan_debt == 2)
	game.round_number = 2
	game._prepare_round()
	assert(game.cost == 1 and game.loan_debt == 0)
	game.round_number = 3
	game._prepare_round()
	assert(game.cost == 3)
	# Recycling uses the selected card's current cost, including chaos and discounts.
	game._new_game(42)
	game.chaos_mask = true
	var recycle := {"id":9007, "name":"환경보호자금", "chaos_cost":1}
	var target := {"id":9008, "name":"사령술사", "chaos_cost":3}
	game.previous_wave_deaths = 1
	game.hand = [recycle, target]
	game.cost = 3
	game._play_skill(0)
	assert(game.cost == 2 and game.pending_skill_discards == 1)
	game._select_card(0)
	assert(game.cost == 4 and game.pending_skill_discards == 0 and game.discard_pile.has(target))
	# Event eligibility uses the currently deployed living units after round 6.
	game._new_game(42)
	assert(not game._eligible_events(6).has(game.COUNT_EVENT))
	assert(game._eligible_events(7).has(game.COUNT_EVENT))
	for i in range(4): game.lanes[0].rooms[0].append({"name":"고블린", "hp":14, "max_hp":14})
	assert(not game._eligible_events(7).has(game.COUNT_EVENT))
	game.lanes[0].rooms[0].pop_back()
	assert(game._eligible_events(7).has(game.COUNT_EVENT))
	var event_hits := 0
	for seed_value in range(40):
		game.map_seed = seed_value
		game.round_number = 6
		game.seen_events.clear()
		game._show_event()
		if game.current_event == game.COUNT_EVENT: event_hits += 1
	assert(event_hits > 8 and event_hits < 32)
	game.phase = "준비"
	# Cheer applies equally to units already deployed and newly summoned later.
	game._gain_relic("응원")
	assert(game.lanes[0].rooms[0][0].hp == 24 and game._soldier_stats("고블린").hp == 24)
	game._gain_relic("염원")
	game.round_number = 10
	game._prepare_round()
	assert(game.cost == 4 and game.max_cost == 3)
	game.round_number = 11
	game._prepare_round()
	assert(game.cost == 3)
	# Reinforcement gives two distinct reward screens before the next round.
	game._new_game(42)
	game.round_number = 6
	game.phase = "이벤트"
	game.current_event = game.COUNT_EVENT
	game._choose_event("증원")
	assert(game.phase == "카드 보상" and game.bonus_reward_remaining == 2)
	game._choose_card_reward(game.offered_cards[0])
	assert(game.phase == "카드 보상" and game.bonus_reward_remaining == 1)
	game._choose_card_reward(game.offered_cards[0])
	assert(game.round_number == 7 and game.phase == "준비" and game.bonus_reward_remaining == 0 and game.deck.size() == 10)
	print("CHECK PASSED: hero party, revival, skills, event and three relics")
	quit()
