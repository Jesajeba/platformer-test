class_name Checkpoint
extends Area3D
## Activates when the player touches it and becomes the respawn point.
## The player respawns at the `SpawnPoint` child, facing its -Z.

signal activated(checkpoint: Checkpoint)

@export var checkpoint_id: int = 0
@export_group("Visuals")
@export var inactive_material: Material
@export var active_material: Material
@export var bob_height: float = 0.15
@export var spin_speed: float = 1.2

var _active: bool = false
var _time: float = 0.0

@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _crystal: MeshInstance3D = $Crystal
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_crystal.material_override = inactive_material
	_light.visible = false


func _process(delta: float) -> void:
	_time += delta
	_crystal.rotation.y += spin_speed * delta * (3.0 if _active else 1.0)
	_crystal.position.y = 1.9 + sin(_time * 2.0) * bob_height


func is_active() -> bool:
	return _active


func get_spawn_transform() -> Transform3D:
	return _spawn_point.global_transform


func activate() -> void:
	if _active:
		return
	_active = true
	_crystal.material_override = active_material
	_light.visible = true
	var tween: Tween = create_tween()
	_crystal.scale = Vector3(1.8, 1.8, 1.8)
	tween.tween_property(_crystal, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameState.set_checkpoint(get_spawn_transform())
	AudioManager.play_sfx(&"checkpoint", 0.0)
	Fx.puff(get_parent(), _crystal.global_position, Color(0.5, 1.0, 0.6), 14, 0.25, 3.0, 0.6)
	activated.emit(self)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		activate()
