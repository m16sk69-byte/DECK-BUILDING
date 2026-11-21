extends "res://main.gd"

var dealt := {}
var actions := {}

func _refresh() -> void:
	pass

func _start_music() -> void:
	pass

func _log(_value: String) -> void:
	pass

func _finish(won: bool) -> void:
	phase = "클리어" if won else "패배"

func _soldier_attack(ally: Dictionary, party: Dictionary, taunters: Array) -> void:
	var before := damage_total
	super._soldier_attack(ally, party, taunters)
	var name_value: String = ally.name
	dealt[name_value] = dealt.get(name_value, 0) + damage_total - before
	actions[name_value] = actions.get(name_value, 0) + 1
