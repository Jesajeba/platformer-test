@tool
class_name HudIcon
extends Control
## Vector icon drawn in code: heart (full/empty), coin or star.

enum Shape { HEART, COIN, STAR }

@export var shape: Shape = Shape.HEART:
	set(value):
		shape = value
		queue_redraw()
@export var filled: bool = true:
	set(value):
		filled = value
		queue_redraw()
@export var fill_color: Color = Color(1.0, 0.32, 0.45):
	set(value):
		fill_color = value
		queue_redraw()
@export var empty_color: Color = Color(0.18, 0.1, 0.14, 0.55):
	set(value):
		empty_color = value
		queue_redraw()
@export var outline_color: Color = Color(0.12, 0.04, 0.07, 0.95):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 3.0


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _draw() -> void:
	var points: PackedVector2Array
	match shape:
		Shape.HEART:
			points = _heart_points()
		Shape.COIN:
			points = _circle_points(size * 0.5, minf(size.x, size.y) * 0.45, 32)
		Shape.STAR:
			points = _star_points()
	var color: Color = fill_color if filled else empty_color
	draw_colored_polygon(points, color)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline_color, outline_width, true)
	if shape == Shape.COIN:
		draw_polyline(_circle_points(size * 0.5, minf(size.x, size.y) * 0.27, 24), color.darkened(0.25), 2.5, true)
	elif shape == Shape.HEART and filled:
		draw_circle(Vector2(size.x * 0.32, size.y * 0.3), size.x * 0.08, Color(1, 1, 1, 0.55))


func _heart_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var margin: float = outline_width
	for i: int in 48:
		var t: float = TAU * i / 48.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(Vector2(
			margin + (x + 16.0) / 32.0 * (size.x - margin * 2.0),
			margin + (y + 12.0) / 29.0 * (size.y - margin * 2.0)))
	return points


func _circle_points(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in count:
		var angle: float = TAU * i / count
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _star_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = size * 0.5
	var outer: float = minf(size.x, size.y) * 0.48
	for i: int in 10:
		var angle: float = -PI * 0.5 + PI * i / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (outer if i % 2 == 0 else outer * 0.45))
	return points
