class_name UnitBase
extends CharacterBody2D
## 자유 이동 오토배틀 유닛 (영웅/몬스터 공용). NavigationAgent2D RVO 회피.

enum Faction { ALLY, ENEMY }
enum State { IDLE, CHASE, ATTACK, MOVE_TO_PIN, DEAD, MARCH }

## 풀링 유닛: 사망 시 queue_free 대신 발행 → UnitPool 회수
signal despawned(unit: UnitBase)

const GROUP_ALLY: StringName = &"allies"
const GROUP_ENEMY: StringName = &"enemies"
const GROUP_LEADER: StringName = &"squad_leader"
const BODY_RADIUS: float = 16.0
const FLASH_TIME: float = 0.12
const COLOR_ALLY: Color = Color(0.29, 0.53, 0.91)
const COLOR_ENEMY: Color = Color(0.85, 0.22, 0.22)
const COLOR_HP_BG: Color = Color(0.09, 0.086, 0.106)
const COLOR_SHIELD: Color = Color(0.62, 0.78, 0.95)
const BUBBLE_SIZE: Vector2 = Vector2(360, 64)
const BUBBLE_TEXT: Color = Color(0.914, 0.89, 0.843)
const BUBBLE_OUTLINE: Color = Color(0.09, 0.086, 0.106)

@export var data: UnitData
@export var tuning: CombatTuning
@export var faction: Faction = Faction.ENEMY
@export var is_leader: bool = false
@export_range(0, 4) var squad_slot: int = 0

var pooled: bool = false

## tuning 파생 제곱값 캐시 (매 판정 곱셈 제거)
var _repath_sq: float = 0.0
var _arrive_sq: float = 0.0
var _focus_sq: float = 0.0
var _witness_sq: float = 0.0

var stats: UnitData
var hero_data: HeroData
var hp: float = 0.0
var state: State = State.IDLE
var target: UnitBase

var _target_friendly: bool = false
var _forced_target: UnitBase
var _has_order: bool = false
var _pin_type: int = -1
var _pin_pos: Vector2 = Vector2.ZERO
var _nav_goal: Vector2 = Vector2.INF
var _retarget_acc: float = 0.0
var _attack_cd: float = 0.0
var _buff_mult: float = 1.0
var _buff_time: float = 0.0
var _flash_time: float = 0.0
var _flash_to: Vector2 = Vector2.ZERO
var _shield: float = 0.0
var _shield_time: float = 0.0
var _march_goal: Vector2 = Vector2.INF
var _bubble: Label
var _bubble_time: float = 0.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	assert(data != null, "UnitBase: data 필요")
	assert(tuning != null, "UnitBase: tuning 필요")
	_repath_sq = tuning.repath_distance * tuning.repath_distance
	_arrive_sq = tuning.arrive_distance * tuning.arrive_distance
	_focus_sq = tuning.focus_pick_radius * tuning.focus_pick_radius
	_witness_sq = tuning.witness_range * tuning.witness_range
	_init_runtime(1.0)
	agent.velocity_computed.connect(_on_velocity_computed)
	EventBus.unit_died.connect(_on_unit_died)
	if faction == Faction.ALLY:
		EventBus.pin_committed.connect(_on_pin_committed)
		EventBus.squad_buff_applied.connect(_on_buff)
		EventBus.master_skill_cast.connect(_on_master_skill)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_tick_timers(delta)
	_retarget_acc -= delta
	if _retarget_acc <= 0.0:
		_retarget_acc = tuning.retarget_interval
		_think()
	match state:
		State.MOVE_TO_PIN: _process_move_to_pin()
		State.CHASE: _process_chase()
		State.ATTACK: _process_attack()
		State.MARCH: _nav_to(_march_goal)
		_: _set_desired(Vector2.ZERO)


