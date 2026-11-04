extends Node2D
## 전투 테스트 아레나: 네비 폴리곤 런타임 베이크(StaticBody2D 장애물 자동 파싱) + 미션 구성.

const FLOOR_COLOR: Color = Color(0.122, 0.114, 0.141)

## 씬 재시작 간 선택 유지
static var selected_mission: int = 0

@export var arena_rect: Rect2 = Rect2(80.0, 120.0, 1760.0, 900.0)
@export var agent_radius: float = 18.0
@export var missions: Array[MissionData] = []

@onready var _nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var _units: Node2D = $Units
@onready var _defend_zone: Marker2D = $DefendZone
@onready var _spawn_root: Node2D = $SpawnPoints


func _ready() -> void:
	_bake_nav()
	EventBus.mission_restart_requested.connect(_on_restart_requested)
	_start_mission.call_deferred()


func _bake_nav() -> void:
	var np: NavigationPolygon = NavigationPolygon.new()
	np.agent_radius = agent_radius
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 1
	var r: Rect2 = arena_rect
	np.add_outline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	_nav_region.navigation_polygon = np
	_nav_region.bake_navigation_polygon(false)


func _start_mission() -> void:
	assert(not missions.is_empty(), "CombatArena: missions 필요")
	selected_mission = clampi(selected_mission, 0, missions.size() - 1)
	var m: MissionData = missions[selected_mission]
	if not m.keep_preplaced_enemies:
		for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY):
			var u: UnitBase = n as UnitBase
			u.deactivate()
			u.queue_free()
	var obj: MissionObjective = _create_objective(m)
	obj.name = "Mission"
	obj.setup(m)
	add_child(obj)
	move_child(obj, _units.get_index())
	EventBus.missions_available.emit(missions, selected_mission)


func _create_objective(m: MissionData) -> MissionObjective:
	match m.kind:
		MissionData.Kind.DEFEND:
			var d: DefendObjective = DefendObjective.new()
			var spawns: Array[Vector2] = []
			for c: Node in _spawn_root.get_children():
				spawns.append((c as Node2D).global_position)
			d.configure(_defend_zone.global_position, spawns, _units)
			return d
		_:
			return AnnihilateObjective.new()


func _on_restart_requested(index: int) -> void:
	if index < 0 or index >= missions.size():
		return
	selected_mission = index
	get_tree().reload_current_scene.call_deferred()


func _draw() -> void:
	draw_rect(arena_rect, FLOOR_COLOR)
