class_name Interactable
extends AnimatedSprite2D

@export var flicker_speed: float = 3.0
@export var is_on: bool = false

var time: float = 0.0

@onready var light := $PointLight2D

func _ready() -> void:
	_set_state(is_on)

func _process(delta: float) -> void:
	if not light.enabled:
		return
	time += delta * flicker_speed
	var n := sin(time) + 0.5 * sin(time * 2.7 + 1.4) + 0.25 * sin(time * 5.1 + 0.8)
	var s := remap(n, -1.75, 1.75, 0.9, 1.0)
	light.scale = Vector2(s, s)
	play("on_2" if s >= 0.95 else "on")

func interact() -> void:
	_set_state(not is_on)

func _set_state(on: bool) -> void:
	is_on = on
	light.enabled = is_on
	if not is_on:
		play("off")
