class_name TacticalPinSystem
extends Node2D
## 마스터 입력 → 전술 핀 생성 → 분대장 역제안 판정 → 확정 명령 발행.

const BT_SOURCE_INPUT: StringName = &"pin_input"
const BT_SOURCE_PROPOSAL: StringName = &"counter_proposal"
const GROUP_ENEMY: StringName = &"enemies"
const GROUP_LEADER: StringName = &"squad_leader"

@export var ego_config: EgoConfig
@export var path_line: Line2D

var current_type: int = PinTypes.Type.MOVE

var _pins: Array[TacticalPinNode] = []
var _proposal_pin: TacticalPinNode
var _dragging: bool = false
var _pending: bool = false
var _pending_leader: UnitBase
var _pending_original: Vector2
var _pending_proposed: Vector2
var _pending_type: int = PinTypes.Type.MOVE


func _ready() -> void:
	assert(ego_config != null, "TacticalPinSystem: ego_config 필요")
	for i: int in PinTypes.Type.size():
		var pin: TacticalPinNode = TacticalPinNode.new()
		pin.visible = false
		add_child(pin)
		_pins.append(pin)
	_proposal_pin = TacticalPinNode.new()
	_proposal_pin.visible = false
	add_child(_proposal_pin)
	if path_line:
		path_line.visible = false
	EventBus.counter_proposal_decided.connect(_resolve_proposal)
	EventBus.pin_type_selected.connect(set_pin_type)
	EventBus.pin_commit_requested.connect(_force_commit)


func set_pin_type(type: int) -> void:
	if type >= 0 and type < PinTypes.Type.size():
		current_type = type


