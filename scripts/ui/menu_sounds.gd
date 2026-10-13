class_name MenuSounds
extends RefCounted
## Adds UI sounds to every button and slider under a menu: a tick when focus moves,
## a chime when pressed.


static func wire(root: Node) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		if node is BaseButton:
			var button: BaseButton = node
			button.focus_entered.connect(func() -> void: AudioManager.play_ui(&"ui_move"))
			button.pressed.connect(func() -> void: AudioManager.play_ui(&"ui_select"))
		elif node is Range:
			(node as Range).value_changed.connect(func(_v: float) -> void: AudioManager.play_ui(&"ui_move"))
