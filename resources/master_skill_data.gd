class_name MasterSkillData
extends Resource
## 마스터 스킬 정의 (데이터 전용). 효과 적용은 MasterSkillSystem / UnitBase.

enum Kind { HEAL, SHIELD, COMMAND, RECALL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.HEAL
@export var hotkey: Key = KEY_NONE
@export_range(0.0, 1000.0) var mana_cost: float = 30.0
@export_range(0.0, 120.0) var cooldown: float = 8.0
## HEAL/SHIELD: 최대 HP 대비 비율, COMMAND: 공격 배율
@export var magnitude: float = 0.3
@export_range(0.0, 60.0) var duration: float = 0.0
## 분대 영웅 Fear 변화량 (COMMAND 사기 고양 등)
@export var fear_delta: float = 0.0
