extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_game(42)
	var trap_data: Dictionary = game.CARDS["독가스 함정"]
	var succubus_data: Dictionary = game.CARDS["서큐버스"]
	assert(trap_data.cost == 2 and trap_data.poison == 3 and trap_data.slot == "천장" and trap_data.consumable and trap_data.rarity == "상급")
	assert(succubus_data.cost == 2 and succubus_data.hp == 15 and succubus_data.attack == 8 and succubus_data.targeting == "rear" and succubus_data.charm and succubus_data.rarity == "상급")
	for name_value in ["독가스 함정", "서큐버스"]:
		assert(game.ROUND_CARD_POOL.has(name_value) and game.card_icons.has(name_value))
	# All living enemies are poisoned, no immediate damage, and poison stacks.
	var trap := {"name":"독가스 함정", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0].append(trap)
	game.trap_bonus = 10
	var one := {"name":"첫째", "hp":20, "max_hp":20, "attack":0}
	var two := {"name":"둘째", "hp":20, "max_hp":20, "attack":0, "poison":2}
	var defeated := {"name":"처치됨", "hp":0, "max_hp":20, "attack":0}
	var party := {"lane":0, "units":[one, two, defeated]}
	game._apply_traps(party, 0)
	assert(one.hp == 20 and one.poison == 3 and two.poison == 5 and not defeated.has("poison"))
	assert(not trap.active and trap.hits == 1)
	game._apply_traps(party, 0)
	assert(one.poison == 3 and trap.hits == 1)
	game.gold = 30
	game._set_mode("rearm")
	game._slot_pressed(0, 0, false)
	assert(game.gold == 25 and trap.active and trap.hits == 0)
	game._apply_traps(party, 0)
	assert(one.poison == 6 and two.poison == 8)
	# Poison damages an enemy at its action, then it remains for the wave.
	game._new_game(42)
	game.card_defs["고블린"].attack = 0
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":1, "max_hp":1})
	var poisoned := {"name":"적", "hp":10, "max_hp":10, "attack":2, "poison":3}
	await game._fight({"lane":0, "units":[poisoned]}, 0)
	assert(poisoned.hp == 7)
	# Rear target takes eight damage and moves to the front immediately.
	game._new_game(42)
	var succubus := {"name":"서큐버스", "hp":15, "max_hp":15}
	var front := {"name":"선두", "hp":30, "max_hp":30, "attack":1}
	var rear := {"name":"후방", "hp":20, "max_hp":20, "attack":1}
	party = {"lane":0, "units":[front, rear]}
	game._soldier_attack(succubus, party, [])
	assert(rear.hp == 12 and party.units[0].name == "후방" and party.units[1].name == "선두")
	# Killed targets cannot be moved; taunt redirects the attack.
	rear.hp = 8
	party.units = [front, rear]
	game._soldier_attack(succubus, party, [])
	assert(rear.hp == 0 and party.units[0].name == "선두")
	rear.hp = 20
	game._soldier_attack(succubus, party, [front])
	assert(front.hp == 22 and rear.hp == 20 and party.units[0].name == "선두")
	# The moved enemy acts first in this cycle, without any unit acting twice.
	game._new_game(42)
	game.lanes[0].rooms[0].append(succubus)
	front = {"name":"선두", "hp":30, "max_hp":30, "attack":1}
	rear = {"name":"후방", "hp":20, "max_hp":20, "attack":20}
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[front, rear]}, 0)
	var attacks: Array = game.log_lines.filter(func(line): return line.begins_with("선두 →") or line.begins_with("후방 →"))
	assert(attacks.size() == 1 and attacks[0].begins_with("후방 →"))
	# Identical enemy copies retain independent actions in the same cycle.
	game._new_game(42)
	game.card_defs["서큐버스"].attack = 0
	game.lanes[0].rooms[0].append({"name":"서큐버스", "hp":2, "max_hp":2})
	var twin_a := {"name":"적", "hp":100, "max_hp":100, "attack":1}
	var twin_b := twin_a.duplicate()
	game.log_lines.clear()
	await game._fight({"lane":0, "units":[twin_a, twin_b]}, 0)
	assert(game.log_lines.filter(func(line): return line.begins_with("적 → 서큐버스")).size() == 2)
	# Fusion preserves charm and the agreed higher-attack targeting priority.
	game._new_game(42)
	game._add_card("서큐버스")
	game._add_card("아라크네")
	game.research_selected = [game.deck[-2].id, game.deck[-1].id]
	game.current_event = "가능성 연구"
	game.phase = "이벤트"
	game.gold = 70
	game._finish_research()
	var chimera: Dictionary = game.card_defs[game.deck[-1].name]
	assert(chimera.charm and chimera.targeting == "highest_attack")
	print("CHECK PASSED: poison trap, charm, targeting, ordering and rearming")
	quit()
