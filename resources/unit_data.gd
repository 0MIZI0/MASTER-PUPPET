class_name UnitData
extends Resource
## 유닛 공통 전투 스탯 (영웅/몬스터 공용).

@export var id: StringName = &""
@export var display_name: String = ""
@export var tint: Color = Color(0.79, 0.78, 0.81)
@export_group("Combat")
@export var max_hp: float = 100.0
@export var attack: float = 10.0
@export var defense: float = 0.0
@export var attack_range: float = 48.0
@export var attack_interval: float = 1.0
@export var move_speed: float = 120.0
@export var aggro_range: float = 420.0
