class_name UnitPool
extends Node
## UnitBase 오브젝트 풀. 사망(despawned) 시 회수, acquire 시 재가동.

@export var unit_scene: PackedScene = preload("res://entities/unit.tscn")

var _container: Node
var _free: Array[UnitBase] = []
var _alive: int = 0


func setup(container: Node, prewarm: int, prewarm_data: UnitData) -> void:
	_container = container
	for i: int in prewarm:
		var u: UnitBase = _create(prewarm_data, UnitBase.Faction.ENEMY, Vector2(-10000.0, -10000.0))
		u.deactivate()
		u.hide()
		_free.append(u)


func alive_count() -> int:
	return _alive


func acquire(data: UnitData, faction: UnitBase.Faction, pos: Vector2, hp_mult: float = 1.0) -> UnitBase:
	var u: UnitBase
	if _free.is_empty():
		u = _create(data, faction, pos)
		if not is_equal_approx(hp_mult, 1.0):
			u.activate(data, pos, hp_mult)
	else:
		u = _free.pop_back()
		u.faction = faction
		u.activate(data, pos, hp_mult)
	_alive += 1
	return u


func _create(data: UnitData, faction: UnitBase.Faction, pos: Vector2) -> UnitBase:
	var u: UnitBase = unit_scene.instantiate() as UnitBase
	u.data = data
	u.faction = faction
	u.pooled = true
	u.position = pos
	u.despawned.connect(_on_despawned)
	_container.add_child(u)
	return u


func _on_despawned(u: UnitBase) -> void:
	_alive -= 1
	_free.append(u)
