class_name CombatHUD
extends CanvasLayer
## 전투 HUD: 핀 타입 선택, 역제안 팝업, 분대장 심리 스탯, 불릿 타임 표시. (비네팅 페이드는 BulletTimeController) EventBus 전용 통신.

const GROUP_LEADER: StringName = &"squad_leader"
const SKILL_BUTTON_SIZE: Vector2 = Vector2(125, 96)
const MISSION_BUTTON_SIZE: Vector2 = Vector2(150, 52)

const PROPOSAL_HINT: String = "\n[Y] 승인 (교감 버프)   [N] 강행 (충성도 하락)"

@onready var _type_buttons: Array[Button] = [%BtnMove, %BtnFocus, %BtnRetreat]
@onready var _psyche_label: Label = %PsycheLabel
@onready var _bt_label: Label = %BulletTimeLabel
@onready var _proposal_panel: PanelContainer = %ProposalPanel
@onready var _proposal_text: Label = %ProposalText
@onready var _result_label: Label = %ResultLabel
@onready var _result_box: VBoxContainer = %ResultBox
@onready var _result_reason: Label = %ResultReason
@onready var _mission_buttons: HBoxContainer = %MissionButtons
@onready var _mission_title: Label = %MissionTitle
@onready var _mission_progress: Label = %MissionProgress
@onready var _mission_brief: Label = %MissionBrief
@onready var _mana_label: Label = %ManaLabel
@onready var _mana_bar: ProgressBar = %ManaBar
@onready var _skill_bar: HBoxContainer = %SkillBar

var _skills: Array[MasterSkillData] = []
var _skill_buttons: Array[Button] = []
var _mission_index: int = 0
var _proposal_name: String = ""


func _ready() -> void:
	for i: int in _type_buttons.size():
		_type_buttons[i].pressed.connect(EventBus.pin_type_selected.emit.bind(i))
	(%BtnAccept as Button).pressed.connect(EventBus.counter_proposal_decided.emit.bind(true))
	(%BtnForce as Button).pressed.connect(EventBus.counter_proposal_decided.emit.bind(false))
	EventBus.pin_type_selected.connect(_on_pin_type_selected)
	EventBus.bullet_time_toggled.connect(_on_bullet_time)
	EventBus.counter_proposal_raised.connect(_on_proposal_raised)
	EventBus.counter_proposal_resolved.connect(_on_proposal_resolved)
	EventBus.counter_proposal_cancelled.connect(_proposal_panel.hide)
	EventBus.hero_spoke.connect(_on_hero_spoke)
	EventBus.hero_state_changed.connect(_on_hero_state_changed)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.master_skills_ready.connect(_on_skills_ready)
	EventBus.master_state_changed.connect(_on_master_state)
	EventBus.missions_available.connect(_on_missions_available)
	EventBus.mission_started.connect(_on_mission_started)
	EventBus.mission_progress.connect(_on_mission_progress)
	EventBus.mission_ended.connect(_on_mission_ended)
	(%BtnRetry as Button).pressed.connect(func() -> void: EventBus.mission_restart_requested.emit(_mission_index))
	_on_pin_type_selected(PinTypes.Type.MOVE)
	_refresh_psyche.call_deferred()


func _on_pin_type_selected(type: int) -> void:
	for i: int in _type_buttons.size():
		_type_buttons[i].set_pressed_no_signal(i == type)


func _on_bullet_time(active: bool) -> void:
	_bt_label.visible = active


func _on_proposal_raised(leader: Node2D, _orig: Vector2, _proposed: Vector2, _type: int) -> void:
	var u: UnitBase = leader as UnitBase
	_proposal_name = u.stats.display_name if u else "분대장"
	_proposal_text.text = "%s: …%s" % [_proposal_name, PROPOSAL_HINT]
	_proposal_panel.show()


func _on_hero_spoke(_hero: Node2D, text: String, ev: StringName) -> void:
	if ev == &"counter_proposal" and _proposal_panel.visible:
		_proposal_text.text = "%s: \"%s\"%s" % [_proposal_name, text, PROPOSAL_HINT]


func _on_proposal_resolved(_accepted: bool) -> void:
	_proposal_panel.hide()


func _on_hero_state_changed(hero: Node2D, _stat: StringName, _value: float) -> void:
	if hero.is_in_group(GROUP_LEADER):
		_refresh_psyche()


func _refresh_psyche() -> void:
	var leader: UnitBase = get_tree().get_first_node_in_group(GROUP_LEADER) as UnitBase
	if leader == null or leader.hero_data == null:
		_psyche_label.text = "분대장 부재"
		return
	var h: HeroData = leader.hero_data
	_psyche_label.text = "%s  SAN %d  LOY %d  FEAR %d" % [h.display_name, roundi(h.sanity), roundi(h.loyalty), roundi(h.fear)]


func _on_unit_died(_unit: Node2D) -> void:
	_refresh_psyche()


# ---------------------------------------------------------------- Mission
func _on_missions_available(missions: Array[MissionData], current: int) -> void:
	_mission_index = current
	for c: Node in _mission_buttons.get_children():
		c.queue_free()
	for i: int in missions.size():
		var b: Button = Button.new()
		b.text = missions[i].display_name
		b.custom_minimum_size = MISSION_BUTTON_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.set_pressed_no_signal(i == current)
		b.add_theme_font_size_override(&"font_size", 22)
		b.pressed.connect(EventBus.mission_restart_requested.emit.bind(i))
		_mission_buttons.add_child(b)


func _on_mission_started(title: String, briefing: String) -> void:
	_mission_title.text = title
	_mission_brief.text = briefing
	_result_box.hide()


func _on_mission_progress(text: String) -> void:
	_mission_progress.text = text


func _on_mission_ended(victory: bool, reason: String) -> void:
	_result_label.text = "VICTORY" if victory else "DEFEAT"
	_result_reason.text = reason
	_result_box.show()


# ---------------------------------------------------------------- Master Skills
func _on_skills_ready(skills: Array[MasterSkillData]) -> void:
	for b: Button in _skill_buttons:
		b.queue_free()
	_skill_buttons.clear()
	_skills = skills
	for i: int in skills.size():
		var b: Button = Button.new()
		b.custom_minimum_size = SKILL_BUTTON_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override(&"font_size", 22)
		b.pressed.connect(EventBus.master_skill_requested.emit.bind(i))
		_skill_bar.add_child(b)
		_skill_buttons.append(b)


func _on_master_state(mana: float, max_mana: float, cooldowns: PackedFloat32Array) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_label.text = "MANA %d/%d" % [floori(mana), roundi(max_mana)]
	for i: int in mini(_skill_buttons.size(), cooldowns.size()):
		var sk: MasterSkillData = _skills[i]
		var cd: float = cooldowns[i]
		var b: Button = _skill_buttons[i]
		b.disabled = cd > 0.0 or mana < sk.mana_cost
		var key: String = OS.get_keycode_string(sk.hotkey)
		b.text = "%s\n%s" % [sk.display_name, ("%.1fs" % cd) if cd > 0.0 else "%d [%s]" % [roundi(sk.mana_cost), key]]
