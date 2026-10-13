class_name LevelGoal
extends Area3D
## End-of-level trigger. Stage 7 hooks the results screen onto GameState.level_completed.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		GameState.complete_level()
