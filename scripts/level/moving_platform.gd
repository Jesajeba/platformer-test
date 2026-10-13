@tool
class_name MovingPlatform
extends AnimatableBody3D
## Platform that travels back and forth between its start position and start + `travel`,
## pausing at each end. The player rides it automatically (AnimatableBody3D + sync_to_physics).

@export_group("Block")
@export var shape_type: GreyboxBlock.ShapeType = GreyboxBlock.ShapeType.BOX:
	set(value):
		shape_type = value
		_rebuild()
@export var size: Vector3 = Vector3(3.0, 0.6, 3.0):
	set(value):
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()
@export var top_material: Material:
	set(value):
		top_material = value
		_rebuild()

@export_group("Motion")
## Offset (in parent space) from the start position to the far end.
@export var travel: Vector3 = Vector3(6.0, 0.0, 0.0)
## Seconds for one full trip there and back, excluding pauses.
@export var cycle_time: float = 5.0
## Pause at each end, in seconds.
@export var pause_time: float = 0.6
## Where in the cycle the platform starts (0..1).
@export_range(0.0, 1.0) var start_phase: float = 0.0

var _origin: Vector3
var _time: float = 0.0
var _visual: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()
	_origin = position
	sync_to_physics = true
	_time = start_phase * _total_cycle()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time = fmod(_time + delta, _total_cycle())
	position = _origin + travel * _travel_fraction(_time)


## 0..1 position along `travel` at time `t` in the cycle (eased, with pauses at both ends).
func _travel_fraction(t: float) -> float:
	var move_time: float = maxf(cycle_time * 0.5, 0.01)
	var leg: float = move_time + pause_time
	if t < leg:
		return 0.0 if t < pause_time else _ease((t - pause_time) / move_time)
	t -= leg
	return 1.0 if t < pause_time else 1.0 - _ease((t - pause_time) / move_time)


func _total_cycle() -> float:
	return maxf(cycle_time, 0.02) + pause_time * 2.0


func _ease(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = GreyboxBlock.build_visual(shape_type, size, material, top_material, 0.12)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	_collision.shape = GreyboxBlock.build_shape(shape_type, size)
