extends Node2D
## 전투 테스트 아레나: 네비 폴리곤 런타임 베이크(StaticBody2D 장애물 자동 파싱).

const FLOOR_COLOR: Color = Color(0.122, 0.114, 0.141)

@export var arena_rect: Rect2 = Rect2(80.0, 120.0, 1760.0, 900.0)
@export var agent_radius: float = 18.0

@onready var _nav_region: NavigationRegion2D = $NavigationRegion2D


func _ready() -> void:
	var np: NavigationPolygon = NavigationPolygon.new()
	np.agent_radius = agent_radius
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 1
	var r: Rect2 = arena_rect
	np.add_outline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	_nav_region.navigation_polygon = np
	_nav_region.bake_navigation_polygon(false)


func _draw() -> void:
	draw_rect(arena_rect, FLOOR_COLOR)
