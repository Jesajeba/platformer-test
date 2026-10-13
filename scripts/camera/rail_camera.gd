class_name RailCamera
extends Camera3D
## Camera that rides a Path3D rail alongside the player.
##
## Each physics frame it finds the closest point on the rail to the player, moves its
## own progress along the rail toward it (damped, speed-limited, lag-limited), and
## builds a pose from the RailCameraKey children of the rail, blending between the
## two keys around the current progress. A sphere cast from the player keeps the
## camera out of walls.

@export var rail: Path3D
@export var target: Node3D

@export_group("Rail Following")
## How quickly progress along the rail catches up with the player (higher = tighter).
@export var rail_follow_rate: float = 6.0
## Maximum speed of the camera along the rail, in m/s.
@export var rail_max_speed: float = 25.0
## The camera never trails (or leads) the player's rail position by more than this. 0 = no limit.
@export var max_lag_distance: float = 6.0
@export var allow_backward: bool = true
## When backward movement is disabled: how far back from its furthest point the camera may still go.
@export var max_backtrack: float = 0.0

@export_group("Smoothing")
## Pose smoothing rate when the Camera Smoothing setting is 0 (snappy).
@export var smoothing_rate_snappy: float = 18.0
## Pose smoothing rate when the Camera Smoothing setting is 1 (floaty).
@export var smoothing_rate_floaty: float = 4.0

@export_group("Collision")
@export var collision_enabled: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_radius: float = 0.3
## Extra distance kept between the camera and the surface it hit.
@export var collision_margin: float = 0.2
## Closest the camera is pulled in toward the player.
@export var collision_min_distance: float = 1.0
## How fast the camera moves back out once the obstruction is gone, in m/s.
@export var collision_recover_speed: float = 10.0
## Height above the player's feet the collision cast starts from.
@export var collision_pivot_height: float = 1.0

@export_group("Shake")
@export var shake_max_offset: float = 0.35
@export var shake_max_roll_degrees: float = 2.0
@export var shake_frequency: float = 22.0
## Shake applied automatically when the target emits `damaged`.
@export var damage_shake_strength: float = 0.5
@export var damage_shake_duration: float = 0.25

class Pose:
	var position: Vector3
	var look: Vector3
	var fov: float
	var pitch: float
	## 1 = fixed shot (locked key / override): no spring-arm collision.
	var fixed: float = 0.0

	func blend(other: Pose, weight: float) -> Pose:
		var result: Pose = Pose.new()
		result.position = position.lerp(other.position, weight)
		result.look = look.lerp(other.look, weight)
		result.fov = lerpf(fov, other.fov, weight)
		result.pitch = lerpf(pitch, other.pitch, weight)
		result.fixed = lerpf(fixed, other.fixed, weight)
		return result

var _keys: Array[RailCameraKey] = []
var _key_offsets: PackedFloat32Array = PackedFloat32Array()
var _fallback_key: RailCameraKey

var _progress: float = 0.0
var _target_progress: float = 0.0
var _furthest_progress: float = 0.0
var _pose: Pose = Pose.new()
var _arm_length: float = 1.0e6
var _collided: bool = false
var _collision_shape: SphereShape3D = SphereShape3D.new()

var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0
var _shake_clock: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()

var _override_active: bool = false
var _override_pose: Pose = Pose.new()

var _debug_key_a: String = ""
var _debug_key_b: String = ""
var _debug_blend: float = 0.0


func _ready() -> void:
	top_level = true
	_fallback_key = RailCameraKey.new()
	_noise.frequency = 1.0
	refresh_keys()
	if target != null and target.has_signal("teleported"):
		target.connect("teleported", snap_to_target)
	if target != null and target.has_signal("damaged"):
		target.connect("damaged", func(_amount: int) -> void: shake(damage_shake_strength, damage_shake_duration))
	snap_to_target()


func _exit_tree() -> void:
	if _fallback_key != null and not _fallback_key.is_inside_tree():
		_fallback_key.free()
		_fallback_key = null


func _physics_process(delta: float) -> void:
	if not _is_ready_to_track():
		return
	_update_progress(delta)
	var desired: Pose = _override_pose if _override_active else _compute_pose(_progress)
	var weight: float = 1.0 - exp(-_smoothing_rate() * delta)
	_pose = _pose.blend(desired, weight)
	_apply_pose(_pose, delta)
	_apply_shake(delta)


#region Public API

## Re-reads the RailCameraKey children of the rail (call after adding/moving keys at runtime).
func refresh_keys() -> void:
	_keys.clear()
	_key_offsets = PackedFloat32Array()
	if rail == null or rail.curve == null:
		return
	var pairs: Array = []
	for child: Node in rail.get_children():
		if child is RailCameraKey:
			var key: RailCameraKey = child
			pairs.append([rail.curve.get_closest_offset(rail.to_local(key.global_position)), key])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair: Array in pairs:
		_key_offsets.append(pair[0])
		_keys.append(pair[1])


