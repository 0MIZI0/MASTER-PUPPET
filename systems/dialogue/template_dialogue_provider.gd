class_name TemplateDialogueProvider
extends DialogueProvider
## 로컬 JSON 템플릿 대사. 구조:
## { "<event>": [ { "when": {"fear_min":60, "loyalty_max":40, ...}, "lines": ["...{name}..."] }, ... ] }
## 엔트리는 위에서부터 첫 조건 일치를 사용 (구체적 조건을 위에 배치).

const STATS: PackedStringArray = ["fear", "loyalty", "sanity"]
const MAX_LINE_CHARS: int = 120

var _table: Dictionary = {}  ## StringName -> Array[Dictionary]
var load_error: String = ""


## 파일 로드. 실패 시 load_error 설정 후 false.
## (정적 팩토리로 자기 타입 반환 시 Godot 4.3 종료 시점 스크립트 누수 발생 → 인스턴스 메서드 사용)
func load_file(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_error = "열기 실패: %s" % path
		push_warning("TemplateDialogueProvider: " + load_error)
		return false
	return load_json(f.get_as_text())


## 스키마 검증 후 로드. 잘못된 엔트리는 건너뜀.
func load_json(text: String) -> bool:
	_table.clear()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		load_error = "JSON 최상위가 객체가 아님"
		push_warning("TemplateDialogueProvider: " + load_error)
		return false
	var root: Dictionary = parsed as Dictionary
	for key: Variant in root:
		if not key is String or not root[key] is Array:
			continue
		var entries: Array[Dictionary] = []
		for e: Variant in root[key] as Array:
			var entry: Dictionary = _validate_entry(e)
			if not entry.is_empty():
				entries.append(entry)
		if not entries.is_empty():
			_table[StringName(key as String)] = entries
	return true


func has_event(ev: StringName) -> bool:
	return _table.has(ev)


func request_line(ctx: DialogueContext, done: Callable) -> void:
	done.call(pick_line(ctx))


func pick_line(ctx: DialogueContext) -> String:
	var entries: Array[Dictionary] = _table.get(ctx.event, [] as Array[Dictionary])
	for entry: Dictionary in entries:
		if _matches(entry["when"] as Dictionary, ctx):
			var lines: PackedStringArray = entry["lines"]
			return _fill(lines[randi() % lines.size()], ctx)
	return ""


func _validate_entry(e: Variant) -> Dictionary:
	if not e is Dictionary:
		return {}
	var d: Dictionary = e as Dictionary
	var lines: PackedStringArray = PackedStringArray()
	if d.get("lines") is Array:
		for l: Variant in d["lines"] as Array:
			if l is String and not (l as String).strip_edges().is_empty():
				lines.append(DialogueProvider.sanitize(l as String, MAX_LINE_CHARS))
	if lines.is_empty():
		return {}
	var when: Dictionary = {}
	if d.get("when") is Dictionary:
		var w: Dictionary = d["when"] as Dictionary
		for s: String in STATS:
			for suffix: String in ["_min", "_max"]:
				var k: String = s + suffix
				if w.get(k) is float or w.get(k) is int:
					when[k] = float(w[k])
	return {"when": when, "lines": lines}


func _matches(when: Dictionary, ctx: DialogueContext) -> bool:
	var values: Dictionary = {"fear": ctx.fear, "loyalty": ctx.loyalty, "sanity": ctx.sanity}
	for k: String in when:
		var stat: String = k.left(k.rfind("_"))
		var v: float = values[stat]
		if k.ends_with("_min") and v < float(when[k]):
			return false
		if k.ends_with("_max") and v > float(when[k]):
			return false
	return true


func _fill(line: String, ctx: DialogueContext) -> String:
	var out: String = line.replace("{name}", ctx.speaker_name)
	for k: Variant in ctx.vars:
		out = out.replace("{%s}" % str(k), str(ctx.vars[k]))
	if out.contains("{memory}"):
		out = out.replace("{memory}", ctx.memories[ctx.memories.size() - 1] if not ctx.memories.is_empty() else "")
	return out
