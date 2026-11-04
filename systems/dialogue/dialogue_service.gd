class_name DialogueService
extends Node
## 전투 이벤트 → 화자 선정 → Provider 대사 요청 → EventBus.hero_spoke + 유닛 말풍선.
## 역제안/결정/승패 대사는 쿨다운 무시, 동료 사망은 전역 쿨다운만 무시.

const PIN_NAMES: PackedStringArray = ["집결", "일점사", "후퇴"]

@export var config: DialogueConfig

var provider: DialogueProvider

var _last_by_speaker: Dictionary = {}  ## instance_id -> msec
var _last_global: int = -1000000
var _proposal_leader: UnitBase


func _ready() -> void:
	assert(config != null, "DialogueService: config 필요")
	provider = _build_provider()
	EventBus.counter_proposal_raised.connect(_on_proposal_raised)
	EventBus.counter_proposal_resolved.connect(_on_proposal_resolved)
	EventBus.counter_proposal_cancelled.connect(_on_proposal_cancelled)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.mission_started.connect(_on_mission_started)
	EventBus.mission_ended.connect(_on_mission_ended)
	EventBus.master_skill_cast.connect(_on_skill_cast)


func _build_provider() -> DialogueProvider:
	var template: TemplateDialogueProvider = TemplateDialogueProvider.new()
	template.load_file(config.template_path)
	if config.mode != DialogueConfig.Mode.LLM:
		return template
	var url: String = EnvLoader.get_value(config.proxy_url_env_key)
	if not LLMDialogueProvider.is_allowed_url(url):
		push_warning("DialogueService: %s 미설정/비허용 URL → 템플릿 사용" % config.proxy_url_env_key)
		return template
	return LLMDialogueProvider.new(self, url, config.llm_timeout_sec, config.max_chars, template)


enum Priority { NORMAL, URGENT, CRITICAL }  ## URGENT: 전역 쿨다운 무시, CRITICAL: 모든 쿨다운 무시


## 화자에게 이벤트 대사 요청.
func speak(unit: UnitBase, ev: StringName, vars: Dictionary = {}, priority: Priority = Priority.NORMAL) -> void:
	if not _is_alive(unit):
		return
	if not can_speak(unit, priority):
		return
	var now: int = Time.get_ticks_msec()
	var id: int = unit.get_instance_id()
	_last_global = now
	_last_by_speaker[id] = now
	var ctx: DialogueContext = DialogueContext.from_unit(ev, unit, vars)
	provider.request_line(ctx, _deliver_deferred.bind(unit, ev))


## 동기 Provider도 현재 신호 처리(HUD 팝업 표시 등)가 끝난 뒤 전달되도록 지연.
func can_speak(unit: UnitBase, priority: Priority) -> bool:
	var now: int = Time.get_ticks_msec()
	if priority == Priority.NORMAL and now - _last_global < int(config.global_cooldown_sec * 1000.0):
		return false
	if priority != Priority.CRITICAL \
			and now - int(_last_by_speaker.get(unit.get_instance_id(), -1000000)) < int(config.speaker_cooldown_sec * 1000.0):
		return false
	return true


func _deliver_deferred(text: String, unit: UnitBase, ev: StringName) -> void:
	_deliver.call_deferred(text, unit, ev)


func _deliver(text: String, unit: UnitBase, ev: StringName) -> void:
	if text.is_empty() or not _is_alive(unit):
		return
	unit.say(text, config.bubble_time)
	EventBus.hero_spoke.emit(unit, text, ev)


# ---------------------------------------------------------------- 이벤트
func _on_proposal_raised(leader: Node2D, _orig: Vector2, _proposed: Vector2, type: int) -> void:
	_proposal_leader = leader as UnitBase
	var pin: String = PIN_NAMES[type] if type >= 0 and type < PIN_NAMES.size() else "명령"
	speak(_proposal_leader, &"counter_proposal", {"pin": pin}, Priority.CRITICAL)


func _on_proposal_resolved(accepted: bool) -> void:
	var leader: UnitBase = _proposal_leader
	_proposal_leader = null
	speak(leader, &"proposal_accepted" if accepted else &"proposal_forced", {}, Priority.CRITICAL)


func _on_proposal_cancelled() -> void:
	_proposal_leader = null


func _on_unit_died(node: Node2D) -> void:
	var dead: UnitBase = node as UnitBase
	if dead == null or dead.hero_data == null:
		return
	var witness: UnitBase = _nearest_hero(dead.global_position, Priority.URGENT)
	if witness:
		speak(witness, &"ally_died", {"target": dead.stats.display_name}, Priority.URGENT)


func _on_mission_started(title: String, _briefing: String) -> void:
	speak(_leader(), &"mission_start", {"mission": title})


func _on_mission_ended(victory: bool, _reason: String) -> void:
	var u: UnitBase = _leader()
	if u == null:
		u = _nearest_hero(Vector2.ZERO)
	speak(u, &"victory" if victory else &"defeat", {}, Priority.CRITICAL)


func _on_skill_cast(skill: MasterSkillData) -> void:
	match skill.kind:
		MasterSkillData.Kind.COMMAND:
			speak(_leader(), &"skill_command")
		MasterSkillData.Kind.HEAL:
			speak(_nearest_hero(Vector2.ZERO), &"skill_heal")
		MasterSkillData.Kind.RECALL:
			speak(_leader(), &"skill_recall")


# ---------------------------------------------------------------- Util
func _leader() -> UnitBase:
	return UnitRegistry.leader


## priority 지정 시 해당 우선순위로 발화 가능한 영웅만 대상.
func _nearest_hero(from: Vector2, priority: Priority = Priority.CRITICAL) -> UnitBase:
	var best: UnitBase = null
	var best_d: float = INF
	for u: UnitBase in UnitRegistry.allies:
		if u.hero_data == null or not can_speak(u, priority):
			continue
		var d: float = from.distance_squared_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func _is_alive(u: UnitBase) -> bool:
	return u != null and is_instance_valid(u) and not u.is_dead()