func _init_runtime(hp_mult: float) -> void:
	stats = data.duplicate(true) as UnitData
	stats.max_hp *= hp_mult
	hero_data = stats as HeroData
	hp = stats.max_hp
	state = State.IDLE
	target = null
	_forced_target = null
	_has_order = false
	_march_goal = Vector2.INF
	_nav_goal = Vector2.INF
	_attack_cd = 0.0
	_buff_mult = 1.0
	_buff_time = 0.0
	_shield = 0.0
	_shield_time = 0.0
	_flash_time = 0.0
	agent.max_speed = stats.move_speed
	add_to_group(GROUP_ALLY if faction == Faction.ALLY else GROUP_ENEMY)
	if is_leader:
		add_to_group(GROUP_LEADER)
	UnitRegistry.register(self)
	_retarget_acc = randf() * tuning.retarget_interval
	queue_redraw()


## 풀 재사용: 사망 상태 유닛을 새 데이터로 재가동.
func activate(new_data: UnitData, pos: Vector2, hp_mult: float = 1.0) -> void:
	data = new_data
	global_position = pos
	velocity = Vector2.ZERO
	_init_runtime(hp_mult)
	_shape.set_deferred("disabled", false)
	agent.avoidance_enabled = true
	set_physics_process(true)
	show()


## 목표 없을 때 이동할 지점 (거점 공격 등). Vector2.INF = 해제.
func set_march_goal(pos: Vector2) -> void:
	_march_goal = pos
	_retarget_acc = 0.0


func _exit_tree() -> void:
	UnitRegistry.unregister(self)


# ---------------------------------------------------------------- AI
func _think() -> void:
	if _has_order and _pin_type == PinTypes.Type.RETREAT:
		state = State.MOVE_TO_PIN
		return
	if _is_alive(_forced_target):
		target = _forced_target
		_target_friendly = false
	else:
		_forced_target = null
		target = _find_target()
	if target and _in_range(target):
		state = State.ATTACK
	elif _has_order:
		state = State.MOVE_TO_PIN
	else:
		state = State.CHASE if target else (State.MARCH if _march_goal != Vector2.INF else State.IDLE)


func _find_target() -> UnitBase:
	var aggro_sq: float = stats.aggro_range * stats.aggro_range
	if hero_data and hero_data.role == HeroData.Role.SUPPORT:
		var heal_t: UnitBase = _lowest_hp_ally(aggro_sq)
		if heal_t:
			_target_friendly = true
			return heal_t
	_target_friendly = false
	return _nearest_in(UnitRegistry.opponents_of(faction), global_position, aggro_sq)


func _process_move_to_pin() -> void:
	var goal: Vector2 = _pin_pos + _slot_offset()
	if global_position.distance_squared_to(goal) <= _arrive_sq:
		_has_order = false
		state = State.IDLE
		_retarget_acc = 0.0
		_set_desired(Vector2.ZERO)
		return
	_nav_to(goal)


func _process_chase() -> void:
	if not _is_alive(target):
		_drop_target()
		return
	if _in_range(target):
		state = State.ATTACK
		_set_desired(Vector2.ZERO)
		return
	_nav_to(target.global_position)


func _process_attack() -> void:
	if not _is_alive(target):
		_drop_target()
		return
	if not _in_range(target, tuning.attack_range_slack):
		state = State.CHASE
		return
	_set_desired(Vector2.ZERO)
	if _attack_cd <= 0.0:
		_perform_attack()


func _perform_attack() -> void:
	_attack_cd = stats.attack_interval
	var power: float = stats.attack * _buff_mult
	if _target_friendly:
		target.heal(power)
	else:
		target.take_damage(maxf(tuning.min_damage, power - target.stats.defense), self)
	_flash_to = target.global_position - global_position
	_flash_time = FLASH_TIME
	queue_redraw()


func _drop_target() -> void:
	target = null
	state = State.IDLE
	_retarget_acc = 0.0
	_set_desired(Vector2.ZERO)