## Jumps straight to the correct position for the target (use after teleports/respawns).
func snap_to_target() -> void:
	if not _is_ready_to_track():
		return
	_target_progress = _closest_offset()
	_progress = _target_progress
	_furthest_progress = _progress
	_pose = _compute_pose(_progress)
	_arm_length = 1.0e6
	_apply_pose(_pose, 0.0)
	reset_physics_interpolation()


## Shakes the camera. Strength is 0..1 (scaled by the Shake export group). Respects the screen-shake setting.
func shake(strength: float = 0.5, duration: float = 0.3) -> void:
	if not SettingsManager.screen_shake or duration <= 0.0:
		return
	if _shake_time_left > 0.0:
		strength = maxf(strength, _current_shake_amount())
	_shake_strength = clampf(strength, 0.0, 1.0)
	_shake_duration = duration
	_shake_time_left = duration


## Takes the camera off the rail to a fixed shot (cutscenes, boss intro). It blends there smoothly.
func set_override(camera_position: Vector3, look_point: Vector3, override_fov: float = 50.0) -> void:
	_override_pose = Pose.new()
	_override_pose.position = camera_position
	_override_pose.look = look_point
	_override_pose.fov = override_fov
	_override_pose.pitch = 0.0
	_override_pose.fixed = 1.0
	_override_active = true


## Returns the camera to the rail (blending back).
func clear_override() -> void:
	_override_active = false


func has_override() -> bool:
	return _override_active


func get_progress() -> float:
	return _progress


func get_target_progress() -> float:
	return _target_progress


func get_keys() -> Array[RailCameraKey]:
	return _keys


func get_key_offsets() -> PackedFloat32Array:
	return _key_offsets


func get_debug_text() -> String:
	var length: float = rail.curve.get_baked_length() if rail != null and rail.curve != null else 0.0
	var lines: PackedStringArray = PackedStringArray([
		"RAIL CAMERA (F3)",
		"Progress: %.1f / %.1f m   (player at %.1f)" % [_progress, length, _target_progress],
		"Keys: %s -> %s   blend %.2f" % [_debug_key_a, _debug_key_b if _debug_key_b != "" else "-", _debug_blend],
		"FOV: %.1f   Pitch: %.1f" % [_pose.fov, _pose.pitch],
		"Collision: %s   arm %.1f m" % ["HIT" if _collided else "clear", minf(_arm_length, 999.0)],
		"Shake: %.2f   (setting %s)" % [_current_shake_amount(), "on" if SettingsManager.screen_shake else "off"],
	])
	for i: int in _keys.size():
		lines.append("  [%d] %s @ %.1f m%s" % [i, _keys[i].name, _key_offsets[i], "  LOCKED" if _keys[i].locked else ""])
	return "\n".join(lines)


func get_debug_blend() -> float:
	return _debug_blend

#endregion


#region Rail tracking

func _is_ready_to_track() -> bool:
	return rail != null and rail.curve != null and rail.curve.point_count >= 2 and target != null and is_inside_tree()


func _closest_offset() -> float:
	return rail.curve.get_closest_offset(rail.to_local(target.global_position))


func _update_progress(delta: float) -> void:
	var goal: float = _closest_offset()
	if not allow_backward:
		goal = maxf(goal, _furthest_progress - max_backtrack)
	_target_progress = goal

	var desired: float = lerpf(_progress, goal, 1.0 - exp(-rail_follow_rate * delta))
	var max_step: float = rail_max_speed * delta
	_progress += clampf(desired - _progress, -max_step, max_step)
	if max_lag_distance > 0.0:
		_progress = clampf(_progress, goal - max_lag_distance, goal + max_lag_distance)
	_progress = clampf(_progress, 0.0, rail.curve.get_baked_length())
	_furthest_progress = maxf(_furthest_progress, _progress)


## Returns [origin, forward, right] of the rail at `offset`, in global space. Forward is flattened.
func _rail_frame(offset: float) -> Array[Vector3]:
	var curve: Curve3D = rail.curve
	var length: float = curve.get_baked_length()
	var xform: Transform3D = rail.global_transform
	var origin: Vector3 = xform * curve.sample_baked(offset, true)
	var ahead: Vector3 = xform * curve.sample_baked(minf(offset + 0.5, length), true)
	var behind: Vector3 = xform * curve.sample_baked(maxf(offset - 0.5, 0.0), true)
	var forward: Vector3 = ahead - behind
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	return [origin, forward, right]

#endregion


#region Pose

