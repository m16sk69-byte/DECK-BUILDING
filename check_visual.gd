extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("res://prototype-preview.png")
	quit()