# ---------------------------------------------------------------- Movement
func _nav_to(goal: Vector2) -> void:
	if goal.distance_squared_to(_nav_goal) > _repath_sq:
		_nav_goal = goal
		agent.target_position = goal
	if agent.is_navigation_finished():
		_set_desired(Vector2.ZERO)
		return
	_set_desired(global_position.direction_to(agent.get_next_path_position()) * stats.move_speed)


func _set_desired(v: Vector2) -> void:
	if agent.avoidance_enabled:
		agent.velocity = v
	else:
		_on_velocity_computed(v)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if state == State.DEAD:
		return
	velocity = safe_velocity
	move_and_slide()


func _slot_offset() -> Vector2:
	if squad_slot == 0:
		return Vector2.ZERO
	return Vector2.from_angle(TAU * float(squad_slot - 1) / 4.0) * tuning.slot_spacing


# ---------------------------------------------------------------- Combat API
func take_damage(amount: float, _source: UnitBase) -> void:
	if state == State.DEAD:
		return
	if _shield > 0.0:
		var absorbed: float = minf(_shield, amount)
		_shield -= absorbed
		amount -= absorbed
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if state == State.DEAD:
		return
	hp = minf(stats.max_hp, hp + amount)
	queue_redraw()


## 전투 이탈 처리 (신호 없음). 풀 프리웜에서도 사용.
func deactivate() -> void:
	state = State.DEAD
	hp = 0.0
	remove_from_group(GROUP_ALLY)
	remove_from_group(GROUP_ENEMY)
	remove_from_group(GROUP_LEADER)
	UnitRegistry.unregister(self)
	_shape.set_deferred("disabled", true)
	agent.avoidance_enabled = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	if _bubble:
		_bubble.hide()
		_bubble_time = 0.0


## 머리 위 말풍선 (Label 1개 지연 생성·재사용). duration은 게임 시간.
func say(text: String, duration: float) -> void:
	if state == State.DEAD:
		return
	if _bubble == null:
		_bubble = Label.new()
		_bubble.size = BUBBLE_SIZE
		_bubble.position = Vector2(-BUBBLE_SIZE.x * 0.5, -BODY_RADIUS - 12.0 - BUBBLE_SIZE.y)
		_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble.z_index = 10
		_bubble.add_theme_font_size_override(&"font_size", 20)
		_bubble.add_theme_color_override(&"font_color", BUBBLE_TEXT)
		_bubble.add_theme_color_override(&"font_outline_color", BUBBLE_OUTLINE)
		_bubble.add_theme_constant_override(&"outline_size", 6)
		add_child(_bubble)
	_bubble.text = text
	_bubble.show()
	_bubble_time = duration


func is_dead() -> bool:
	return state == State.DEAD


func _die() -> void:
	deactivate()
	EventBus.unit_died.emit(self)
	if pooled:
		hide()
		despawned.emit(self)
	else:
		queue_free()


# ---------------------------------------------------------------- Psyche
func change_psyche(stat: StringName, delta: float) -> void:
	if hero_data == null:
		return
	var v: float = hero_data.modify_stat(stat, delta)
	EventBus.hero_state_changed.emit(self, stat, v)


func remember(entry: String) -> void:
	if hero_data:
		hero_data.add_memory(entry)


# ---------------------------------------------------------------- Signals
func _on_pin_committed(type: int, pos: Vector2) -> void:
	if state == State.DEAD:
		return
	_pin_type = type
	_pin_pos = pos
	_nav_goal = Vector2.INF
	if type == PinTypes.Type.FOCUS:
		_forced_target = _nearest_in(UnitRegistry.enemies, pos, _focus_sq)
		_has_order = _forced_target == null
	else:
		_forced_target = null
		_has_order = true
	_retarget_acc = 0.0


func _on_buff(attack_mult: float, duration: float) -> void:
	_buff_mult = maxf(_buff_mult, attack_mult)
	_buff_time = maxf(_buff_time, duration)


