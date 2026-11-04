class_name MissionObjective
extends Node2D
## 미션 승패 판정 베이스 (IMissionObjective). 공통: 아군 전멸 = 실패.
## 파생 클래스는 _on_begin / _on_tick / _on_unit_died / _progress_text 만 구현.

const TICK_INTERVAL: float = 0.2

var data: MissionData
var ended: bool = false

var _tick_acc: float = 0.0


func setup(mission: MissionData) -> void:
	data = mission


func _ready() -> void:
	assert(data != null, "MissionObjective: setup() 필요")
	EventBus.unit_died.connect(_handle_unit_died)
	_on_begin()
	EventBus.mission_started.emit(data.display_name, data.briefing)
	_emit_progress()


func _process(delta: float) -> void:
	if ended:
		return
	_tick_acc -= delta
	if _tick_acc > 0.0:
		return
	var dt: float = TICK_INTERVAL - _tick_acc
	_tick_acc = TICK_INTERVAL
	_on_tick(dt)
	if not ended:
		_emit_progress()


func complete(reason: String) -> void:
	_finish(true, reason)


func fail(reason: String) -> void:
	_finish(false, reason)


func _finish(victory: bool, reason: String) -> void:
	if ended:
		return
	ended = true
	_emit_progress()
	_on_end(victory)
	EventBus.mission_ended.emit(victory, reason)


func _handle_unit_died(unit: Node2D) -> void:
	if ended:
		return
	_on_unit_died(unit)
	if not ended and UnitRegistry.allies.is_empty():
		fail("분대 전멸")
	elif not ended:
		_emit_progress()


func _emit_progress() -> void:
	EventBus.mission_progress.emit(_progress_text())


# ---------------------------------------------------------------- 파생 훅
func _on_begin() -> void:
	pass


func _on_tick(_dt: float) -> void:
	pass


func _on_unit_died(_unit: Node2D) -> void:
	pass


func _on_end(_victory: bool) -> void:
	pass


func _progress_text() -> String:
	return ""
