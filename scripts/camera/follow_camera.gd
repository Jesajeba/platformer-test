class_name FollowCamera
extends Camera3D
## Temporary fixed-angle follow camera for Stage 1 testing.
## Replaced by the rail camera in Stage 2.

@export var target: Node3D

@export_group("Follow")
@export var offset: Vector3 = Vector3(0.0, 5.5, 9.0)
@export var look_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var follow_speed: float = 6.0


func _ready() -> void:
	top_level = true
	snap_to_target()


## Jumps straight to the follow position (use after teleports).
func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_position + offset
	look_at(target.global_position + look_offset)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = target.global_position + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	look_at(target.global_position + look_offset)
