class_name BrushStrokeOptimizer

# -------------------------------------------------------------------------------------------------
var points_removed := 0

# -------------------------------------------------------------------------------------------------
func reset() -> void:
	points_removed = 0

# -------------------------------------------------------------------------------------------------
func optimize(s: BrushStroke) -> void:
	if s.points.size() < 3:
		return
	
	var previous_angle := 0.0
	var prev_point: Vector2 = s.points[-2]
	var point: Vector2 = s.points[-1]
	
	if prev_point.distance_to(point) < 0.0000001:
		s.remove_last_point()
		points_removed += 1
