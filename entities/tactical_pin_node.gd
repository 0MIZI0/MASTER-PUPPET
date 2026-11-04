class_name TacticalPinNode
extends Node2D
## 풀링되는 전술 핀 마커 (코드 드로잉).

const RADIUS: float = 22.0

var pin_type: int = PinTypes.Type.MOVE
var is_proposal: bool = false


func show_pin(type: int, world_pos: Vector2, proposal: bool = false) -> void:
	pin_type = type
	is_proposal = proposal
	global_position = world_pos
	visible = true
	queue_redraw()


func hide_pin() -> void:
	visible = false


func _draw() -> void:
	var c: Color = PinTypes.COLORS[pin_type]
	if is_proposal:
		c = Color(0.91, 0.89, 0.84)
		draw_arc(Vector2.ZERO, RADIUS + 8.0, 0.0, TAU, 32, c, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-5.0, -RADIUS - 14.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, c)
	draw_circle(Vector2.ZERO, RADIUS, Color(c, 0.25))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, c, 3.0)
	draw_line(Vector2(0.0, -RADIUS), Vector2(0.0, -RADIUS * 2.2), c, 3.0)
