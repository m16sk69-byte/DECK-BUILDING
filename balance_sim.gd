extends SceneTree

var game
var choice_rng := RandomNumberGenerator.new()
var summary := {"runs":0, "wins":0, "stalemates":0, "rounds":{}, "profiles":{}, "cards":{}, "events":{}, "relics":{}, "soldier_damage":{}, "soldier_actions":{}}

func _initialize() -> void:
	call_deferred("run")

func card_value(card: Dictionary) -> float:
	var data: Dictionary = game.card_defs[card.name]
	if data.type == "soldier":
		return data.hp * 0.5 + data.attack * (4 if data.get("area_attack", false) else 2) + data.get("regen", 0) * 2 + (14 if data.get("revive", false) else 0) - game._card_cost(card.name, card) * 3
	if data.type == "trap": return data.get("damage", 0) * (2 if data.get("targeting", "") in ["all", "front_two", "rear"] else 1) + data.get("poison", 0) * 3 - game._card_cost(card.name, card) * 3
	return 0.0

func prepare(profile: int) -> void:
	var skill_attempts := 0
	while skill_attempts < 8:
		var skill_index := -1
		for i in range(game.hand.size()):
			var card: Dictionary = game.hand[i]
			var data: Dictionary = game.card_defs[card.name]
			if data.type != "skill" or game.cost < game._card_cost(card.name, card): continue
			if data.get("toxins", 0) > 0 and profile == 0: continue
			if data.get("recycle_cost", false) and game.hand.size() < 2: continue
			skill_index = i
			break
		if skill_index < 0: break
		game._select_card(skill_index)
		skill_attempts += 1
		if game.pending_skill_discards > 0 and not game.hand.is_empty():
			var discard_index := 0
			for i in range(1, game.hand.size()):
				if card_value(game.hand[i]) < card_value(game.hand[discard_index]): discard_index = i
			game._select_card(discard_index)
	var planned := []
	for party in game.parties:
		for step in range(game.MAP_STAGES.size()):
			var lane: int = party.route[step]
			var stage: Dictionary = game._map_stage(lane, step)
			if stage.type in ["room", "trap"] and not planned.any(func(item): return item.lane == lane and item.slot == stage.slot and item.type == stage.type):
				planned.append({"lane":lane, "slot":stage.slot, "type":stage.type})
	for item in planned:
		if item.type != "trap": continue
		for trap in game.lanes[item.lane].traps[item.slot]:
			if not trap.active and game.gold >= 5 * maxi(1, trap.hits):
				game.mode = "rearm"
				game._slot_pressed(item.lane, item.slot, false)
	game.mode = "card"
	var attempts := 0
	var rejected := {}
	while attempts < 20:
		attempts += 1
		var best_index := -1
		var best_value := -9999.0
		for i in range(game.hand.size()):
			var card: Dictionary = game.hand[i]
			if rejected.has(card.id): continue
			if game.card_defs[card.name].type == "skill" or game._card_cost(card.name, card) > game.cost: continue
			var value: float = card_value(card) + (choice_rng.randf() * 10 if profile == 1 else 0)
			if value > best_value: best_value = value; best_index = i
		if best_index < 0: break
		var card: Dictionary = game.hand[best_index]
		var is_room: bool = game.card_defs[card.name].type == "soldier"
		var before: int = game.hand.size()
		for item in planned:
			if (item.type == "room") != is_room: continue
			game.selected_card = best_index
			game._slot_pressed(item.lane, item.slot, is_room)
			if game.hand.size() < before: break
		if game.hand.size() == before: rejected[card.id] = true

func pick_reward(profile: int) -> String:
	if game.offered_cards.is_empty(): return ""
	if profile == 1: return game.offered_cards[choice_rng.randi_range(0, game.offered_cards.size() - 1)]
	var best: String = game.offered_cards[0]
	for name_value in game.offered_cards:
		if card_value({"name":name_value}) > card_value({"name":best}): best = name_value
	return best

