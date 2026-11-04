class_name DialogueProvider
extends RefCounted
## 대사 공급자 인터페이스. 결과는 done.call(text: String) 로 전달 (동기/비동기 공통).
## 빈 문자열 = 대사 없음.


func request_line(_ctx: DialogueContext, done: Callable) -> void:
	done.call("")


## 외부 입력(LLM/JSON) 정제: 제어문자 제거, 공백 정리, 길이 제한.
static func sanitize(text: String, max_chars: int) -> String:
	var out: String = ""
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		out += " " if code < 0x20 or code == 0x7f else text[i]
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	if out.length() > max_chars:
		out = out.left(max_chars - 1) + "…"
	return out
