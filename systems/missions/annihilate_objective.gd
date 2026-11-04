class_name AnnihilateObjective
extends MissionObjective
## 섬멸: 적 전멸 시 승리.

var _total: int = 0


func _on_begin() -> void:
	_total = UnitRegistry.enemies.size()


func _on_unit_died(_unit: Node2D) -> void:
	if UnitRegistry.enemies.is_empty():
		complete("적 섬멸")


func _progress_text() -> String:
	var alive: int = UnitRegistry.enemies.size()
	return "적 섬멸 %d / %d" % [_total - alive, _total]
