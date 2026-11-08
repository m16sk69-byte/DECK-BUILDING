extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://enemy-test-%d.json" % Time.get_ticks_usec()
	game.speed = 0.001
	var party_shapes := {}
	var budget_three_shapes := {}
	for seed_value in range(300):
		game._generate_map(seed_value)
		for test_round in [1, 3, 6, 11, 19]:
			game.round_number = test_round
			game._generate_parties()
			var total := 0
			var names: Array = []
			for party in game.parties:
				assert(party.units.size() >= 1 and party.units.size() <= 4)
				for unit in party.units:
					total += unit.enemy_cost
					names.append(unit.name)
					if unit.get("requires_party", false): assert(party.units.size() >= 2)
					if unit.name == "마법사": assert(test_round >= 6)
				if party.units.size() > 1:
					for unit in party.units: assert(party.units[0].max_hp >= unit.max_hp)
					for unit in party.units.slice(1): assert(party.units[-1].attack >= unit.attack)
			assert(total == game.ENEMY_BUDGETS[test_round - 1])
			assert(game.parties.size() <= 3)
			if test_round == 6:
				party_shapes[game.parties.size()] = true
				var shape: Array = []
				for party in game.parties:
					var costs: Array = party.units.map(func(unit): return unit.enemy_cost)
					costs.sort()
					shape.append("+".join(costs.map(func(value): return str(value))))
				shape.sort()
				budget_three_shapes["/".join(shape)] = true
			var first := JSON.stringify(game.parties)
			game._generate_parties()
			assert(first == JSON.stringify(game.parties))
	assert(party_shapes.has(1) and party_shapes.has(2) and party_shapes.has(3))
	for shape in ["1+1+1", "1+2", "1/1+1", "1/1/1"]: assert(budget_three_shapes.has(shape))
	# Taunt starts with the shieldbearer's first attack, overriding front targeting.
	game._new_game(123)
	game.card_defs["고블린"].attack = 10
	var shield = game._make_enemy("방패병")
	shield.hp = 15
	var enemy_front = {"name":"적 선두", "hp":100, "max_hp":100, "attack":0}
	var hero = {"name":"고블린", "hp":100, "max_hp":100}
	game.lanes[0].rooms[0].append(hero)
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[enemy_front, shield]}, 0)
	var attacks: Array = game.log_lines.filter(func(line): return line.begins_with("고블린 →"))
	assert(attacks.size() >= 4 and attacks[0].begins_with("고블린 → 적 선두"))
	assert(attacks[1].begins_with("고블린 → 방패병") and attacks[2].begins_with("고블린 → 방패병"))
	assert(attacks[3].begins_with("고블린 → 적 선두"))
	# Every room triggers taunt again; a defeated shield cannot remain a target.
	game._new_game(123)
	game.card_defs["고블린"].attack = 0
	shield = game._make_enemy("방패병")
	game.log_lines.clear()
	for room in [0, 1]:
		game.lanes[0].rooms[room].append({"name":"고블린", "hp":1, "max_hp":1})
		await game._fight({"lane":0, "units":[shield]}, room)
	assert(game.log_lines.filter(func(line): return line.contains("#도발")).size() == 2)
	# Healer restores a wounded ally in front order, never attacks, and cannot exceed max HP.
	game._new_game(123)
	var wounded = {"name":"기사", "hp":10, "max_hp":18, "attack":1}
	var healer = game._make_enemy("회복술사")
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":2, "max_hp":2})
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[wounded, healer]}, 0)
	assert(wounded.hp == 14)
	assert(game.log_lines.any(func(line): return line.begins_with("회복술사 → 기사 체력 10 회복")))
	assert(not game.log_lines.any(func(line): return line.begins_with("회복술사 → 고블린")))
	# Mage hits all defenders on its turn.
	game._new_game(123)
	var mage = game._make_enemy("마법사")
	mage.hp = 6
	var heroes = [{"name":"고블린", "hp":20, "max_hp":20}, {"name":"고블린", "hp":20, "max_hp":20}]
	game.lanes[0].rooms[0].append_array(heroes)
	await game._fight({"lane":0, "units":[mage]}, 0)
	assert(heroes[0].hp == 11 and heroes[1].hp == 11)
	# Alond clears poison and bleed before the turn after attack 3 and when a room falls.
	game._new_game(123)
	game.card_defs["고블린"].attack = 0
	var alond = game._make_enemy("검신 알론드")
	alond.poison = 1
	alond.bleed = 1
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":130, "max_hp":130})
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[alond]}, 0)
	assert(alond.hp == 194 and not alond.has("poison") and not alond.has("bleed"))
	assert(alond.attacks_since_cleanse == 0)
	assert(game.log_lines.filter(func(line): return line.contains("상태 이상 회복")).size() == 2)
	# Repeated heal-versus-damage loops are reported as stalemates instead of hanging.
	game._new_game(123)
	game.phase = "웨이브"
	game.speed = 0.001
	var self_healer = game._make_enemy("회복술사")
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":14, "max_hp":14})
	await game._fight({"lane":0, "units":[self_healer]}, 0)
	assert(game.phase == "교착" and self_healer.hp == 10)
	assert(game.log_lines.any(func(line): return line.contains("전투 교착")))
	print("CHECK PASSED: enemy formations, taunt, healing, area damage, Alond cleanse and stalemates")
	quit()
