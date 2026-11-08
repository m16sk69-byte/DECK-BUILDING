extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func capture_run(game: Control, seed_value: int, disturb_rng: bool) -> Dictionary:
	game._new_game(seed_value)
	var output := {
		"map": JSON.stringify({"lanes":game.lanes, "crossings":game.map_crossings}),
		"opening_hand": game.hand.map(func(card): return card.name),
		"enemies": [], "cards": [], "sample_cards": [], "boss_rewards": [], "events": [],
	}
	for round_value in range(1, 21):
		game.round_number = round_value
		if disturb_rng:
			for i in range(round_value + 7): game.rng.randi()
			game._shuffle_draw_pile()
		game._generate_parties()
		output.enemies.append(JSON.stringify(game.parties))
		if round_value < 20:
			game._show_card_reward()
			output.cards.append(game.offered_cards.duplicate())
			output.sample_cards.append(game._sample_options(["A", "B", "C", "D", "E", "F"], 3, game._seeded_rng("card_reward", round_value)))
		if round_value % 5 == 0 and round_value < 20:
			game._show_rewards()
			var rewards: Array = []
			for child in game.options_box.get_children(): rewards.append(child.text)
			output.boss_rewards.append(rewards)
			if not rewards.is_empty(): game.rewards_used.append(rewards[0])
		if round_value % 2 == 0 and round_value < 20:
			var old_count: int = game.event_index
			game._show_event()
			output.events.append(game.current_event if game.event_index > old_count else "후보 없음")
	return output

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://seed-test-%d.json" % Time.get_ticks_usec()
	var first := capture_run(game, 12345678, false)
	await process_frame
	var replay := capture_run(game, 12345678, true)
	assert(first.map == replay.map and first.opening_hand == replay.opening_hand)
	assert(first.enemies == replay.enemies)
	assert(first.cards == replay.cards and first.sample_cards == replay.sample_cards)
	assert(first.boss_rewards == replay.boss_rewards and first.events == replay.events)
	assert(first.enemies.size() == 20 and first.cards.size() == 19 and first.events.size() == 9)
	for choices in first.sample_cards:
		assert(choices.size() == 3 and choices[0] != choices[1] and choices[0] != choices[2] and choices[1] != choices[2])
	await process_frame
	game._new_game(87654321)
	game.round_number = 10
	game._generate_parties()
	assert(JSON.stringify(game.parties) != first.enemies[9])
	# A changed candidate set is still respected, including boss reward non-repetition.
	game.rewards_used = [game.REWARDS[0]]
	game._show_rewards()
	for child in game.options_box.get_children(): assert(child.text != game.REWARDS[0])
	print("CHECK PASSED: seeded maps, enemies, routes, events, card offers and independent random streams")
	quit()
