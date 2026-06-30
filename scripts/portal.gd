extends Node2D
class_name Portal

@export var target_map: Map

func interact() -> void:
	get_tree().current_scene.begin_transition(target_map)
