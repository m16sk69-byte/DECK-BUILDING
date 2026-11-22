extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.menu_layer.visible and game.menu_main.visible and not game.menu_options.visible)
	game._show_menu_options()
	assert(not game.menu_main.visible and game.menu_options.visible)
	game._set_menu_music(false)
	assert(not game.music_enabled and game.music_button.text == "배경음: 끔")
	game._set_menu_music(true)
	game._hide_menu_options()
	game._start_from_menu()
	assert(not game.menu_layer.visible)
	game._new_game(2)
	game.hand = [{"id":91001, "name":"고블린"}, {"id":91002, "name":"가시"}, {"id":91003, "name":"리트라이"}]
	game._refresh()
	await process_frame
	var board = game.board_box.get_child(0)
	var scale_value: float = board.size.x / 1200.0
	var room: Vector2 = board._node_pos(0, 1) * scale_value
	var corridor: Vector2 = board._node_pos(0, 0) * scale_value
	var soldier := {"kind":"hand_card", "card_id":91001}
	var trap := {"kind":"hand_card", "card_id":91002}
	var skill := {"kind":"hand_card", "card_id":91003}
	assert(board._can_drop_data(room, soldier) and not board._can_drop_data(corridor, soldier))
	assert(board._can_drop_data(corridor, trap) and not board._can_drop_data(room, trap))
	assert(not board._can_drop_data(room, skill) and not board._can_drop_data(room, {"kind":"hand_card", "card_id":99999}))
	board._drop_data(room, soldier)
	assert(game.lanes[0].rooms[0].size() == 1 and game.cost == 2 and game._hand_index_by_id(91001) == -1)
	await process_frame
	board = game.board_box.get_child(0)
	corridor = board._node_pos(0, 0) * (board.size.x / 1200.0)
	board._drop_data(corridor, trap)
	assert(game.lanes[0].traps[0].size() == 1 and game.cost == 1 and game._hand_index_by_id(91002) == -1)
	game.phase = "웨이브"
	board = game.board_box.get_child(0)
	assert(not board._can_drop_data(room, skill))
	print("CHECK PASSED: menu, options, drag target rules and placement costs")
	quit()
