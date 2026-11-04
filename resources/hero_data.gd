class_name HeroData
extends UnitData


enum Role { VANGUARD, RANGED, SUPPORT }

const STAT_MIN: float = 0.0
const STAT_MAX: float = 100.0
const MEMORY_CAP: int = 32

@export_range(1, 5) var rarity: int = 1
@export var role: Role = Role.VANGUARD
@export_group("Psyche")
@export_range(0.0, 100.0) var sanity: float = 70.0
@export_range(0.0, 100.0) var loyalty: float = 50.0
@export_range(0.0, 100.0) var fear: float = 30.0
@export var memory_log: Array[String] = []


func modify_stat(stat: StringName, delta: float) -> float:
	var next: float = clampf(float(get(stat)) + delta, STAT_MIN, STAT_MAX)
	set(stat, next)
	return next


func add_memory(entry: String) -> void:
	memory_log.append(entry)
	if memory_log.size() > MEMORY_CAP:
		memory_log.pop_front()
