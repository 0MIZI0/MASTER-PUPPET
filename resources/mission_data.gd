class_name MissionData
extends Resource
## 미션 정의 (데이터 전용). 판정 로직은 systems/missions/*_objective.gd.

enum Kind { ANNIHILATE, DEFEND }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var briefing: String = ""
@export var kind: Kind = Kind.ANNIHILATE
## 씬에 배치된 적 유지 여부 (false면 시작 시 제거)
@export var keep_preplaced_enemies: bool = true

@export_group("Defend")
@export_range(10.0, 900.0) var survive_time: float = 90.0
@export_range(40.0, 600.0) var zone_radius: float = 170.0
## 적 1기당 초당 점령 게이지 증가량 (게이지 100 = 실패)
@export_range(0.0, 100.0) var capture_rate: float = 4.0
## 아군만 있을 때 초당 게이지 감소량
@export_range(0.0, 100.0) var recapture_rate: float = 6.0

@export_group("Waves")
@export var wave_enemy: UnitData
@export_range(1.0, 120.0) var wave_interval: float = 15.0
@export_range(0.0, 60.0) var first_wave_delay: float = 3.0
@export_range(1, 50) var wave_size_start: int = 3
@export_range(0, 20) var wave_size_growth: int = 1
## 웨이브당 적 최대 HP 증가율 (턴틀링 억제)
@export_range(0.0, 2.0) var wave_hp_growth: float = 0.12
## 동시 생존 적 상한 (풀 크기)
@export_range(1, 200) var max_alive: int = 24
## 미션 시작 시 미리 생성할 풀 크기 (스폰 순간 instantiate 스파이크 방지)
@export_range(0, 200) var pool_prewarm: int = 12
@export_range(0.0, 300.0) var spawn_jitter: float = 40.0