func _compute_pose(offset: float) -> Pose:
	var frame: Array[Vector3] = _rail_frame(offset)
	var key_a: RailCameraKey = _fallback_key
	var key_b: RailCameraKey = null
	var t: float = 0.0

	if not _keys.is_empty():
		var index: int = -1
		for i: int in _keys.size():
			if _key_offsets[i] <= offset:
				index = i
		if index < 0:
			key_a = _keys[0]
		elif index >= _keys.size() - 1:
			key_a = _keys[index]
		else:
			key_a = _keys[index]
			key_b = _keys[index + 1]
			var span: float = maxf(_key_offsets[index + 1] - _key_offsets[index], 0.001)
			var blend_len: float = key_b.blend_in_distance
			if blend_len <= 0.0 or blend_len > span:
				blend_len = span
			t = clampf((offset - (_key_offsets[index + 1] - blend_len)) / blend_len, 0.0, 1.0)

	_debug_key_a = key_a.name if key_a != _fallback_key else "(default)"
	_debug_key_b = key_b.name if key_b != null else ""
	_debug_blend = t

	var pose: Pose = _pose_for_key(key_a, frame)
	if key_b != null and t > 0.0:
		pose = pose.blend(_pose_for_key(key_b, frame), smoothstep(0.0, 1.0, t))
	return pose


func _pose_for_key(key: RailCameraKey, frame: Array[Vector3]) -> Pose:
	var origin: Vector3 = frame[0]
	var forward: Vector3 = frame[1]
	var right: Vector3 = frame[2]
	var player: Vector3 = target.global_position
	var to_player: Vector3 = player - origin

	# The framing anchor follows the rail, plus some of the player's sideways/vertical offset.
	# Look-ahead slides the whole framing forward instead of turning the camera, so the
	# camera's orientation (and therefore camera-relative input) only depends on the key.
	var anchor: Vector3 = origin \
		+ right * to_player.dot(right) * key.lateral_follow \
		+ Vector3.UP * to_player.y * key.vertical_follow \
		+ forward * key.look_ahead

	var pose: Pose = Pose.new()
	pose.fov = key.fov
	pose.pitch = key.pitch_offset_degrees
	if key.locked and key.lock_camera_point != null:
		pose.position = key.lock_camera_point.global_position
		var center: Vector3 = key.lock_look_point.global_position if key.lock_look_point != null else origin
		pose.look = center.lerp(player + Vector3.UP * key.look_height, key.lock_player_look_weight)
		pose.fixed = 1.0
	else:
		pose.position = anchor + right * key.offset.x + Vector3.UP * key.offset.y - forward * key.offset.z
		pose.look = anchor + Vector3.UP * key.look_height
	return pose


func _apply_pose(pose: Pose, delta: float) -> void:
	# Fixed shots (locked keys, overrides) are placed deliberately, so collision fades out for them.
	var position_out: Vector3 = _resolve_collision(pose.position, delta).lerp(pose.position, clampf(pose.fixed, 0.0, 1.0))
	global_position = position_out
	var look_dir: Vector3 = pose.look - position_out
	if look_dir.length_squared() > 0.0001:
		var up: Vector3 = Vector3.UP if absf(look_dir.normalized().y) < 0.999 else Vector3.FORWARD
		look_at(pose.look, up)
	if not is_zero_approx(pose.pitch):
		rotate_object_local(Vector3.RIGHT, deg_to_rad(pose.pitch))
	fov = pose.fov


func _smoothing_rate() -> float:
	return lerpf(smoothing_rate_snappy, smoothing_rate_floaty, SettingsManager.camera_smoothing)

#endregion


#region Collision

## Spring-arm: sphere-cast from the player toward the desired camera position and pull in on hits.
func _resolve_collision(desired: Vector3, delta: float) -> Vector3:
	_collided = false
	if not collision_enabled:
		return desired
	var pivot: Vector3 = target.global_position + Vector3.UP * collision_pivot_height
	var to_camera: Vector3 = desired - pivot
	var distance: float = to_camera.length()
	if distance < 0.01:
		return desired

	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	_collision_shape.radius = collision_radius
	params.shape = _collision_shape
	params.transform = Transform3D(Basis.IDENTITY, pivot)
	params.motion = to_camera
	params.collision_mask = collision_mask
	if target is CollisionObject3D:
		params.exclude = [(target as CollisionObject3D).get_rid()]
	var result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(params)

	var allowed: float = distance
	if result.size() == 2 and result[0] < 1.0:
		_collided = true
		allowed = clampf(distance * result[0] - collision_margin, minf(collision_min_distance, distance), distance)
	# Snap in immediately, ease back out.
	_arm_length = minf(allowed, _arm_length + collision_recover_speed * delta) if delta > 0.0 else allowed
	return pivot + to_camera / distance * minf(_arm_length, distance)

#endregion


#region Shake

func _current_shake_amount() -> float:
	if _shake_time_left <= 0.0 or _shake_duration <= 0.0:
		return 0.0
	var k: float = _shake_time_left / _shake_duration
	return _shake_strength * k * k


func _apply_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	_shake_clock += delta * shake_frequency
	var amount: float = _current_shake_amount()
	h_offset = _noise.get_noise_2d(_shake_clock, 0.0) * shake_max_offset * amount
	v_offset = _noise.get_noise_2d(0.0, _shake_clock) * shake_max_offset * amount
	rotate_object_local(Vector3.FORWARD, deg_to_rad(_noise.get_noise_2d(_shake_clock, 50.0) * shake_max_roll_degrees * amount))

#endregion
