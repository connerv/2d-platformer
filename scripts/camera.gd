extends Camera2D

enum CameraMode { FOLLOW_PLAYER, MAP_TRANSITION }

@export var player: CharacterBody2D

var mode: CameraMode = CameraMode.FOLLOW_PLAYER



func _physics_process(delta: float) -> void:
	match mode:
		CameraMode.FOLLOW_PLAYER:
			global_position = player.global_position
		CameraMode.MAP_TRANSITION:
			pass

func enter_follow_mode() -> void:
	mode = CameraMode.FOLLOW_PLAYER

func enter_transition_mode() -> void:
	mode = CameraMode.MAP_TRANSITION