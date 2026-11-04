class_name DialogueContext
extends RefCounted
## 대사 생성 입력 (화자 심리 스냅샷 + 이벤트 변수). Provider 간 공통 포맷.

const MEMORY_TAIL: int = 3

var event: StringName = &""
var speaker_name: String = ""
var role: int = 0
var sanity: float = 50.0
var loyalty: float = 50.0
var fear: float = 50.0
var memories: PackedStringArray = PackedStringArray()
var vars: Dictionary = {}  ## String -> String


static func from_unit(ev: StringName, unit: UnitBase, extra: Dictionary = {}) -> DialogueContext:
	var c: DialogueContext = DialogueContext.new()
	c.event = ev
	c.vars = extra
	c.speaker_name = unit.stats.display_name
	var h: HeroData = unit.hero_data
	if h:
		c.role = h.role
		c.sanity = h.sanity
		c.loyalty = h.loyalty
		c.fear = h.fear
		var n: int = h.memory_log.size()
		for i: int in range(maxi(0, n - MEMORY_TAIL), n):
			c.memories.append(h.memory_log[i])
	return c


func to_payload(max_chars: int) -> Dictionary:
	return {
		"event": String(event),
		"speaker": {
			"name": speaker_name, "role": role,
			"sanity": roundi(sanity), "loyalty": roundi(loyalty), "fear": roundi(fear),
			"memories": Array(memories),
		},
		"vars": vars,
		"max_chars": max_chars,
		"lang": "ko",
	}
