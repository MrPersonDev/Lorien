class_name BrushTool
extends CanvasTool

# -------------------------------------------------------------------------------------------------
const MIN_PRESSURE := 0.1

# -------------------------------------------------------------------------------------------------
export var pressure_curve: Curve

# -------------------------------------------------------------------------------------------------
var _current_position: Vector2
var _current_pressure: float
var _last_accepted_position: Vector2
var _first_point := false
var _prev_points: Array # Array<Vector2>

# -------------------------------------------------------------------------------------------------
func tool_event(event: InputEvent) -> void:
	var constant_pressure = 0.375
	_cursor.set_pressure(constant_pressure)
	
	if event is InputEventMouseMotion:
		_current_position = event.position
		_current_pressure = constant_pressure

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				_prev_points.clear()
				start_stroke()
				_first_point = true
			elif !event.pressed && performing_stroke:
				end_stroke()

# -------------------------------------------------------------------------------------------------
func smooth_points(point: Vector2) -> Vector2:
	_prev_points.append(point)
	var average_point := Vector2(0.0, 0.0)
	for p in _prev_points:
		average_point += p
	average_point /= _prev_points.size()
	while _prev_points.size() > Settings.get_value(Settings.GENERAL_POINT_SMOOTHING, Config.DEFAULT_POINT_SMOOTHING):
		_prev_points.pop_front()
	return average_point

# -------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if performing_stroke:
		if _current_pressure <= MIN_PRESSURE:
			return
			
		var sensitivity: float = Settings.get_value(Settings.GENERAL_PRESSURE_SENSITIVITY, Config.DEFAULT_PRESSURE_SENSITIVITY)
		var point_pressure = pressure_curve.interpolate(_current_pressure) * sensitivity
		if _first_point:
			point_pressure *= 1.0
			_first_point = false
		var point_position := xform_vector2(_current_position)
		
		var smoothed_point := smooth_points(point_position)
		add_stroke_point(smoothed_point, point_pressure)
			
		_last_accepted_position = _current_position

