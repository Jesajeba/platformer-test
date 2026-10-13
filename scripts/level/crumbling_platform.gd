@tool
class_name CrumblingPlatform
extends StaticBody3D
## Platform that shakes when the player lands on it, falls away after `crumble_delay`,
## and reappears after `respawn_time`.

signal crumbled
signal restored

enum Phase { SOLID, SHAKING, FALLEN }

@export_group("Block")
@export var size: Vector3 = Vector3(2.5, 0.6, 2.5):
	set(value):
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

@export_group("Crumble")
@export var crumble_delay: float = 0.6
@export var shake_strength: float = 0.06
@export var fall_distance: float = 4.0
@export var fall_duration: float = 0.5
@export var respawn_time: float = 3.0

var _phase: Phase = Phase.SOLID
var _timer: float = 0.0
var _visual: Node3D
var _collision: CollisionShape3D
var _detector: Area3D
var _detector_shape: CollisionShape3D
var _tween: Tween


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_detector.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _phase:
		Phase.SHAKING:
			_timer -= delta
			_visual.position = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * shake_strength
			if _timer <= 0.0:
				_fall()
		Phase.FALLEN:
			_timer -= delta
			if _timer <= 0.0:
				if _detector.get_overlapping_bodies().any(func(b: Node3D) -> bool: return b is Player):
					_timer = 0.5  # Don't reappear inside the player.
				else:
					_restore()


func get_phase() -> Phase:
	return _phase


func _on_body_entered(body: Node3D) -> void:
	if _phase == Phase.SOLID and body is Player:
		_phase = Phase.SHAKING
		_timer = crumble_delay


func _fall() -> void:
	_phase = Phase.FALLEN
	_timer = respawn_time
	_collision.set_deferred("disabled", true)
	_visual.position = Vector3.ZERO
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_visual, "position:y", -fall_distance, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_visual, "scale", Vector3(0.6, 0.6, 0.6), fall_duration)
	_tween.chain().tween_callback(func() -> void: _visual.visible = false)
	crumbled.emit()


func _restore() -> void:
	_phase = Phase.SOLID
	_collision.set_deferred("disabled", false)
	if _tween != null:
		_tween.kill()
	_visual.visible = true
	_visual.position = Vector3.ZERO
	_visual.scale = Vector3(0.2, 0.2, 0.2)
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	restored.emit()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = GreyboxBlock.build_visual(GreyboxBlock.ShapeType.BOX, size, material)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	_collision.shape = GreyboxBlock.build_shape(GreyboxBlock.ShapeType.BOX, size)

	# Detector: a thin volume on top of the platform that notices the player standing on it.
	if _detector == null:
		_detector = Area3D.new()
		_detector.collision_layer = 0
		_detector.collision_mask = 2
		_detector.monitorable = false
		add_child(_detector, false, Node.INTERNAL_MODE_FRONT)
		_detector_shape = CollisionShape3D.new()
		_detector.add_child(_detector_shape)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x - 0.1, 0.4, size.z - 0.1)
	_detector_shape.shape = box
	_detector_shape.position.y = size.y * 0.5 + 0.2
