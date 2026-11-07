extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.record_path = "user://map-test-%d.json" % Time.get_ticks_usec()
	var found_two := -1
	var found_three := -1
	var different_layouts := {}
	for seed_value in range(100):
		game._generate_map(seed_value)
		var lane_count: int = game.lanes.size()
		assert(lane_count in [2, 3])
		if lane_count == 2 and game.map_crossings.any(func(crossing): return crossing.after == 1): found_two = seed_value
		elif lane_count == 3: found_three = seed_value
		for lane in game.lanes:
			assert(lane.rooms.size() == 3 and lane.traps.size() == 5)
		var signature := JSON.stringify({"lanes":lane_count, "crossings":game.map_crossings})
		different_layouts[signature] = true
		game._generate_map(seed_value)
		assert(signature == JSON.stringify({"lanes":game.lanes.size(), "crossings":game.map_crossings}))
		for crossing in game.map_crossings:
			assert(crossing.top >= 0 and crossing.top + 1 < lane_count)
			assert(crossing.after >= 0 and crossing.after < game.MAP_STAGES.size() - 1)
			assert(game._crossing_destination(crossing.top, crossing.after) == crossing.top + 1)
			assert(game._crossing_destination(crossing.top + 1, crossing.after) == crossing.top)
		for sample in range(5):
			var route: Array = game._make_party_route(sample % lane_count)
			assert(route.size() == game.MAP_STAGES.size())
			for step in range(route.size() - 1):
				assert(route[step] >= 0 and route[step] < lane_count)
				assert(route[step + 1] == route[step] or route[step + 1] == game._crossing_destination(route[step], step))
	assert(found_two >= 0 and found_three >= 0 and different_layouts.size() > 2)
	assert(game.MAP_STAGES[2].type == "trap" and game.MAP_STAGES[3].type == "trap")
	game._new_game(found_three)
	var saved_map := JSON.stringify({"lanes":game.lanes.size(), "crossings":game.map_crossings})
	assert(game.seed_input.text == str(found_three))
	game._new_game(found_three)
	assert(saved_map == JSON.stringify({"lanes":game.lanes.size(), "crossings":game.map_crossings}))
	game.seed_input.text = str(found_two)
	game._start_seeded_game()
	assert(game.map_seed == found_two and game.lanes.size() == 2)
	game.seed_input.text = "잘못된 시드"
	game._start_seeded_game()
	assert(game.map_seed == found_two)
	game._new_game(found_three)
	# Each crossing permits both continuing straight and changing lanes.
	var first_crossing: Dictionary = game.map_crossings[0]
	var saw_straight := false
	var saw_change := false
	for sample in range(100):
		var route: Array = game._make_party_route(first_crossing.top)
		if route[first_crossing.after + 1] == route[first_crossing.after]: saw_straight = true
		else: saw_change = true
	assert(saw_straight and saw_change)
	# The third path's last room and corridor respond to map clicks.
	game.hand.append({"id":90001, "name":"고블린"})
	game._select_card(game.hand.size() - 1)
	await process_frame
	var board = game.board_box.get_child(0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(900, board._lane_y(2)) * (board.size.x / 1200.0)
	board._gui_input(click)
	assert(game.lanes[2].rooms[2].size() == 1)
	game.hand.append({"id":90002, "name":"가시"})
	game._select_card(game.hand.size() - 1)
	await process_frame
	board = game.board_box.get_child(0)
	click.position = Vector2(1025, board._lane_y(2)) * (board.size.x / 1200.0)
	board._gui_input(click)
	assert(game.lanes[2].traps[4].size() == 1)
	# Two routes merging on one corridor queue and each trigger its actual trap.
	game._new_game(found_two)
	game.speed = 0.001
	var trap := {"name":"가시", "active":true, "hits":0, "placed_round":1}
	game.lanes[1].traps[1].append(trap)
	game.parties = [
		{"lane":0, "route":[0,0,1,1,1,1,1,1], "units":[{"name":"도적", "hp":20, "max_hp":20, "attack":1}], "pos":-1, "done":false},
		{"lane":1, "route":[1,1,1,1,1,1,1,1], "units":[{"name":"도적", "hp":20, "max_hp":20, "attack":1}], "pos":-1, "done":false},
	]
	game._start_wave()
	while game.phase == "웨이브":
		await process_frame
		if game.phase == "웨이브":
			var a: Dictionary = game.parties[0]
			var b: Dictionary = game.parties[1]
			assert(a.pos < 0 or b.pos < 0 or a.done or b.done or a.pos != b.pos or a.lane != b.lane)
	assert(game.phase == "패배" and trap.hits == 2)
	assert(game.previous_parties[0].units[0].hp == 14 and game.previous_parties[1].units[0].hp == 14)
	# A crossing route really enters the destination lane's corridor and can be stopped there.
	game._new_game(found_two)
	game.speed = 0.001
	var target_trap := {"name":"가시", "active":true, "hits":0, "placed_round":1}
	game.lanes[1].traps[1].append(target_trap)
	game.parties = [{"lane":0, "route":[0,0,1,1,1,1,1,1], "units":[{"name":"도적", "hp":6, "max_hp":6, "attack":1}], "pos":-1, "done":false}]
	game._start_wave()
	while game.phase == "웨이브": await create_timer(0.01).timeout
	assert(game.phase == "카드 보상" and target_trap.hits == 1)
	assert(game.previous_parties[0].lane == 1 and game.previous_parties[0].units[0].hp == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.record_path))
	print("CHECK PASSED: seeded maps, orthogonal crossings, paths, placements and merging parties")
	quit()
