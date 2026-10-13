class_name BossNameCard
extends CanvasLayer
## Banner that slides in with the boss's name and title during the intro.

@export var hold_time: float = 1.8

var _panel: ColorRect
var _title: Label
var _subtitle: Label


func _ready() -> void:
	layer = 15
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.03, 0.03, 0.72)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.62
	_panel.offset_top = -70.0
	_panel.offset_bottom = 70.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title = _make_label(64, Color(1.0, 0.85, 0.35))
	_subtitle = _make_label(28, Color(0.95, 0.92, 0.85))
	box.add_child(_title)
	box.add_child(_subtitle)
	_panel.visible = false


func show_card(title: String, subtitle: String, hold: float = -1.0) -> void:
	_title.text = title.to_upper()
	_subtitle.text = subtitle
	_panel.visible = true
	_panel.modulate.a = 0.0
	_title.position.x = -200.0
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold if hold >= 0.0 else hold_time)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void: _panel.visible = false)


func is_showing() -> bool:
	return _panel.visible


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 12)
	return label
