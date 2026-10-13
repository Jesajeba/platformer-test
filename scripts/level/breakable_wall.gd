@tool
class_name BreakableWall
extends StaticBody3D
## Wall that breaks after a number of player attacks.
## Shakes when hit; on breaking it bursts into debris and dust with a sound and a camera shake.

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
@export var debris_color: Color = Color(0.86, 0.8, 0.68)
@export var break_camera_shake: float = 0.35

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


## Called by RailCamera while this wall hides the player.
func set_camera_faded(faded: bool) -> void:
	GreyboxBlock.set_occluder_faded(self, _visual, faded)


func take_hit(damage: int, _source_position: Vector3, _knockback: float) -> void:
	if _hits_left <= 0:
		return
	_hits_left -= damage
	if _hits_left <= 0:
		_break()
	else:
		_shake_timer = shake_duration
		AudioManager.play_sfx(&"stone_hit")
		Fx.chunks(get_parent(), global_position, debris_color, 4, 0.2, 4.0, 0.6, size * 0.4)


func _break() -> void:
	_collision.set_deferred("disabled", true)
	broken.emit()
	var amount: int = clampi(int(size.x * size.y * size.z * 2.5), 10, 40)
	Fx.chunks(get_parent(), global_position, debris_color, amount, 0.32, 7.0, 1.1, size * 0.45)
	Fx.puff(get_parent(), global_position, Color(0.92, 0.88, 0.78), 14, 0.9, 2.5, 0.8)
	AudioManager.play_sfx(&"wall_break")
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", break_camera_shake, 0.25)
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
