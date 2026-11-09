extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func fuse(game, first: String, second: String) -> Dictionary:
	game._new_game(1234)
	game.gold = 70
	game._add_card(first)
	game._add_card(second)
	var first_card: Dictionary = game.deck[-2]
	var second_card: Dictionary = game.deck[-1]
	game.research_selected = [first_card.id, second_card.id]
	game.current_event = "가능성 연구"
	game.phase = "이벤트"
	game._finish_research()
	return game.card_defs[game.deck[-1].name]

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://soldier-test-%d.json" % Time.get_ticks_usec()
	var expected := {
		"임프":[0, 4, 3, "일반"], "슬라임":[1, 13, 5, "상급"],
		"가고일":[2, 26, 7, "일반"], "드래곤":[3, 30, 12, "특급"],
		"하피":[1, 7, 3, "일반"], "사령술사":[6, 25, 5, "상급"], "아라크네":[2, 25, 11, "상급"],
	}
	for name_value in expected:
		var data: Dictionary = game.CARDS[name_value]
		var values: Array = expected[name_value]
		assert(data.cost == values[0] and data.hp == values[1] and data.attack == values[2] and data.rarity == values[3])
		assert(game.ROUND_CARD_POOL.has(name_value))
		assert(game.card_icons.has(name_value) and game.sprite_icons.has(name_value))
	assert(not game.CARDS.has("서큐버스"))
	assert(game.CARDS["슬라임"].regen == 4)
	assert(game.CARDS["드래곤"].area_attack and game.CARDS["사령술사"].area_attack)
	assert(game.CARDS["하피"].targeting == "rear" and game.CARDS["아라크네"].targeting == "highest_attack")
	game._new_game(1234)
	assert(game.deck.size() == 8)
	game._show_card_reward()
	assert(game.offered_cards.size() == 3)
	assert(game.offered_cards.all(func(card_name): return game.ROUND_CARD_POOL.has(card_name) and not game.STARTER_ONLY_CARDS.has(card_name)))
	assert(game.offered_cards.duplicate().filter(func(name): return name == game.offered_cards[0]).size() == 1)
	# Target selection follows current attack values and respects taunt.
	var front = {"name":"앞", "hp":30, "attack":5}
	var strong = {"name":"강한 적", "hp":30, "attack":20}
	var rear = {"name":"뒤", "hp":30, "attack":4}
	assert(game._single_target_enemy([front, strong, rear], "rear", []) == rear)
	assert(game._single_target_enemy([front, strong, rear], "highest_attack", []) == strong)
	assert(game._single_target_enemy([front, strong, rear], "rear", [front]) == front)
	assert(game._single_target_enemy([front, strong, rear], "highest_attack", [rear]) == rear)
	# Harpy and Arachne use those choices during actual combat.
	game._new_game(1234)
	game.lanes[0].rooms[0].append({"name":"하피", "hp":7, "max_hp":7})
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[{"name":"앞", "hp":3, "attack":0}, {"name":"뒤", "hp":3, "attack":0}]}, 0)
	var attacks: Array = game.log_lines.filter(func(line): return line.begins_with("하피 →"))
	assert(attacks.size() == 2 and attacks[0].begins_with("하피 → 뒤"))
	game._new_game(1234)
	game.lanes[0].rooms[0].append({"name":"아라크네", "hp":25, "max_hp":25})
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[{"name":"앞", "hp":11, "attack":1}, {"name":"강한 적", "hp":11, "attack":10}, {"name":"뒤", "hp":11, "attack":2}]}, 0)
	attacks = game.log_lines.filter(func(line): return line.begins_with("아라크네 →"))
	assert(attacks[0].begins_with("아라크네 → 강한 적"))
	# Dragon and necromancer attack every living enemy.
	for name_value in ["드래곤", "사령술사"]:
		game._new_game(1234)
		var damage: int = game.CARDS[name_value].attack
		game.lanes[0].rooms[0].append({"name":name_value, "hp":30, "max_hp":30})
		var enemies := [{"name":"적1", "hp":damage, "attack":0}, {"name":"적2", "hp":damage, "attack":0}]
		await game._fight({"lane":0, "units":enemies}, 0)
		assert(enemies[0].hp == 0 and enemies[1].hp == 0 and game.damage_total == damage * 2)
	# Slime regenerates 4 at preparation, without exceeding maximum health.
	game._new_game(1234)
	var slime := {"name":"슬라임", "hp":8, "max_hp":13}
	game.lanes[0].rooms[0].append(slime)
	game._prepare_round()
	assert(slime.hp == 12)
	game._prepare_round()
	assert(slime.hp == 13)
	# Four actual ally deaths discount the following round's Necromancer by 4.
	game._new_game(1234)
	game.speed = 0.001
	for i in range(4): game.lanes[0].rooms[0].append({"name":"고블린", "hp":1, "max_hp":14})
	game.lanes[0].traps[1].append({"name":"가시", "active":true, "hits":0, "placed_round":0})
	game.parties = [{"lane":0, "route":[0,0,0,0,0,0,0,0], "units":[{"name":"적", "hp":9, "max_hp":9, "attack":99, "area_attack":true}], "pos":-1, "done":false}]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "카드 보상" and game.deaths_this_wave == 4 and game.previous_wave_deaths == 4)
	assert(game._card_cost("사령술사") == 2)
	game._choose_card_reward("")
	game._add_card("사령술사")
	var necro_card: Dictionary = game.deck[-1]
	game.discard_pile.erase(necro_card)
	game.hand.append(necro_card)
	var start_cost: int = game.cost
	game._select_card(game.hand.size() - 1)
	game._slot_pressed(0, 0, true)
	assert(game.cost == start_cost - 2 and game.lanes[0].rooms[0][0].paid_cost == 2)
	game._set_mode("remove")
	game._soldier_pressed(0, 0, 0)
	assert(game.cost == start_cost and game.hand.has(necro_card))
	# A wave without ally deaths removes the discount; lower bound is zero.
	game.parties.clear()
	game._start_wave()
	assert(game.phase == "카드 보상" and game.previous_wave_deaths == 0 and game._card_cost("사령술사") == 6)
	game.previous_wave_deaths = 9
	assert(game._card_cost("사령술사") == 0)
	game._new_game(1234)
	assert(game.previous_wave_deaths == 0)
	# Existing fusion inherits the new abilities and resolves target conflicts as agreed.
	var chimera := fuse(game, "하피", "아라크네")
	assert(chimera.targeting == "highest_attack")
	chimera = fuse(game, "사령술사", "사령술사")
	assert(chimera.death_discount and chimera.area_attack and chimera.cost == 6)
	game.previous_wave_deaths = 2
	assert(game._card_cost(game.deck[-1].name) == 4)
	chimera = fuse(game, "드래곤", "하피")
	assert(chimera.area_attack and chimera.targeting == "rear")
	var chimera_name: String = game.deck[-1].name
	game.lanes[0].rooms[0].append({"name":chimera_name, "hp":30, "max_hp":30})
	var targets := [{"name":"적1", "hp":15, "attack":0}, {"name":"적2", "hp":15, "attack":0}]
	await game._fight({"lane":0, "units":targets}, 0)
	assert(targets[0].hp == 0 and targets[1].hp == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.record_path))
	print("CHECK PASSED: soldier definitions, targets, area attacks, regeneration and previous-wave discount")
	quit()
