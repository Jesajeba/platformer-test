class_name UiFactory
extends RefCounted
## Small helpers for building menus in code with the project theme.


## A full-screen dimmer with a centered panel; returns the panel's content VBox.
static func centered_panel(parent: Control, min_size: Vector2, dim: float = 0.55) -> VBoxContainer:
	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0, 0, 0, dim)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dimmer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


static func title(text: String, font_size: int = 48, color: Color = Color(1.0, 0.85, 0.35)) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 12)
	return label


static func label(text: String, font_size: int = 24) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	return result


static func button(text: String, on_pressed: Callable, min_width: float = 320.0) -> Button:
	var result: Button = Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(min_width, 56)
	result.pressed.connect(on_pressed)
	return result


## Links focus_neighbor_top/bottom in a vertical list (wrapping), skipping nothing.
static func chain_focus_vertical(controls: Array[Control]) -> void:
	for i: int in controls.size():
		var previous: Control = controls[(i - 1 + controls.size()) % controls.size()]
		var next: Control = controls[(i + 1) % controls.size()]
		controls[i].focus_neighbor_top = controls[i].get_path_to(previous)
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(next)


## If nothing has focus (e.g. after a mouse click) and a menu direction/confirm is pressed on
## keyboard or gamepad, focuses `fallback` so navigation picks up again. Returns true if it did.
static func recover_focus(event: InputEvent, fallback: Control) -> bool:
	if fallback == null or not fallback.is_visible_in_tree():
		return false
	var owner_control: Control = fallback.get_viewport().gui_get_focus_owner()
	if owner_control != null and owner_control.is_visible_in_tree():
		return false
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"]:
		if event.is_action_pressed(action):
			fallback.grab_focus()
			return true
	return false


## Focuses the first enabled button (call when a menu opens).
static func focus_first(controls: Array[Control]) -> void:
	for control: Control in controls:
		if control.is_visible_in_tree() and not (control is BaseButton and (control as BaseButton).disabled):
			control.grab_focus()
			return
