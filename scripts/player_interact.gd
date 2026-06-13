extends Area2D

@onready var indicator := $Sprite2D

var current_interactable: Interactable = null

func _ready() -> void:
	indicator.visible = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if current_interactable and Input.is_action_just_pressed("interact"):
		current_interactable.interact()

func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent is Interactable:
		current_interactable = parent
		indicator.visible = true

func _on_area_exited(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent == current_interactable:
		current_interactable = null
		indicator.visible = false
