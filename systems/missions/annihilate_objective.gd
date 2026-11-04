class_name AnnihilateObjective
extends MissionObjective
## 섬멸: 적 전멸 시 승리.

var _total: int = 0


func _on_begin() -> void:
	_total = get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY).size()


func _on_unit_died(_unit: Node2D) -> void:
	if get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY).is_empty():
		complete("적 섬멸")


func _progress_text() -> String:
	var alive: int = get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY).size()
	return "적 섬멸 %d / %d" % [_total - alive, _total]
