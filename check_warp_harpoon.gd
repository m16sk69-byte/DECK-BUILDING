extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func make_party(units: Array, pos := 0) -> Dictionary:
	return {"lane":0, "start_lane":0, "route":[0,0,0,0,0,0,0,0], "units":units, "pos":pos, "done":false}

func new_two_lane_game(game: Control) -> void:
	for seed_value in range(100):
		game._new_game(seed_value)
		if game.lanes.size() == 2: return
	assert(false)

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.speed = 0.001
	game.record_path = "user://warp-test-%d.json" % Time.get_ticks_usec()
	assert(game.CARDS["작살함정"].slot == "벽" and game.CARDS["작살함정"].cost == 1 and game.CARDS["작살함정"].damage == 6 and not game.CARDS["작살함정"].consumable)
	assert(game.CARDS["마법전이진"].slot == "바닥" and game.CARDS["마법전이진"].cost == 2 and not game.CARDS["마법전이진"].consumable)
	for card_name in ["작살함정", "마법전이진"]: assert(game.ROUND_CARD_POOL.has(card_name) and game.card_icons.has(card_name))
	new_two_lane_game(game)
	var harpoon := {"name":"작살함정", "active":true, "hits":0}
	game.lanes[0].traps[0].append(harpoon)
	var a := {"name":"앞", "hp":20, "max_hp":20, "attack":1}
	var b := {"name":"중간", "hp":20, "max_hp":20, "attack":1}
	var c := {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	var party := make_party([a, b, c])
	game._apply_traps(party, 0)
	assert(a.hp == 20 and b.hp == 14 and c.hp == 20 and harpoon.hits == 1 and harpoon.active)
	game._apply_traps(party, 0)
	assert(b.hp == 8 and harpoon.hits == 2 and harpoon.active)
	party.units = [a]
	game._apply_traps(party, 0)
	assert(a.hp == 14 and harpoon.hits == 3 and harpoon.active)
	game._apply_traps(party, 0)
	assert(a.hp == 8 and harpoon.hits == 4)
	# 이미 쓰러진 적은 대상 순서에서 제외한다.
	b.hp = 0
	c.hp = 0
	party.units = [b, a, c]
	game._apply_traps(party, 0)
	assert(a.hp == 2 and harpoon.hits == 5)
	a.hp = 0
	game._apply_traps(party, 0)
	assert(harpoon.hits == 5)
	# The lowest HP enemy teleports, dies in a separate battle, and the original frontline acts again when the remaining party reaches the room.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0, "placed_round":1})
	game.lanes[0].rooms[0].append_array([{"name":"고블린", "hp":14, "max_hp":14}, {"name":"고블린 궁수", "hp":8, "max_hp":8}])
	a = {"name":"앞", "hp":10, "max_hp":10, "attack":14}
	b = {"name":"약한 적", "hp":2, "max_hp":2, "attack":1}
	c = {"name":"뒤", "hp":30, "max_hp":30, "attack":1}
	party = make_party([a, b, c], -1)
	game.parties = [party]
	game.log_lines.clear()
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(b.hp == 0 and a.hp < 10 and game.phase == "카드 보상")
	var actions: Array = game.log_lines.filter(func(line): return line.begins_with("고블린 →"))
	assert(actions.size() >= 2 and actions[0].begins_with("고블린 → 약한 적") and actions[1].begins_with("고블린 → 앞"))
	# The detached survivor waits, then rejoins in its original formation position.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0})
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":3, "max_hp":14})
	a = {"name":"앞", "hp":10, "max_hp":10, "attack":1}
	b = {"name":"전이", "hp":5, "max_hp":5, "attack":8}
	c = {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	party = make_party([a,b,c])
	game.parties = [party]
	game.phase = "웨이브"
	await game._apply_traps(party, 0)
	assert(b.hp == 2 and b.get("_warp_detached", false) and party.warps.size() == 1 and party.warps[0].state == "waiting")
	assert(game._live_enemies(party).map(func(unit): return unit.name) == ["앞", "뒤"])
	game._merge_warps_at(party, 0, 1)
	assert(game._live_enemies(party).map(func(unit): return unit.name) == ["앞", "전이", "뒤"] and party.warps.is_empty())
	# Remaining traps on the same corridor target only the enemies still present.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append_array([{"name":"마법전이진", "active":true, "hits":0}, {"name":"작살함정", "active":true, "hits":0}])
	a = {"name":"앞", "hp":20, "max_hp":20, "attack":1}
	b = {"name":"전이", "hp":5, "max_hp":5, "attack":1}
	c = {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	party = make_party([a,b,c])
	game.parties = [party]
	game.phase = "웨이브"
	await game._apply_traps(party, 0)
	assert(b.get("_warp_detached", false) and b.hp == 5 and a.hp == 20 and c.hp == 14)
	# A lone survivor continues from the teleported room instead of waiting forever.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0, "placed_round":1})
	party = make_party([{"name":"홀로", "hp":10, "max_hp":10, "attack":1}], -1)
	game.parties = [party]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "패배" and game.previous_parties[0].pos == game.MAP_STAGES.size())
	# A surviving teleported enemy rejoins its own party when the party actually arrives.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0})
	game.lanes[0].rooms[0].append({"name":"고블린", "hp":1, "max_hp":14})
	a = {"name":"앞", "hp":10, "max_hp":10, "attack":1}
	b = {"name":"전이", "hp":5, "max_hp":5, "attack":8}
	c = {"name":"뒤", "hp":20, "max_hp":20, "attack":1}
	party = make_party([a,b,c], -1)
	game.parties = [party]
	game.log_lines.clear()
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "패배" and b.hp == 2 and not b.has("_warp_detached"))
	assert(game.log_lines.any(func(line): return line.contains("전이: 원래 파티와 합류")))
	assert(party.units.map(func(unit): return unit.name) == ["앞", "전이", "뒤"])
	# When every non-teleported companion dies in an intervening corridor, a survivor proceeds from the destination.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[1].append({"name":"마법전이진", "active":true, "hits":0})
	var spike := {"name":"가시", "active":true, "hits":0}
	game.lanes[0].traps[2].append(spike)
	game.lanes[0].rooms[1].append({"name":"고블린", "hp":1, "max_hp":14})
	a = {"name":"동료", "hp":6, "max_hp":6, "attack":1}
	b = {"name":"전이", "hp":5, "max_hp":5, "attack":8}
	party = make_party([a,b], -1)
	game.parties = [party]
	game.log_lines.clear()
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "패배" and a.hp == 0 and b.hp == 2 and spike.hits == 1)
	assert(game.log_lines.any(func(line): return line.contains("단독으로 진행")))
	# Two transfer traps on different corridors can send two identical units to the same room.
	new_two_lane_game(game)
	game.speed = 0.001
	var portal_one := {"name":"마법전이진", "active":true, "hits":0}
	var portal_two := {"name":"마법전이진", "active":true, "hits":0}
	game.lanes[0].traps[1].append(portal_one)
	game.lanes[0].traps[2].append(portal_two)
	a = {"name":"앞", "hp":20, "max_hp":20, "attack":1}
	b = {"name":"쌍둥이", "hp":5, "max_hp":5, "attack":1}
	c = b.duplicate()
	party = make_party([a,b,c], -1)
	game.parties = [party]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "패배" and portal_one.hits == 1 and portal_two.hits == 1 and party.warps.is_empty())
	assert(not b.has("_warp_detached") and not c.has("_warp_detached") and is_same(party.units[1], b) and is_same(party.units[2], c))
	# If the destination is occupied, the target enters only after the other party leaves.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0})
	var first_party := make_party([{"name":"앞선 파티", "hp":10, "max_hp":10, "attack":1}], 0)
	a = {"name":"전이 대기", "hp":5, "max_hp":5, "attack":1}
	party = make_party([a], -1)
	game.parties = [first_party, party]
	game.log_lines.clear()
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	var exits: int = game.log_lines.find("파티 1: 위 경로 통로 2")
	var arrival: int = game.log_lines.find("마법전이진: 전이 대기 → 위 경로 방 1")
	assert(game.phase == "패배" and exits >= 0 and arrival > exits)
	# Occupied destination waits without teleporting through another party.
	new_two_lane_game(game)
	game.speed = 0.001
	game.lanes[0].traps[0].append({"name":"마법전이진", "active":true, "hits":0})
	a = {"name":"전이", "hp":5, "max_hp":5, "attack":1}
	party = make_party([a])
	var blocker := make_party([{"name":"다른 파티", "hp":10, "max_hp":10, "attack":1}], 1)
	game.parties = [party, blocker]
	game.phase = "웨이브"
	await game._apply_traps(party, 0)
	assert(party.warps.size() == 1 and party.warps[0].state == "pending" and a.hp == 5)
	blocker.done = true
	await game._resolve_warp(party, party.warps[0], game.wave_token)
	assert(party.warps[0].state == "waiting" and game._promote_waiting_warps(party) and party.pos == 1 and not a.has("_warp_detached"))
	# No later room means no activation and no disappearance.
	new_two_lane_game(game)
	var portal := {"name":"마법전이진", "active":true, "hits":0}
	game.lanes[0].traps[4].append(portal)
	a = {"name":"마지막", "hp":5, "max_hp":5, "attack":1}
	party = make_party([a], 7)
	game.phase = "웨이브"
	await game._apply_traps(party, 4)
	assert(portal.hits == 0 and a.hp == 5 and not a.has("_warp_detached"))
	# The destination follows the actual route, including lane changes.
	party.route = [0,0,1,1,1,1,1,1]
	party.pos = 2
	party.lane = 1
	var destination: Dictionary = game._next_route_room(party)
	assert(destination.pos == 4 and destination.lane == 1 and destination.slot == 1)
	# Three-lane layouts also use their actual per-lane room stages.
	for seed_value in range(100):
		game._new_game(seed_value)
		if game.lanes.size() == 3: break
	assert(game.lanes.size() == 3)
	party = make_party([a], 2)
	party.route = [0,0,1,1,1,1,1,1]
	party.lane = 1
	destination = game._next_route_room(party)
	assert(destination.pos == 4 and destination.lane == 1 and destination.slot == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.record_path))
	print("CHECK PASSED: harpoon, warp combat, rejoining, queues and route edges")
	quit()
