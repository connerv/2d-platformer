extends Node2D

@export var player: CharacterBody2D
@export var current_map: Map
@export var camera: Camera2D

@export var transition_time: float = 1.2

var is_transitioning: bool = false

func _ready() -> void:
	_link_portals()
	_enter_map(current_map)

## Pair up every portal that shares a link_id. Portals live inside the map
## scenes and can't reference each other across scenes -- the manager is the
## one place that sees them all, so it does the stitching here.
##
## NOTE: requires every portal to be in the "portals" group (Node > Groups).
## CAVEAT for later: once you add bg "poster" maps (which are instances of real
## maps), they'll carry duplicate portals with the same link_ids. When that day
## comes, keep poster portals OUT of this group so they don't get paired here.
func _link_portals() -> void:
	var seen: Dictionary = {}
	for portal: Portal in get_tree().get_nodes_in_group("portals"):
		if portal.link_id == "":
			continue
		if portal.map == null or portal.map.get_parent() != self:
			continue   # this portal belongs to a background poster, not a real map
		if seen.has(portal.link_id):
			var other: Portal = seen[portal.link_id]
			portal.partner = other
			other.partner = portal
		else:
			seen[portal.link_id] = portal

## Make `map` the active area and point the player's tilemap logic at it.
## Called once at startup and again on every transition.
func _enter_map(map: Map) -> void:
	current_map = map
	player.ground_tilemap = map.ground_tilemap
	player.ladder_tilemap = map.ladder_tilemap

## Find the poster copy of the destination door that lives inside the map we're
## leaving -- that's the point the camera zooms into before the snap. Two poster
## copies share a link_id (one per map's poster), so we pick the one nested
## inside from_portal's own map.
func _find_dive_anchor(from_portal: Portal) -> Portal:
	for p: Portal in get_tree().get_nodes_in_group("portals"):
		if p.link_id != from_portal.link_id:
			continue                              # different door pair
		if p.map == null or p.map.get_parent() == self:
			continue                              # a real portal, not a poster
		if from_portal.map.is_ancestor_of(p):
			return p                              # the poster copy in our current map
	return null

## Triggered by a portal's interact(). `from_portal` is the door the player
## walked into; its `partner` is where they come out.
func begin_transition(from_portal: Portal) -> void:
	var dest_portal: Portal = from_portal.partner
	if is_transitioning or dest_portal == null:
		return
	is_transitioning = true


	# Take control away, and drive the camera by hand (no follow, no smoothing --
	# the tween needs exact control or the view lags behind and the snap shows).
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	camera.enter_transition_mode()
	camera.position_smoothing_enabled = false
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_snap_2d_transforms_to_pixel(vp, false)
	RenderingServer.viewport_set_snap_2d_vertices_to_pixel(vp, false)

	# --- Phase 1: zoom INTO the little poster sitting in the current map ---
	var anchor: Portal = _find_dive_anchor(from_portal)
	var poster: Node2D = anchor.map if anchor else null
	var poster_dim: Color = poster.modulate if poster else Color.WHITE

	var tween := create_tween()
	# tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if anchor:
		# Zooming by 1 / poster_scale makes the poster fill the screen at the
		# size the real map shows at zoom 1 -- so the upcoming snap is seamless.
		tween.tween_property(camera, "global_position", anchor.global_position, transition_time)
		tween.tween_property(camera, "zoom", Vector2.ONE / anchor.map.scale, transition_time*3)
		tween.parallel().tween_property(anchor.map, "modulate", Color(1, 1, 1, 1), transition_time * 3)    # brighten WITH the zoom
	else:
		# No poster wired for this door -- fall back to a plain pan to the real map.
		tween.tween_property(camera, "global_position", dest_portal.global_position, transition_time)
	await tween.finished

	# --- Snap: cut to the REAL map, hidden behind the full-screen poster ---
	current_map.process_mode = Node.PROCESS_MODE_DISABLED      # old map -> frozen backdrop
	_enter_map(dest_portal.map)
	dest_portal.map.process_mode = Node.PROCESS_MODE_INHERIT   # new map -> alive
	player.global_position = dest_portal.global_position
	camera.global_position = player.global_position
	camera.zoom = Vector2.ONE    
	camera.force_update_scroll()   # <-- apply the new camera transform THIS frame, no 1-frame lag
	# in the snap block:
	if poster:
		poster.modulate = poster_dim   # put the backdrop back to its dim resting look                              # reset zoom -> never accumulates

	# Hand control back. reset_smoothing() so the camera doesn't slide from the
	# pre-snap spot, then restore the nice follow smoothing.
	camera.enter_follow_mode()
	camera.position_smoothing_enabled = true
	camera.reset_smoothing()
	RenderingServer.viewport_set_snap_2d_transforms_to_pixel(vp, true)
	RenderingServer.viewport_set_snap_2d_vertices_to_pixel(vp, true)
	player.set_physics_process(true)
	is_transitioning = false
