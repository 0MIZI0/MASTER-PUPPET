class_name CombatTuning
extends Resource
## 유닛 AI/전투 밸런스 수치 (UnitBase 공용).

@export_range(0.05, 2.0) var retarget_interval: float = 0.3
@export_range(1.0, 200.0) var repath_distance: float = 32.0
@export_range(1.0, 200.0) var arrive_distance: float = 40.0
@export_range(10.0, 600.0) var focus_pick_radius: float = 160.0
@export_range(10.0, 200.0) var slot_spacing: float = 46.0
## 공격 유지 사거리 배율 (교전 중 미세 이동으로 인한 상태 진동 방지)
@export_range(1.0, 2.0) var attack_range_slack: float = 1.15
@export_range(0.0, 100.0) var min_damage: float = 1.0
## 서포트가 치유 대상으로 삼는 HP 비율 상한
@export_range(0.0, 1.0) var heal_threshold: float = 0.9

@export_group("Psyche")
@export_range(0.0, 2000.0) var witness_range: float = 500.0
@export var fear_on_ally_death: float = 6.0
@export var sanity_on_ally_death: float = -4.0
