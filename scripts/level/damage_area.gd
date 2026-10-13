@tool
class_name DamageArea
extends Area3D
## Hurts anything with `take_damage()` that overlaps it. Checks every physics frame,
## so a player standing in it is hit again once their invincibility runs out.

@export_group("Damage")
@export var damage: int = 1


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for body: Node3D in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
