extends Node2D

@export var player: CharacterBody2D
@export var current_map: Map
@export var camera: Camera2D

@export var transition_time: float = 1.2
var is_transitioning: bool = false

func _ready() -> void:
	_enter_map(current_map)

func _enter_map(map: Map) -> void:
	current_map = map
	player.ground_tilemap = map.ground_tilemap
	player.ladder_tilemap = map.ladder_tilemap

func begin_transition(target_map: Map) -> void:
	if is_transitioning or target_map == current_map:
		return
	is_transitioning = true

	# 1. take control away from the player
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	# 2. camera stops following
	camera.enter_transition_mode()

	# 3. teleport the player + rewire tilemaps to the new map
	_enter_map(target_map)
	player.global_position = target_map.spawn_point.global_position

	# 4. fly the camera over to where the player now is
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", player.global_position, transition_time)

	# 5. wait for the fly to finish, then hand control back
	await tween.finished
	camera.enter_follow_mode()
	player.set_physics_process(true)
	is_transitioning = false