func _on_master_skill(skill: MasterSkillData) -> void:
	if state == State.DEAD:
		return
	match skill.kind:
		MasterSkillData.Kind.HEAL:
			heal(stats.max_hp * skill.magnitude)
		MasterSkillData.Kind.SHIELD:
			_shield = stats.max_hp * skill.magnitude
			_shield_time = skill.duration
			queue_redraw()
		MasterSkillData.Kind.COMMAND:
			_on_buff(skill.magnitude, skill.duration)
	if skill.fear_delta != 0.0:
		change_psyche(&"fear", skill.fear_delta)


func _on_unit_died(node: Node2D) -> void:
	var unit: UnitBase = node as UnitBase
	if unit == null or unit == self:
		return
	if unit == target or unit == _forced_target:
		_retarget_acc = 0.0
	if hero_data and unit.faction == faction \
			and global_position.distance_squared_to(unit.global_position) <= _witness_sq:
		change_psyche(&"fear", tuning.fear_on_ally_death)
		change_psyche(&"sanity", tuning.sanity_on_ally_death)
		remember("%s의 죽음을 목격했다." % unit.stats.display_name)


# ---------------------------------------------------------------- Util
func _tick_timers(delta: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _buff_time > 0.0:
		_buff_time -= delta
		if _buff_time <= 0.0:
			_buff_mult = 1.0
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			queue_redraw()
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.hide()
	if _shield_time > 0.0:
		_shield_time -= delta
		if _shield_time <= 0.0 or _shield <= 0.0:
			_shield_time = 0.0
			_shield = 0.0
			queue_redraw()


func _in_range(t: UnitBase, slack: float = 1.0) -> bool:
	var r: float = (stats.attack_range + BODY_RADIUS * 2.0) * slack
	return global_position.distance_squared_to(t.global_position) <= r * r


func _is_alive(u: UnitBase) -> bool:
	return u != null and is_instance_valid(u) and not u.is_dead()


func _nearest_in(list: Array[UnitBase], from: Vector2, max_dist_sq: float) -> UnitBase:
	var best: UnitBase = null
	var best_d: float = max_dist_sq
	for u: UnitBase in list:
		if u == self:
			continue
		var d: float = from.distance_squared_to(u.global_position)
		if d <= best_d:
			best_d = d
			best = u
	return best


func _lowest_hp_ally(max_dist_sq: float) -> UnitBase:
	var best: UnitBase = null
	var best_ratio: float = tuning.heal_threshold
	for u: UnitBase in UnitRegistry.of_faction(faction):
		if global_position.distance_squared_to(u.global_position) > max_dist_sq:
			continue
		var ratio: float = u.hp / u.stats.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


func _draw() -> void:
	if stats == null:
		return
	var ring: Color = COLOR_ALLY if faction == Faction.ALLY else COLOR_ENEMY
	draw_circle(Vector2.ZERO, BODY_RADIUS, stats.tint)
	draw_arc(Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, ring, 2.5)
	if is_leader:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10, -22), Vector2(-10, -30), Vector2(-5, -26), Vector2(0, -32),
			Vector2(5, -26), Vector2(10, -30), Vector2(10, -22)]), Color(0.92, 0.78, 0.25))
	var w: float = BODY_RADIUS * 2.0
	draw_rect(Rect2(-BODY_RADIUS, BODY_RADIUS + 4.0, w, 4.0), COLOR_HP_BG)
	draw_rect(Rect2(-BODY_RADIUS, BODY_RADIUS + 4.0, w * clampf(hp / stats.max_hp, 0.0, 1.0), 4.0), ring)
	if _shield > 0.0:
		draw_arc(Vector2.ZERO, BODY_RADIUS + 5.0, 0.0, TAU, 32, COLOR_SHIELD, 2.0)
	if _flash_time > 0.0:
		var fc: Color = Color(0.5, 0.95, 0.6) if _target_friendly else Color(0.91, 0.89, 0.84)
		draw_line(Vector2.ZERO, _flash_to, fc, 2.0)
