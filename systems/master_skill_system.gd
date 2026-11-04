class_name MasterSkillSystem
extends Node
## 마스터 마나/쿨다운 관리 + 스킬 발동. EventBus 전용 통신.

const STATE_EMIT_INTERVAL: float = 0.1

@export var config: MasterConfig
@export var recall_point: Marker2D

var mana: float = 0.0

var _cooldowns: PackedFloat32Array = PackedFloat32Array()
var _emit_acc: float = 0.0


func _ready() -> void:
	assert(config != null, "MasterSkillSystem: config 필요")
	mana = config.start_mana
	_cooldowns.resize(config.skills.size())
	_cooldowns.fill(0.0)
	EventBus.master_skill_requested.connect(try_cast)
	_announce.call_deferred()


func _announce() -> void:
	EventBus.master_skills_ready.emit(config.skills)
	_emit_state()


func _process(delta: float) -> void:
	mana = minf(config.max_mana, mana + config.mana_regen * delta)
	for i: int in _cooldowns.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
	_emit_acc -= delta
	if _emit_acc <= 0.0:
		_emit_acc = STATE_EMIT_INTERVAL
		_emit_state()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	for i: int in config.skills.size():
		if config.skills[i].hotkey == k.keycode:
			try_cast(i)
			get_viewport().set_input_as_handled()
			return


func can_cast(index: int) -> bool:
	if index < 0 or index >= config.skills.size():
		return false
	return _cooldowns[index] <= 0.0 and mana >= config.skills[index].mana_cost


func try_cast(index: int) -> void:
	if not can_cast(index):
		return
	var skill: MasterSkillData = config.skills[index]
	mana -= skill.mana_cost
	_cooldowns[index] = skill.cooldown
	if skill.kind == MasterSkillData.Kind.RECALL:
		var pos: Vector2 = recall_point.global_position if recall_point else Vector2.ZERO
		EventBus.pin_commit_requested.emit(PinTypes.Type.RETREAT, pos)
	EventBus.master_skill_cast.emit(skill)
	_emit_state()


func _emit_state() -> void:
	EventBus.master_state_changed.emit(mana, config.max_mana, _cooldowns)
