class_name EgoConfig
extends Resource
## 역제안 판정 가중치. p = base + danger*w_danger + fear*w_fear - loyalty*w_loyalty (0~1 정규화 입력).

@export_range(0.0, 1.0) var base_chance: float = 0.1
@export var w_danger: float = 0.6
@export var w_fear: float = 0.35
@export var w_loyalty: float = 0.45
@export_range(0.0, 1.0) var min_danger_to_evaluate: float = 0.25
@export var danger_radius: float = 260.0
@export var danger_per_enemy: float = 0.2
@export var cover_search_distance: float = 280.0
@export_group("Resolution")
@export var accept_buff_mult: float = 1.3
@export var accept_buff_duration: float = 8.0
@export var accept_loyalty_gain: float = 4.0
@export var force_loyalty_penalty: float = 8.0
@export var force_fear_gain: float = 5.0


func evaluate(danger: float, fear: float, loyalty: float) -> float:
	if danger < min_danger_to_evaluate:
		return 0.0
	var p: float = base_chance + danger * w_danger + (fear / 100.0) * w_fear - (loyalty / 100.0) * w_loyalty
	return clampf(p, 0.0, 1.0)
