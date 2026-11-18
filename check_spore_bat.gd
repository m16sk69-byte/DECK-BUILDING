extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.speed = 0.001
	var bat: Dictionary = game.CARDS["동굴박쥐"]
	var spore: Dictionary = game.CARDS["포자술사"]
	assert(bat.cost == 1 and bat.hp == 5 and bat.attack == 5 and bat.blur and bat.rarity == "일반")
	assert(spore.cost == 1 and spore.hp == 8 and spore.attack == 3 and spore.battle_start_attack_down == 2)
	for name_value in ["동굴박쥐", "포자술사"]:
		assert(game.ROUND_CARD_POOL.has(name_value) and game.card_icons.has(name_value))
	var bat_unit := {"name":"동굴박쥐", "hp":5, "max_hp":5}
	var goblin := {"name":"고블린", "hp":14, "max_hp":14}
	assert(is_same(game._single_target_soldier([bat_unit, goblin]), goblin))
	assert(is_same(game._single_target_soldier([goblin, bat_unit], "rear"), goblin))
	assert(is_same(game._single_target_soldier([bat_unit]), bat_unit))
	# Every enemy loses two for this room, including enemies that act later.
	game._new_game(9)
	var s := {"name":"포자술사", "hp":8, "max_hp":8}
	game.lanes[0].rooms[0].append(s)
	var front := {"name":"앞", "hp":100, "max_hp":100, "attack":5}
	var back := {"name":"뒤", "hp":100, "max_hp":100, "attack":6}
	game.phase = "웨이브"
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[front, back]}, 0)
	assert(game.log_lines.any(func(line): return line.begins_with("앞 → 포자술사 3 피해")))
	assert(game.log_lines.any(func(line): return line.begins_with("뒤 → 포자술사 4 피해")))
	assert(front.attack == 5 and back.attack == 6 and not front.has("room_attack_down") and not back.has("room_attack_down"))
	# Two spores stack, zero is the minimum, and area attacks hit both.
	game._new_game(9)
	game.lanes[0].rooms[0].append_array([{"name":"포자술사", "hp":8, "max_hp":8}, {"name":"포자술사", "hp":8, "max_hp":8}])
	var weak := {"name":"약한 적", "hp":100, "max_hp":100, "attack":3}
	var mage := {"name":"범위 적", "hp":100, "max_hp":100, "attack":9, "area_attack":true}
	game.phase = "웨이브"
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[weak, mage]}, 0)
	assert(game.log_lines.any(func(line): return line.begins_with("약한 적 → 포자술사 0 피해")))
	assert(game.log_lines.filter(func(line): return line.begins_with("범위 적 → 포자술사 5 피해")).size() >= 2)
	assert(not weak.has("room_attack_down") and not mage.has("room_attack_down"))
	# A spore caster's reduction persists until the room combat ends even after it dies.
	game._new_game(9)
	game.lanes[0].rooms[0].append_array([{"name":"포자술사", "hp":1, "max_hp":8}, {"name":"포자술사", "hp":8, "max_hp":8}])
	var durable := {"name":"적", "hp":20, "max_hp":20, "attack":5}
	game.phase = "웨이브"
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[durable]}, 0)
	assert(game.log_lines.filter(func(line): return line.begins_with("적 → 포자술사 1 피해")).size() >= 2)
	assert(not durable.has("room_attack_down"))
	# A permanent attack boost keeps growing; the temporary penalty is clamped independently.
	game._new_game(9)
	game.lanes[0].rooms[0].append({"name":"포자술사", "hp":8, "max_hp":8})
	var swordsman := {"name":"강화 적", "hp":100, "max_hp":100, "attack":1, "attack_count":0, "attack_boost_interval":1, "attack_boost":5}
	game.phase = "웨이브"
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[swordsman]}, 0)
	assert(swordsman.attack == 11 and game._effective_enemy_attack(swordsman) == 11)
	assert(game.log_lines.any(func(line): return line.begins_with("강화 적 → 포자술사 4 피해")))
	# The temporary attack penalty does not alter fixed party healing.
	game._new_game(9)
	game.card_defs["포자술사"].attack = 0
	game.lanes[0].rooms[0].append({"name":"포자술사", "hp":1, "max_hp":8})
	var saint = game._make_enemy("성녀")
	saint.hp = 10
	var killer := {"name":"적", "hp":100, "max_hp":100, "attack":5}
	game.phase = "웨이브"
	await game._fight({"lane":0, "units":[saint, killer]}, 0)
	assert(saint.hp == 40 and saint.attack == 30 and not saint.has("room_attack_down"))
	# Fusion combines the two numeric start-of-combat effects.
	game._new_game(9)
	game._add_card("포자술사")
	game._add_card("포자술사")
	game.research_selected = [game.deck[-2].id, game.deck[-1].id]
	game.current_event = "가능성 연구"
	game.phase = "이벤트"
	game.gold = 70
	game._finish_research()
	assert(game.card_defs[game.deck[-1].name].battle_start_attack_down == 4)
	print("CHECK PASSED: bat targeting, spore stacking, floor, buffs, healing and fusion")
	quit()
