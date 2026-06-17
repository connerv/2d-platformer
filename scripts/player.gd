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
@export var can_glide: bool = true
@export var glide_fall_speed: float = 20.0
@export var ladder_tilemap: TileMapLayer
@export var ground_tilemap: TileMapLayer
@export var water_area: Area2D

const TILE_SIZE: int = 8
const DROWN_DURATION: float = 1.2

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var just_jumped: bool = false
var is_drowning: bool = false
var last_ground_tile: Vector2 = Vector2.ZERO

@onready var anim: AnimatedSprite2D = $AnimSprite
@onready var anim_reflection: AnimatedSprite2D = $AnimSpriteReflection

func _ready() -> void:
	last_ground_tile = global_position
	if water_area:
		water_area.body_entered.connect(_on_water_entered)

func _physics_process(delta: float) -> void:
	if is_drowning:
		return

	if _is_on_ladder() and Input.is_action_pressed("move_up"):
		velocity = Vector2(Input.get_axis("move_left", "move_right") * crouch_speed, -climb_speed)
		move_and_slide()
		_play("climb")
		return

	if _try_glide(delta):
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	_tick_timers(delta)
	_handle_movement(delta)
	_handle_jump()

	if is_on_floor():
		_try_save_ground_position()

	was_on_floor = is_on_floor()
	move_and_slide()
	_update_animation()

# Plays animation on both sprites and syncs flip
func _play(anim_name: String) -> void:
	anim.play(anim_name)
	anim_reflection.play(anim_name)
	anim_reflection.flip_h = anim.flip_h

func _try_save_ground_position() -> void:
	var snapped := Vector2(
		floor(global_position.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2.0,
		floor(global_position.y / TILE_SIZE) * TILE_SIZE
	)
	if _is_solid_ground_below(snapped):
		last_ground_tile = snapped + Vector2(0, 4)

func _is_solid_ground_below(snapped_pos: Vector2) -> bool:
	if ground_tilemap == null:
		return true
	var check_pos := snapped_pos + Vector2(0, TILE_SIZE)
	var tile_pos := ground_tilemap.local_to_map(ground_tilemap.to_local(check_pos))
	return ground_tilemap.get_cell_tile_data(tile_pos) != null

func _on_water_entered(body: Node) -> void:
	if body == self and not is_drowning:
		_start_drown()

func _start_drown() -> void:
	is_drowning = true
	velocity = Vector2.ZERO
	anim.play("drown")
	# Reflection sprite doesn't need to play drown — hide it
	anim_reflection.visible = false
	await get_tree().create_timer(DROWN_DURATION).timeout
	_respawn()

func _respawn() -> void:
	global_position = last_ground_tile
	velocity = Vector2.ZERO
	is_drowning = false
	anim_reflection.visible = true
	_play("idle")

func _try_glide(delta: float) -> bool:
	if is_on_floor() or not can_glide or not (velocity.y >= glide_fall_speed and Input.is_action_pressed("move_up")):
		return false
	velocity.y = glide_fall_speed
	_tick_timers(delta)
	_handle_movement(delta)
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	was_on_floor = false
	move_and_slide()
	_play("glide")
	return true

func _is_on_ladder() -> bool:
	if ladder_tilemap == null:
		return false
	var data := ladder_tilemap.get_cell_tile_data(ladder_tilemap.local_to_map(ladder_tilemap.to_local(global_position)))
	return data != null and data.get_custom_data("is_ladder")

func _tick_timers(delta: float) -> void:
	if was_on_floor and not is_on_floor() and not just_jumped:
		coyote_timer = coyote_time
	elif is_on_floor():
		coyote_timer = 0.0
	else:
		coyote_timer -= delta
	jump_buffer_timer = jump_buffer_time if Input.is_action_just_pressed("jump") else jump_buffer_timer - delta

func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * move_speed, (ground_acceleration if is_on_floor() else air_acceleration) * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_deceleration * delta)

func _handle_jump() -> void:
	if (is_on_floor() or coyote_timer > 0.0) and jump_buffer_timer > 0.0:
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
		_play("jump" if velocity.y < 0 else ("fall-fast" if velocity.y > 70 else "fall"))
	elif Input.is_action_pressed("move_down") and velocity.x == 0:
		_play("crouch")
	elif velocity.x != 0:
		_play("walk")
	else:
		_play("idle")
