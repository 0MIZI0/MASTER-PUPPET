class_name EnvLoader
extends RefCounted
## 런타임 설정값 로더. 우선순위: OS 환경변수 > user://.env (KEY=VALUE).
## res:// 의 .env 는 읽지 않음 (export 패키지 유출 방지).

const USER_ENV_PATH: String = "user://.env"

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func get_value(key: String, default_value: String = "") -> String:
	var v: String = OS.get_environment(key)
	if not v.is_empty():
		return v
	_ensure_loaded()
	return String(_cache.get(key, default_value))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(USER_ENV_PATH):
		return
	var f: FileAccess = FileAccess.open(USER_ENV_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var eq: int = line.find("=")
		if eq <= 0:
			continue
		_cache[line.left(eq).strip_edges()] = line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
