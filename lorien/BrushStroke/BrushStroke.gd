extends Node2D
class_name BrushStroke

# ------------------------------------------------------------------------------------------------
const COLLIDER_NODE_NAME := "StrokeCollider"

# ------------------------------------------------------------------------------------------------
const MAX_LINE_POINTS		:= 1000
const MAX_PRESSURE_VALUE 	:= 255
const MIN_PRESSURE_VALUE 	:= 30
const MAX_PRESSURE_DIFF 	:= 20
const GROUP_ONSCREEN 		:= "onscreen_stroke"

const MAX_VECTOR2 := Vector2(2147483647, 2147483647)
const MIN_VECTOR2 := -MAX_VECTOR2

# ------------------------------------------------------------------------------------------------
onready var _lines: Node2D = $Lines
onready var _visibility_notifier: VisibilityNotifier2D = $VisibilityNotifier2D
var color: Color setget set_color, get_color
var size: int
var points: Array # Array<Vector2>
var smoothed_points: Array # Array<Vector2>
var queued_points : Array # Array<Vector2>
var pressures: Array # Array<float>
var top_left_pos: Vector2
var bottom_right_pos: Vector2

# ------------------------------------------------------------------------------------------------
func _ready():
	refresh()

# ------------------------------------------------------------------------------------------------
func create_line() -> Line2D:
	var _line2d := AntialiasedLine2D.new()
	_lines.add_child(_line2d)
	_line2d.width_curve = Curve.new()
	_line2d.joint_mode = Line2D.LINE_JOINT_ROUND
	_line2d.round_precision = 12
	
	_line2d.default_color = color
	_line2d.width = size
	
	# Anti aliasing
	var aa_mode: int = Settings.get_value(Settings.RENDERING_AA_MODE, Config.DEFAULT_AA_MODE)
	if aa_mode == Types.AAMode.TEXTURE_FILL:
		_line2d.texture = BrushStrokeTexture.texture
		_line2d.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	var rounding_mode: int = Settings.get_value(Settings.RENDERING_BRUSH_ROUNDING, Config.DEFAULT_BRUSH_ROUNDING)
	match rounding_mode:
		Types.BrushRoundingType.FLAT:
			_line2d.end_cap_mode = Line2D.LINE_CAP_NONE
			_line2d.begin_cap_mode = Line2D.LINE_CAP_NONE
		Types.BrushRoundingType.ROUNDED:
			_line2d.end_cap_mode = Line2D.LINE_CAP_ROUND
			_line2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
	
	return _line2d

# ------------------------------------------------------------------------------------------------
func get_line(idx: int) -> Line2D:
	return _lines.get_child(idx) as Line2D

# ------------------------------------------------------------------------------------------------
func last_line() -> Line2D:
	return _lines.get_child(_lines.get_child_count() - 1) as Line2D

# ------------------------------------------------------------------------------------------------
func clear_lines() -> void:
	while _lines.get_child_count() > 0:
		var first_child := _lines.get_child(0)
		_lines.remove_child(first_child)
		first_child.queue_free()

# ------------------------------------------------------------------------------------------------
func _on_VisibilityNotifier2D_viewport_entered(viewport: Viewport) -> void: 
	add_to_group(GROUP_ONSCREEN)
	visible = true
	
# ------------------------------------------------------------------------------------------------
func _on_VisibilityNotifier2D_viewport_exited(viewport: Viewport) -> void:
	remove_from_group(GROUP_ONSCREEN)
	visible = false

# -------------------------------------------------------------------------------------------------
func _to_string() -> String:
	return "Color: %s, Size: %d, Points: %s" % [color, size, points]

# -------------------------------------------------------------------------------------------------
func enable_collider(enable: bool) -> void:
	# Remove current collider
	var collider = get_node_or_null(COLLIDER_NODE_NAME)
	if collider != null:
		remove_child(collider)
		collider.queue_free()
	
	# Create new collider
	if enable:
		var body := StaticBody2D.new()
		body.name = COLLIDER_NODE_NAME
		var idx := 0
		while idx < points.size()-1:
			var col := CollisionShape2D.new()
			var shape := SegmentShape2D.new()
			shape.a = points[idx]
			shape.b = points[idx + 1]
			col.shape = shape
			body.add_child(col)
			idx += 1
		add_child(body)

