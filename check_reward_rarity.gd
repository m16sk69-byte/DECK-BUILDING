extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.CARD_RARITY_WEIGHTS == {"일반":65, "상급":30, "특급":5})
	assert(game.CARDS["오크"].rarity == "일반" and game.CARDS["오크"].rarity_provisional)
	assert(game._display_card_description("오크").contains("#일반 (임시)"))
	var pool := []
	for grade in ["일반", "상급", "특급"]:
		for i in range(3):
			var name_value: String = "%s%d" % [grade, i]
			game.card_defs[name_value] = {"type":"soldier", "cost":1, "hp":10, "attack":1, "rarity":grade, "description":"시험"}
			pool.append(name_value)
	game.card_defs["등급 미정"] = {"type":"soldier", "cost":1, "hp":10, "attack":1, "description":"시험"}
	pool.append("등급 미정")
	var stream := RandomNumberGenerator.new()
	stream.seed = 389723
	var grades := {"일반":0, "상급":0, "특급":0}
	var names := {}
	var sample_size := 60000
	for i in range(sample_size):
		var reward: String = game._sample_reward_cards(pool, 1, stream)[0]
		grades[game.card_defs[reward].rarity] += 1
		names[reward] = names.get(reward, 0) + 1
	assert(absf(float(grades["일반"]) / sample_size - 0.65) < 0.01)
	assert(absf(float(grades["상급"]) / sample_size - 0.30) < 0.01)
	assert(absf(float(grades["특급"]) / sample_size - 0.05) < 0.01)
	for grade in grades:
		for i in range(3):
			var proportion: float = float(names["%s%d" % [grade, i]]) / grades[grade]
			assert(absf(proportion - 1.0 / 3.0) < 0.04)
	var common_count := 0
	for i in range(20000):
		if game._sample_reward_cards(["일반0", "특급0"], 1, stream)[0] == "일반0":
			common_count += 1
	assert(absf(float(common_count) / 20000 - 65.0 / 70.0) < 0.012)
	var candidates := ["일반0", "상급0", "특급0"]
	var choices: Array = game._sample_reward_cards(candidates, 3, stream)
	assert(choices.size() == 3 and choices.has("일반0") and choices.has("상급0") and choices.has("특급0"))
	assert(game._sample_reward_cards(["등급 미정"], 3, stream).is_empty())
	for i in range(100):
		choices = game._sample_reward_cards(pool, 3, stream)
		assert(choices.size() == 3 and choices[0] != choices[1] and choices[0] != choices[2] and choices[1] != choices[2])
	print("CHECK PASSED: rarity weights, uniform within rarity, exhaustion and unique offers")
	quit()
