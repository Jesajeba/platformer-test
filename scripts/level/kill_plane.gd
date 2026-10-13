class_name KillPlane
extends Area3D
## Bottomless-pit trigger. Players are sent back to the last checkpoint; anything
## else that falls in is removed.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("fall_out"):
		body.call_deferred("fall_out")
	elif not body is StaticBody3D:
		body.queue_free()
