class_name LostSprite
extends Pickup
## Special collectible: one of the three Lost Sprites hidden in each level.

@export var sprite_id: int = 1


func _ready() -> void:
	super()
	if GameState.sprite_ids.has(sprite_id):
		_collected = true
		_set_present(false)


func _on_collected(_player: Player) -> void:
	GameState.collect_sprite(sprite_id)
	Fx.puff(get_parent(), global_position, Color(1.0, 0.95, 0.6), 24, 0.3, 5.0, 0.8)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", 0.2, 0.2)


func _on_items_reverted() -> void:
	if _collected and not GameState.sprite_ids.has(sprite_id):
		_collected = false
		_set_present(true)