# -------------------------------------------------------------------------------------------------
func add_point(point: Vector2, pressure: float) -> void:
	var converted_pressure := int(floor(pressure * MAX_PRESSURE_VALUE))
	
	# Smooth out pressure values (on Linux i sometimes get really high pressure spikes)
	if !pressures.empty():
		var last_pressure: int = pressures.back()
		var pressure_diff := converted_pressure - last_pressure
		if abs(pressure_diff) > MAX_PRESSURE_DIFF:
			converted_pressure = last_pressure + sign(pressure_diff) * MAX_PRESSURE_DIFF
	converted_pressure = clamp(converted_pressure, MIN_PRESSURE_VALUE, MAX_PRESSURE_VALUE)
	
	points.append(point)
	queued_points.append(point)
	pressures.append(converted_pressure)

# ------------------------------------------------------------------------------------------------
func remove_last_point() -> void:
	if !points.empty():
		points.pop_back()
		
		if (queued_points.size() > 0):
			queued_points.pop_back()

# ------------------------------------------------------------------------------------------------
func remove_all_points() -> void:
	if !points.empty():
		points.clear()
		queued_points.clear()
		smoothed_points.clear()
		pressures.clear()
		remove_all_points()

# ------------------------------------------------------------------------------------------------
func cubic_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	a *= pow(1 - t, 3)
	b *= 3 * t * pow(1 - t, 2)
	c *= 3 * pow(t, 2) * (1 - t)
	d *= pow(t, 3)
	return a + b + c + d

# ------------------------------------------------------------------------------------------------
func refresh_line(_points: Array, start: int, end: int):
	var _line2d := create_line()
	var max_pressure := float(MAX_PRESSURE_VALUE)
	for i in range(start, end):
		var point: Vector2 = _points[i]
		
		if i+1 < _points.size() && point == _points[i+1]:
			continue
		
		# Add the point
		_line2d.add_point(point)
		
		# Update the extreme values
		top_left_pos.x = min(top_left_pos.x, point.x)
		top_left_pos.y = min(top_left_pos.y, point.y)
		bottom_right_pos.x = max(bottom_right_pos.x, point.x)
		bottom_right_pos.y = max(bottom_right_pos.y, point.y)
	
	_line2d.width_curve.add_point(Vector2(0.0, pressures[0] / max_pressure))
	_line2d.width_curve.bake()

# ------------------------------------------------------------------------------------------------
func refresh() -> void:
	clear_lines()
	
	if points.empty():
		return
	
	top_left_pos = MAX_VECTOR2
	bottom_right_pos = MIN_VECTOR2

	for i in range(0, queued_points.size()-3, 4):
		var a = queued_points[i]
		var b = queued_points[i+1]
		var c = queued_points[i+2]
		var d = queued_points[i+3]
		
		var t: float = 0.0
		while t < 1.0:
			var cur_point := cubic_bezier(a, b, c, d, t)
			if (smoothed_points.size() == 0 || smoothed_points.back().distance_to(cur_point) > 0.01):
				smoothed_points.append(cur_point)
			t += 0.1
		
	queued_points = queued_points.slice((queued_points.size()/4)*4 - queued_points.size()%4 - 1, queued_points.size())
	
	var all_points := smoothed_points + queued_points
	if (all_points.size() <= 3):
		all_points.append(all_points[0] + Vector2(0.001, 0.001))
	for i in range(0, all_points.size(), MAX_LINE_POINTS):
		refresh_line(all_points, max(i-1, 0), min(i+MAX_LINE_POINTS, all_points.size()))
	
	_visibility_notifier.rect = Utils.calculate_rect(top_left_pos, bottom_right_pos)

# -------------------------------------------------------------------------------------------------
func set_color(c: Color) -> void:
	color = c
	
	if _lines != null:
		for line in _lines.get_children():
			line.default_color = color

# -------------------------------------------------------------------------------------------------
func get_color() -> Color:
	return color

# -------------------------------------------------------------------------------------------------
func clear() -> void:
	points.clear()
	queued_points.clear()
	smoothed_points.clear()
	pressures.clear()
	clear_lines()
