extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.speed = 0.001
	for name_value in ["폭발 룬", "가시 그물"]:
		assert(game.ROUND_CARD_POOL.has(name_value) and game.card_icons.has(name_value))
	assert(game.CARDS["폭발 룬"].slot == "바닥" and game.CARDS["폭발 룬"].damage == 7 and game.CARDS["폭발 룬"].cost == 1 and game.CARDS["폭발 룬"].consumable)
	assert(game.CARDS["가시 그물"].slot == "천장" and game.CARDS["가시 그물"].damage == 4 and game.CARDS["가시 그물"].bleed == 3 and game.CARDS["가시 그물"].consumable)
	var hunter_data: Dictionary = game.ENEMY_TYPES["언데드 사냥꾼"]
	assert(hunter_data.enemy_cost == 2 and hunter_data.hp == 34 and hunter_data.attack == 8 and hunter_data.blocks_revive)
	# Front two are hit; the third remains unharmed and the rune must be rearmed.
	game._new_game(42)
	var rune := {"name":"폭발 룬", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0].append(rune)
	var a := {"name":"앞", "hp":20, "max_hp":20, "attack":1}
	var b := {"name":"중간", "hp":20, "max_hp":20, "attack":1}
	var c := {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	var party := {"lane":0, "units":[a,b,c]}
	game._apply_traps(party, 0)
	assert(a.hp == 13 and b.hp == 13 and c.hp == 20 and not rune.active)
	game._apply_traps(party, 0)
	assert(a.hp == 13 and b.hp == 13)
	game.gold = 5
	game._set_mode("rearm")
	game._slot_pressed(0, 0, false)
	assert(game.gold == 0 and rune.active)
	game._apply_traps(party, 0)
	assert(a.hp == 6 and b.hp == 6 and c.hp == 20)
	# Existing bleed triggers on the hit; new bleed stacks only afterward.
	game._new_game(42)
	var net := {"name":"가시 그물", "active":true, "hits":0, "placed_round":1}
	game.lanes[0].traps[0].append(net)
	a = {"name":"앞", "hp":20, "max_hp":20, "attack":1, "bleed":2}
	b = {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	party = {"lane":0, "units":[a,b]}
	game._apply_traps(party, 0)
	assert(a.hp == 14 and a.bleed == 5 and b.hp == 20 and not b.has("bleed"))
	game._damage_enemy(a, 1, "후속 피해")
	assert(a.hp == 8)
	game._new_game(42)
	game.lanes[0].traps[0].append({"name":"가시 그물", "active":true, "hits":0})
	a = {"name":"약한 적", "hp":4, "max_hp":4, "attack":1}
	game._apply_traps({"lane":0, "units":[a]}, 0)
	assert(a.hp == 0 and not a.has("bleed"))
	# A hunter that survives the room blocks revival, without removing its card.
	game._new_game(42)
	game._add_card("스켈레톤")
	var count_before: int = game.deck.size()
	var skeleton := {"name":"스켈레톤", "hp":1, "max_hp":10}
	game.lanes[0].rooms[0].append(skeleton)
	var hunter = game._make_enemy("언데드 사냥꾼")
	game.phase = "웨이브"
	await game._fight({"lane":0, "units":[hunter]}, 0)
	assert(game.lanes[0].rooms[0].is_empty() and hunter.hp > 0 and game.fallen_revivable.is_empty() and game.deck.size() == count_before)
	# A companion may kill the skeleton, as long as a hunter survives the room.
	game._new_game(42)
	skeleton = {"name":"스켈레톤", "hp":1, "max_hp":10}
	game.lanes[0].rooms[0].append(skeleton)
	hunter = game._make_enemy("언데드 사냥꾼")
	var companion := {"name":"동료", "hp":100, "max_hp":100, "attack":4}
	game.phase = "웨이브"
	await game._fight({"lane":0, "units":[companion, hunter]}, 0)
	assert(game.fallen_revivable.is_empty() and hunter.hp > 0)
	# A hunter killed before the defender dies cannot block resurrection.
	game._new_game(42)
	skeleton = {"name":"스켈레톤", "hp":1, "max_hp":10}
	game.lanes[0].rooms[0].append(skeleton)
	hunter = game._make_enemy("언데드 사냥꾼")
	hunter.hp = 8
	companion = {"name":"동료", "hp":100, "max_hp":100, "attack":4}
	game.phase = "웨이브"
	await game._fight({"lane":0, "units":[hunter, companion]}, 0)
	assert(hunter.hp == 0 and game.fallen_revivable.size() == 1)
	game.round_number = 2
	game._prepare_round()
	assert(game.lanes[0].rooms[0].has(skeleton) and skeleton.hp == 10)
	# Prior deaths in another encounter do not become this hunter's kills.
	game._new_game(42)
	var earlier := {"name":"스켈레톤", "hp":1, "max_hp":10}
	var room: Array = game.lanes[0].rooms[0]
	room.append(earlier)
	game.phase = "웨이브"
	game._damage_soldier(earlier, 1, "먼저 지나간 적", room)
	skeleton = {"name":"스켈레톤", "hp":1, "max_hp":10}
	room.append(skeleton)
	hunter = game._make_enemy("언데드 사냥꾼")
	await game._fight({"lane":0, "units":[hunter]}, 0)
	assert(game.fallen_revivable.size() == 1 and is_same(game.fallen_revivable[0].soldier, earlier))
	print("CHECK PASSED: two traps, bleed timing and hunter resurrection blocking")
	quit()
