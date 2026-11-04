class_name MasterConfig
extends Resource
## 마스터 마나/스킬 슬롯 설정.

@export_range(1.0, 1000.0) var max_mana: float = 100.0
@export_range(0.0, 1000.0) var start_mana: float = 50.0
@export_range(0.0, 100.0) var mana_regen: float = 4.0  ## 초당 (게임 시간)
@export var skills: Array[MasterSkillData] = []
