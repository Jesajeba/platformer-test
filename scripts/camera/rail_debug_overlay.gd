class_name RailDebugOverlay
extends Node
## Debug view for a RailCamera, toggled with the `debug_toggle` action (F3).
## Draws the rail curve, the key points, the player's projected point and the
## camera's rail position (through walls), plus a text readout of blend values.

@export var camera: RailCamera
@export var enabled: bool = false:
	set(value):
		enabled = value
		_apply_enabled()

@export_group("Colors")
@export var curve_color: Color = Color(0.2, 0.9, 1.0)
@export var key_color: Color = Color(1.0, 0.65, 0.1)
@export var active_key_color: Color = Color(1.0, 1.0, 0.2)
@export var locked_key_color: Color = Color(1.0, 0.25, 0.25)
@export var projected_color: Color = Color(1.0, 0.2, 1.0)
@export var camera_point_color: Color = Color(0.3, 1.0, 0.3)

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _mesh_instance: MeshInstance3D
var _layer: CanvasLayer
var _label: Label


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.top_level = true
	add_child(_mesh_instance)

	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -440.0
	_label.offset_top = 12.0
	_label.offset_right = -16.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_label)
	_apply_enabled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = not enabled
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not enabled or camera == null or camera.rail == null or camera.rail.curve == null:
		return
	_label.text = camera.get_debug_text()
	_redraw()


func _apply_enabled() -> void:
	if _mesh_instance == null:
		return
	_mesh_instance.visible = enabled
	_layer.visible = enabled
	if not enabled:
		_mesh.clear_surfaces()


func _redraw() -> void:
	var rail: Path3D = camera.rail
	var curve: Curve3D = rail.curve
	var xform: Transform3D = rail.global_transform
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Rail curve.
	var points: PackedVector3Array = curve.get_baked_points()
	for i: int in range(1, points.size()):
		_line(xform * points[i - 1], xform * points[i], curve_color)

	# Key points: vertical post, brighter for the keys currently being blended.
	var keys: Array[RailCameraKey] = camera.get_keys()
	var offsets: PackedFloat32Array = camera.get_key_offsets()
	var progress: float = camera.get_progress()
	for i: int in keys.size():
		var base: Vector3 = xform * curve.sample_baked(offsets[i], true)
		var active: bool = offsets[i] <= progress and (i == keys.size() - 1 or offsets[i + 1] > progress)
		active = active or (i > 0 and offsets[i - 1] <= progress and offsets[i] > progress and camera.get_debug_blend() > 0.0)
		var color: Color = locked_key_color if keys[i].locked else key_color
		if active:
			color = active_key_color
		_line(base, base + Vector3.UP * 3.0, color)
		_cross(base + Vector3.UP * 3.0, 0.4, color)
		if keys[i].locked and keys[i].lock_camera_point != null:
			_line(base + Vector3.UP * 3.0, keys[i].lock_camera_point.global_position, locked_key_color)
			_cross(keys[i].lock_camera_point.global_position, 0.6, locked_key_color)

	# Player's projected point on the rail, and the camera's own rail position.
	var target_point: Vector3 = xform * curve.sample_baked(camera.get_target_progress(), true)
	if camera.target != null:
		_line(camera.target.global_position, target_point, projected_color)
	_cross(target_point, 0.5, projected_color)
	var camera_point: Vector3 = xform * curve.sample_baked(progress, true)
	_cross(camera_point, 0.7, camera_point_color)
	_line(camera_point, camera.global_position, camera_point_color)

	_mesh.surface_end()


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)


func _cross(center: Vector3, size: float, color: Color) -> void:
	_line(center - Vector3(size, 0, 0), center + Vector3(size, 0, 0), color)
	_line(center - Vector3(0, size, 0), center + Vector3(0, size, 0), color)
	_line(center - Vector3(0, 0, size), center + Vector3(0, 0, size), color)
