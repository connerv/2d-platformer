extends CharacterBody2D

@export var move_speed: float = 70.0
@export var crouch_speed: float = 28.0
@export var jump_force: float = -155.0
@export var gravity: float = 500.0
@export var coyote_time: float = 0.07
@export var jump_buffer_time: float = 0.08
@export var ground_acceleration: float = 600.0
@export var ground_deceleration: float = 800.0
@export var air_acceleration: float = 300.0
@export var climb_speed: float = 40.0
@export var ladder_tilemap: TileMapLayer

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var just_jumped: bool = false

@onready var anim: AnimatedSprite2D = $AnimSprite

func _physics_process(delta: float) -> void:
	if _is_on_ladder() and Input.is_action_pressed("move_up"):
		velocity.y = -climb_speed
		var dir := Input.get_axis("move_left", "move_right")
		velocity.x = dir * crouch_speed
		move_and_slide()
		anim.play("climb")
		#_update_animation()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	_tick_timers(delta)
	_handle_movement(delta)
	_handle_jump()
	was_on_floor = is_on_floor()
	move_and_slide()
	_update_animation()

func _is_on_ladder() -> bool:
	if ladder_tilemap == null:
		return false
	var tile_pos := ladder_tilemap.local_to_map(ladder_tilemap.to_local(global_position))
	var data := ladder_tilemap.get_cell_tile_data(tile_pos)
	return data != null and data.get_custom_data("is_ladder")

func _tick_timers(delta: float) -> void:
	if was_on_floor and not is_on_floor() and not just_jumped:
		coyote_timer = coyote_time
	elif is_on_floor():
		coyote_timer = 0.0
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	#var crouching := Input.is_action_pressed("crouch") and is_on_floor()
	var target_speed := dir * move_speed#(crouch_speed if crouching else move_speed)
	if dir != 0:
		var accel := ground_acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)

func _handle_jump() -> void:
	var can_jump := is_on_floor() or coyote_timer > 0.0
	var wants_jump := jump_buffer_timer > 0.0
	if can_jump and wants_jump:
		velocity.y = jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		just_jumped = true
	else:
		just_jumped = false

func _update_animation() -> void:
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	if not is_on_floor():
		if velocity.y < 0:
			anim.play("jump")
		elif velocity.y > 70:
			anim.play("fall-fast")
		else:
			anim.play("fall")
	elif Input.is_action_pressed("move_down") and velocity.x == 0:
		anim.play("crouch")
	elif velocity.x != 0:
		anim.play("walk")
	else:
		anim.play("idle")
