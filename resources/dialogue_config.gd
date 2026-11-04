class_name DialogueConfig
extends Resource
## 대사 시스템 설정. LLM 프록시 URL은 EnvLoader(proxy_url_env_key)로 런타임 주입 — 하드코딩 금지.

enum Mode { TEMPLATE, LLM }

@export var mode: Mode = Mode.TEMPLATE
@export_file("*.json") var template_path: String = "res://data/dialogue/ko_templates.json"
@export var proxy_url_env_key: String = "DIALOGUE_PROXY_URL"
@export_range(0.5, 10.0) var llm_timeout_sec: float = 2.5
@export_range(10, 200) var max_chars: int = 80
@export_range(0.0, 30.0) var speaker_cooldown_sec: float = 4.0  ## 실시간
@export_range(0.0, 10.0) var global_cooldown_sec: float = 1.2   ## 실시간
@export_range(0.5, 10.0) var bubble_time: float = 3.0           ## 게임 시간 (불릿 타임 중 길게 유지)
