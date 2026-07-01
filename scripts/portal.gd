extends Node2D
class_name Portal

## A linked door. It lives INSIDE a map scene, so it can't directly reference a
## portal in another scene -- instead each pair shares a `link_id`, and the World
## manager stitches the pairs together at startup (see world.gd::_link_portals).

@export var map: Map         ## the map this portal sits on (same-scene drag)
@export var link_id: String  ## must match exactly on its partner portal

## Filled in at runtime by the manager once it pairs up matching link_ids.
var partner: Portal = null

func interact() -> void:
	var world := get_tree().current_scene
	if partner and world.has_method("begin_transition"):
		world.begin_transition(self)
