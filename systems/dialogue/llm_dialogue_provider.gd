class_name LLMDialogueProvider
extends DialogueProvider
## 서버 프록시 경유 LLM 대사. 클라이언트는 API 키를 갖지 않음 (프록시가 보관).
## 요청: POST JSON DialogueContext.to_payload() / 응답: {"line": "<대사>"}
## 실패·타임아웃·동시 요청·비정상 응답 시 fallback 사용.

var _http: HTTPRequest
var _url: String = ""
var _max_chars: int = 80
var _fallback: DialogueProvider
var _busy: bool = false
var _pending_ctx: DialogueContext
var _pending_done: Callable


static func is_allowed_url(url: String) -> bool:
	if url.begins_with("https://"):
		return url.length() > 8
	for local: String in ["http://localhost", "http://127.0.0.1"]:
		if url == local or url.begins_with(local + ":") or url.begins_with(local + "/"):
			return true
	return false


func _init(host: Node, url: String, timeout_sec: float, max_chars: int, fallback: DialogueProvider) -> void:
	assert(is_allowed_url(url), "LLMDialogueProvider: https 프록시 URL 필요")
	_url = url
	_max_chars = max_chars
	_fallback = fallback
	_http = HTTPRequest.new()
	_http.timeout = timeout_sec
	_http.request_completed.connect(_on_completed)
	host.add_child(_http)


func request_line(ctx: DialogueContext, done: Callable) -> void:
	if _busy:
		_fallback.request_line(ctx, done)
		return
	var body: String = JSON.stringify(ctx.to_payload(_max_chars))
	var err: Error = _http.request(_url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	if err != OK:
		_fallback.request_line(ctx, done)
		return
	_busy = true
	_pending_ctx = ctx
	_pending_done = done


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var ctx: DialogueContext = _pending_ctx
	var done: Callable = _pending_done
	_pending_ctx = null
	_pending_done = Callable()
	if ctx == null or not done.is_valid():
		return
	var line: String = parse_response(result, code, body, _max_chars)
	if line.is_empty():
		_fallback.request_line(ctx, done)
	else:
		done.call(line)


static func parse_response(result: int, code: int, body: PackedByteArray, max_chars: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.size() > 4096:
		return ""
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not (parsed as Dictionary).get("line") is String:
		return ""
	return DialogueProvider.sanitize((parsed as Dictionary)["line"] as String, max_chars)
