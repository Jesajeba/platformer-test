extends SmokeTestBase
## Camera audit for the ruins level: stands the player on every walkable spot along the route
## (centre and side lanes) plus off-route areas (secrets, shortcut, lifts), snaps the camera,
## and checks the player is visible (line of sight) and the camera isn't jammed up close.
## Run: godot --headless --path . res://tests/camera_audit_test.tscn

## Closer than this (m) counts as "camera jammed against the player".
const MIN_DISTANCE: float = 3.0

## Off-route spots the player can reach (ground position; y is found by raycast).
const EXTRA_SPOTS: Dictionary = {
	"secret alcove 1": Vector3(-13.5, 0, -12.5),
	"teaching step": Vector3(5.5, 2, -13.5),
	"secret alcove 3": Vector3(148, 14, -87.5),
	"shortcut corridor start": Vector3(188, 10, -88),
	"shortcut corridor middle": Vector3(198, 10, -88),
	"shortcut corridor end": Vector3(208, 10, -88),
	"secret floating platform": Vector3(205.75, 15, -73.5),
	"stairway landing back": Vector3(119, 7, -85),
	"garden island A back": Vector3(182, 10, -89),
	"arena near throne": Vector3(270, 10, -90),
	"arena behind pillar": Vector3(277.5, 10, -72.5),
	"arena west": Vector3(259, 10, -80),
	"arena east": Vector3(281, 10, -80),
}

var problems: PackedStringArray = PackedStringArray()


func _init() -> void:
	level_scene = load("res://scenes/levels/level_ruins.tscn")


func _run() -> void:
	await _frames(5)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for node: Node in get_tree().get_nodes_in_group("boss"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	(_level.get_node("BossArena") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # Hold still where we put it.
	await _frames(2)

	var rail: Path3D = _level.get_node("CameraRail") as Path3D
	var length: float = rail.curve.get_baked_length()
	var spots: int = 0
	var offset: float = 0.0
	while offset < length:
		var p: Vector3 = rail.global_transform * rail.curve.sample_baked(offset, true)
		var ahead: Vector3 = rail.global_transform * rail.curve.sample_baked(minf(offset + 0.5, length), true)
		var forward: Vector3 = Vector3(ahead.x - p.x, 0, ahead.z - p.z).normalized()
		var right: Vector3 = forward.cross(Vector3.UP)
		for lane: float in [0.0, -1.6, 1.6]:
			spots += await _audit("rail %.0f m%s" % [offset, "" if lane == 0.0 else (" lane %+.1f" % lane)], p + right * lane)
		offset += 3.0
	for spot_name: String in EXTRA_SPOTS:
		spots += await _audit(spot_name, EXTRA_SPOTS[spot_name])
	print("  audited %d spots, %d problems" % [spots, problems.size()])
	for problem: String in problems:
		print("   - " + problem)
	_check("camera sees the player everywhere it can stand", problems.is_empty(), "%d problem spots" % problems.size())


## Returns 1 if the spot was audited (there was ground to stand on), 0 otherwise.
func _audit(label: String, at: Vector3) -> int:
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return 0  # Pit or gap: nowhere to stand.
	var feet: Vector3 = hit["position"]
	# Only audit spots with headroom (not inside walls/pillars).
	var head_query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	head_query.position = feet + Vector3.UP * 0.6
	head_query.collision_mask = 1
	if not space.intersect_point(head_query).is_empty():
		return 0
	_player.global_position = feet + Vector3.UP * 0.02
	_player.reset_physics_interpolation()
	_camera.snap_to_target()
	await _frames(2)
	_camera.snap_to_target()
	var eye: Vector3 = _camera.global_position
	var distance: float = eye.distance_to(feet)
	var visible: bool = false
	for height: float in [0.3, 0.6, 0.95]:
		if not _blocked(space, eye, feet + Vector3.UP * height):
			visible = true
			break
	if not visible:
		problems.append("%s: player hidden (camera %.1f m away, key %s)" % [label, distance, _camera._debug_key_a])
	elif distance < MIN_DISTANCE:
		problems.append("%s: camera jammed %.1f m from the player (key %s)" % [label, distance, _camera._debug_key_a])
	return 1


## True if solid, non-fading geometry blocks the line (objects that fade out when occluding don't count).
func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var exclude: Array[RID] = [_player.get_rid()]
	for attempt: int in 8:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | 128, exclude)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit["collider"]
		if collider is Node and (collider as Node).is_in_group("camera_fade"):
			exclude.append(hit["rid"])
			continue
		return true
	return false