func decide_event(profile: int) -> String:
	var event: String = game.current_event
	var choice := "leave"
	match event:
		game.WOUNDED_EVENT: choice = "bait" if profile == 1 and game.gold >= 50 else "kill"
		game.VAMPIRE_EVENT: choice = "noctis" if game.gold >= game.NOCTIS_PRICE and not game._unique_in_play("녹티스") else "leave"
		game.COUNT_EVENT:
			var choices := ["응원", "증원", "염원"].filter(func(r): return not game._has_relic(r))
			if not choices.is_empty(): choice = choices[choice_rng.randi_range(0, choices.size() - 1)] if profile == 1 else choices[0]
		game.DRAGON_EVENT: choice = "pendant" if game.gold >= 50 and not game.dragon_pendant else "leave"
		game.MADNESS_EVENT: choice = "madness" if profile == 1 else "leave"
		game.CHAOS_EVENT: choice = "chaos" if profile == 1 and choice_rng.randi_range(0, 1) == 0 else "leave"
		game.EVOLUTION_EVENT: choice = "instinct" if profile == 1 else "leave"
		game.MERCHANT_EVENT:
			if game.gold >= 30: game._choose_event("buy_card")
			choice = "leave"
		"강화 의식":
			var candidates: Array = game._research_candidates()
			if profile == 1 and not candidates.is_empty():
				game._choose_event("ritual")
				game.selected_event_card = candidates[0].id
				game._finish_card_event()
				return "ritual"
		"넌 필요없어!!", "그냥 처음에 보여준거로 해주세요":
			if profile == 1 and not game.deck.is_empty():
				game._start_card_event()
				game.selected_event_card = game.deck[0].id
				game._finish_card_event()
				return "use"
		"가능성 연구":
			var candidates: Array = game._research_candidates()
			if profile == 1 and game.gold >= 70 and candidates.size() >= 2:
				game.research_selected = [candidates[0].id, candidates[1].id]
				game._finish_research()
				return "fusion"
	game._choose_event(choice)
	return choice

func add_result(map: Dictionary, key: String, won: bool, round_value: int) -> void:
	if not map.has(key): map[key] = {"runs":0, "wins":0, "round_sum":0}
	map[key].runs += 1
	if won: map[key].wins += 1
	map[key].round_sum += round_value

func run() -> void:
	game = load("res://simulation_game.gd").new()
	root.add_child(game)
	await process_frame
	game.simulation_fast = true
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 10000
	var start_seed := int(args[1]) if args.size() > 1 else 1
	var output_name: String = args[2] if args.size() > 2 else "balance_results.json"
	for seed_value in range(start_seed, start_seed + count):
		var profile := seed_value % 2
		choice_rng.seed = seed_value * 7919
		game._new_game(seed_value)
		game.dealt.clear()
		game.actions.clear()
		var seen_cards := {}
		var seen_events := {}
		var turns := 0
		while game.phase not in ["클리어", "패배", "교착"] and turns < 150:
			turns += 1
			match game.phase:
				"준비":
					for card in game.deck: seen_cards[card.name] = true
					prepare(profile)
					await game._start_wave()
				"카드 보상": game._choose_card_reward(pick_reward(profile))
				"보스 보상":
					var options: Array = game._sample_options(game.REWARDS.filter(func(r): return not game.rewards_used.has(r)), 3, game._seeded_rng("boss_reward", game.round_number))
					if options.is_empty(): break
					var reward: String = options[choice_rng.randi_range(0, options.size() - 1)] if profile == 1 else options[0]
					game._choose_reward(reward)
				"이벤트":
					var name_value: String = game.current_event
					var choice := decide_event(profile)
					seen_events[name_value + " | " + choice] = true
				_: break
		var won: bool = game.phase == "클리어"
		var round_value: int = game.round_number
		summary.runs += 1
		if won: summary.wins += 1
		if game.phase == "교착" or turns >= 150: summary.stalemates += 1
		var round_key := str(round_value)
		summary.rounds[round_key] = summary.rounds.get(round_key, 0) + 1
		add_result(summary.profiles, str(profile), won, round_value)
		for name_value in seen_cards: add_result(summary.cards, name_value, won, round_value)
		for name_value in seen_events: add_result(summary.events, name_value, won, round_value)
		for relic in game.RELIC_POOL:
			if game._has_relic(relic): add_result(summary.relics, relic, won, round_value)
		for name_value in game.dealt: summary.soldier_damage[name_value] = summary.soldier_damage.get(name_value, 0) + game.dealt[name_value]
		for name_value in game.actions: summary.soldier_actions[name_value] = summary.soldier_actions.get(name_value, 0) + game.actions[name_value]
		if summary.runs % 100 == 0:
			print("PROGRESS ", summary.runs, "/", count, " wins=", summary.wins, " stalled=", summary.stalemates)
			await process_frame
	var file := FileAccess.open("res://" + output_name, FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	print("SIMULATION COMPLETE ", JSON.stringify({"runs":summary.runs, "wins":summary.wins, "stalemates":summary.stalemates}))
	quit()
