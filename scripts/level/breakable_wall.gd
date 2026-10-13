@tool
class_name BreakableWall
extends StaticBody3D
## Wall that breaks after a number of player attacks.
## Stage 5 adds debris, particles and sound; this version shakes and shrinks away.

signal broken

@export_group("Wall")
@export var size: Vector3 = Vector3(4.0, 3.0, 1.0):
	set(value):
		size = value.max(Vector3(0.1, 0.1, 0.1))
		_apply_size()
@export var hits_to_break: int = 2

@export_group("Feedback")
@export var shake_strength: float = 0.08
@export var shake_duration: float = 0.15
@export var break_duration: float = 0.2

var _hits_left: int = 0
var _shake_timer: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _mesh_instance: MeshInstance3D = $Visual/MeshInstance3D
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_hits_left = hits_to_break
	_apply_size()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _shake_timer <= 0.0:
		return
	_shake_timer = maxf(_shake_timer - delta, 0.0)
	var strength: float = shake_strength * (_shake_timer / maxf(shake_duration, 0.001))
	_visual.position = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * strength


func take_hit(damage: int, _source_position: Vector3, _knockback: float) -> void:
	if _hits_left <= 0:
		return
	_hits_left -= damage
	if _hits_left <= 0:
		_break()
	else:
		_shake_timer = shake_duration


func _break() -> void:
	_collision.set_deferred("disabled", true)
	broken.emit()
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.2, 0.05, 1.2), break_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _apply_size() -> void:
	if not is_node_ready():
		return
	var mesh: BoxMesh = _mesh_instance.mesh as BoxMesh
	if mesh != null:
		mesh.size = size
	var shape: BoxShape3D = _collision.shape as BoxShape3D
	if shape != null:
		shape.size = size