# ---------------------------------------------------------------- Input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
		return
	if _pending:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_drag(mb.position)
			elif _dragging:
				_end_drag(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _dragging:
			_cancel_drag()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm and _dragging:
		_update_preview(_to_world(mm.position))


func _handle_key(k: InputEventKey) -> void:
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1: EventBus.pin_type_selected.emit(PinTypes.Type.MOVE)
		KEY_2: EventBus.pin_type_selected.emit(PinTypes.Type.FOCUS)
		KEY_3: EventBus.pin_type_selected.emit(PinTypes.Type.RETREAT)
		KEY_Y: EventBus.counter_proposal_decided.emit(true)
		KEY_N: EventBus.counter_proposal_decided.emit(false)


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _begin_drag(screen_pos: Vector2) -> void:
	_dragging = true
	EventBus.bullet_time_requested.emit(BT_SOURCE_INPUT, true)
	_update_preview(_to_world(screen_pos))


func _cancel_drag() -> void:
	_dragging = false
	_pins[current_type].hide_pin()
	if path_line:
		path_line.visible = false
	EventBus.bullet_time_requested.emit(BT_SOURCE_INPUT, false)


func _end_drag(screen_pos: Vector2) -> void:
	_dragging = false
	var pos: Vector2 = _snap_to_nav(_to_world(screen_pos))
	_pins[current_type].show_pin(current_type, pos)
	EventBus.pin_placed.emit(current_type, pos)
	_evaluate(current_type, pos)
	EventBus.bullet_time_requested.emit(BT_SOURCE_INPUT, false)


func _update_preview(world_pos: Vector2) -> void:
	_pins[current_type].show_pin(current_type, world_pos)
	var leader: UnitBase = _get_leader()
	if leader:
		_draw_path(leader.global_position, world_pos, PinTypes.COLORS[current_type])


func _draw_path(from: Vector2, to: Vector2, color: Color) -> void:
	if path_line == null:
		return
	var path: PackedVector2Array = NavigationServer2D.map_get_path(get_world_2d().navigation_map, from, to, true)
	if path.is_empty():
		path = PackedVector2Array([from, to])
	path_line.points = path
	path_line.default_color = Color(color, 0.7)
	path_line.visible = true


# ---------------------------------------------------------------- Ego 판정
var _threat_count: int = 0
var _threat_centroid: Vector2 = Vector2.ZERO


func _evaluate(type: int, pos: Vector2) -> void:
	var leader: UnitBase = _get_leader()
	if leader == null or leader.hero_data == null or type == PinTypes.Type.RETREAT:
		_commit(type, pos)
		return
	_scan_threat(pos)
	var danger: float = clampf(_threat_count * ego_config.danger_per_enemy, 0.0, 1.0)
	var hd: HeroData = leader.hero_data
	var p: float = ego_config.evaluate(danger, hd.fear, hd.loyalty)
	if p <= 0.0 or randf() >= p:
		_commit(type, pos)
		return
	_raise_proposal(leader, type, pos)


func _scan_threat(pos: Vector2) -> void:
	var r2: float = ego_config.danger_radius * ego_config.danger_radius
	var sum: Vector2 = Vector2.ZERO
	_threat_count = 0
	for node: Node in get_tree().get_nodes_in_group(GROUP_ENEMY):
		var e: Node2D = node as Node2D
		if e and e.global_position.distance_squared_to(pos) <= r2:
			sum += e.global_position
			_threat_count += 1
	_threat_centroid = sum / float(_threat_count) if _threat_count > 0 else pos


func _raise_proposal(leader: UnitBase, type: int, original: Vector2) -> void:
	var away: Vector2 = (leader.global_position - _threat_centroid).normalized()
	if away == Vector2.ZERO:
		away = Vector2.LEFT
	var proposed: Vector2 = _snap_to_nav(original + away * ego_config.cover_search_distance)
	_pending = true
	_pending_leader = leader
	_pending_original = original
	_pending_proposed = proposed
	_pending_type = type
	_proposal_pin.show_pin(type, proposed, true)
	_draw_path(leader.global_position, proposed, Color(0.91, 0.89, 0.84))
	EventBus.bullet_time_requested.emit(BT_SOURCE_PROPOSAL, true)
	EventBus.counter_proposal_raised.emit(leader, original, proposed, type)


func _resolve_proposal(accepted: bool) -> void:
	if not _pending:
		return
	_pending = false
	_proposal_pin.hide_pin()
	var leader: UnitBase = _pending_leader
	_pending_leader = null
	if is_instance_valid(leader):
		if accepted:
			leader.change_psyche(&"loyalty", ego_config.accept_loyalty_gain)
			leader.remember("마스터가 내 제안을 받아들였다.")
			EventBus.squad_buff_applied.emit(ego_config.accept_buff_mult, ego_config.accept_buff_duration)
		else:
			leader.change_psyche(&"loyalty", -ego_config.force_loyalty_penalty)
			leader.change_psyche(&"fear", ego_config.force_fear_gain)
			leader.remember("마스터는 내 경고를 무시했다.")
	var final_pos: Vector2 = _pending_proposed if accepted else _pending_original
	_pins[_pending_type].show_pin(_pending_type, final_pos)
	EventBus.counter_proposal_resolved.emit(accepted)
	_commit(_pending_type, final_pos)
	EventBus.bullet_time_requested.emit(BT_SOURCE_PROPOSAL, false)


## 마스터 절대 명령: 역제안 판정 생략, 대기 중 역제안은 무효화.
func _force_commit(type: int, pos: Vector2) -> void:
	if _dragging:
		_cancel_drag()
	if _pending:
		_pending = false
		_pending_leader = null
		_proposal_pin.hide_pin()
		EventBus.counter_proposal_resolved.emit(false)
		EventBus.bullet_time_requested.emit(BT_SOURCE_PROPOSAL, false)
	var p: Vector2 = _snap_to_nav(pos)
	_pins[type].show_pin(type, p)
	_commit(type, p)


func _commit(type: int, pos: Vector2) -> void:
	var leader: UnitBase = _get_leader()
	if leader:
		_draw_path(leader.global_position, pos, PinTypes.COLORS[type])
	EventBus.pin_committed.emit(type, pos)


# ---------------------------------------------------------------- Util
func _get_leader() -> UnitBase:
	return get_tree().get_first_node_in_group(GROUP_LEADER) as UnitBase


func _snap_to_nav(pos: Vector2) -> Vector2:
	var map: RID = get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return pos
	return NavigationServer2D.map_get_closest_point(map, pos)
