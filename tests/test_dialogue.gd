extends Node
## Headless 검증: Dialogue Provider / Service.

var _fail: int = 0
var _spoken: Array = []  ## [hero, text, event]


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _ready() -> void:
	EventBus.hero_spoke.connect(func(h: Node2D, t: String, e: StringName) -> void: _spoken.append([h, t, e]))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _ctx(ev: StringName, fear: float, loyalty: float, sanity: float = 60.0) -> DialogueContext:
	var c: DialogueContext = DialogueContext.new()
	c.event = ev
	c.speaker_name = "에르사"
	c.fear = fear
	c.loyalty = loyalty
	c.sanity = sanity
	c.vars = {"pin": "집결", "target": "리나"}
	return c


func _run() -> void:
	# ---------------- Template provider
	var t: TemplateDialogueProvider = TemplateDialogueProvider.new()
	t.load_json('{"e":[{"when":{"fear_min":60},"lines":["무서워 {name}"]},{"when":{"loyalty_max":30},"lines":["반항 {pin}"]},{"lines":["기본 {target}"]}],"bad":"x","bad2":[1,{"lines":[]}]}')
	_check(t.pick_line(_ctx(&"e", 80.0, 50.0)) == "무서워 에르사", "템플릿: fear_min 분기 + {name}")
	_check(t.pick_line(_ctx(&"e", 10.0, 20.0)) == "반항 집결", "템플릿: loyalty_max 분기 + vars")
	_check(t.pick_line(_ctx(&"e", 10.0, 50.0)) == "기본 리나", "템플릿: 기본 분기")
	_check(not t.has_event(&"bad") and not t.has_event(&"bad2"), "템플릿: 잘못된 스키마 엔트리 무시")
	_check(t.pick_line(_ctx(&"none", 0.0, 0.0)) == "", "템플릿: 미정의 이벤트 → 빈 문자열")
	_check(not TemplateDialogueProvider.new().load_json("[1,2"), "템플릿: 깨진 JSON 거부")
	var real: TemplateDialogueProvider = TemplateDialogueProvider.new()
	real.load_file("res://data/dialogue/ko_templates.json")
	_check(real.load_error.is_empty() and real.has_event(&"counter_proposal"), "템플릿: ko_templates.json 로드")
	var missing: PackedStringArray = []
	for ev: StringName in [&"counter_proposal", &"proposal_accepted", &"proposal_forced", &"ally_died", &"mission_start", &"victory", &"defeat", &"skill_command", &"skill_heal", &"skill_recall"]:
		for f: float in [0.0, 100.0]:
			for l: float in [0.0, 100.0]:
				for s: float in [0.0, 100.0]:
					if real.pick_line(_ctx(ev, f, l, s)).is_empty():
						missing.append("%s(f%d,l%d,s%d)" % [ev, f, l, s])
	_check(missing.is_empty(), "템플릿: 전 이벤트 × 심리 극값에서 대사 존재 %s" % [missing])

	# ---------------- 정제 / LLM 응답 검증
	_check(DialogueProvider.sanitize("  a\n\tb" + char(1) + "c" + char(127) + "  ", 80) == "a b c", "정제: 제어문자/공백")
	_check(DialogueProvider.sanitize("가나다라마바사", 5) == "가나다라…", "정제: 길이 제한")
	_check(LLMDialogueProvider.is_allowed_url("https://x.supabase.co/functions/v1/d"), "URL: https 허용")
	_check(not LLMDialogueProvider.is_allowed_url("http://evil.com"), "URL: 원격 http 거부")
	_check(not LLMDialogueProvider.is_allowed_url("http://localhost.evil.com"), "URL: localhost 위장 거부")
	_check(LLMDialogueProvider.is_allowed_url("http://127.0.0.1:8787/d"), "URL: 로컬 http 허용")
	var ok_body: PackedByteArray = '{"line":"살아서 돌아가요.\\n"}'.to_utf8_buffer()
	_check(LLMDialogueProvider.parse_response(HTTPRequest.RESULT_SUCCESS, 200, ok_body, 80) == "살아서 돌아가요.", "LLM 응답: 정상 파싱")
	_check(LLMDialogueProvider.parse_response(HTTPRequest.RESULT_SUCCESS, 500, ok_body, 80) == "", "LLM 응답: 5xx 거부")
	_check(LLMDialogueProvider.parse_response(HTTPRequest.RESULT_SUCCESS, 200, '{"line":3}'.to_utf8_buffer(), 80) == "", "LLM 응답: 타입 불일치 거부")
	_check(LLMDialogueProvider.parse_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray(), 80) == "", "LLM 응답: 타임아웃 → 폴백")

	# LLM 요청 실패 시 템플릿 폴백 (닫힌 로컬 포트)
	var got: Array[String] = []
	var llm: LLMDialogueProvider = LLMDialogueProvider.new(self, "http://127.0.0.1:9/none", 1.0, 80, t)
	llm.request_line(_ctx(&"e", 10.0, 50.0), func(s: String) -> void: got.append(s))
	for i: int in 180:
		if not got.is_empty():
			break
		await get_tree().process_frame
	_check(got.size() == 1 and got[0] == "기본 리나", "LLM: 연결 실패 → 템플릿 폴백 %s" % [got])

	# ---------------- Service 통합 (아레나)
	(load("res://scenes/combat_arena.gd") as GDScript).set(&"selected_mission", 0)
	var arena: Node = (load("res://scenes/combat_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _frames(4)
	var leader: UnitBase = arena.get_node("Units/Ersa") as UnitBase
	_check(_spoken.any(func(e: Array) -> bool: return e[2] == &"mission_start" and e[0] == leader), "서비스: 미션 시작 대사 (분대장)")
	_spoken.clear()
	EventBus.counter_proposal_raised.emit(leader, Vector2(1400, 500), Vector2(1000, 500), PinTypes.Type.MOVE)
	await _frames(2)
	var hud: CombatHUD = arena.get_node("CombatHUD") as CombatHUD
	var ptext: String = (hud.get_node("%ProposalText") as Label).text
	_check(_spoken.size() == 1 and _spoken[0][2] == &"counter_proposal", "서비스: 역제안 대사 발화")
	_check(ptext.begins_with("에르사: \"") and not ptext.contains("…[Y]") and ptext.contains("[Y]"), "HUD: 역제안 팝업에 대사 반영 (%s)" % ptext.get_slice("\n", 0))
	_check(leader._bubble != null and leader._bubble.visible and leader._bubble.text == _spoken[0][1], "유닛: 말풍선 표시")
	EventBus.counter_proposal_resolved.emit(false)
	await _frames(2)
	_check(_spoken.size() == 2 and _spoken[1][2] == &"proposal_forced", "서비스: 강행 반응 대사 (쿨다운 무시)")
	_spoken.clear()
	var rina: UnitBase = arena.get_node("Units/Rina") as UnitBase
	rina.take_damage(99999.0, null)
	await _frames(2)
	_check(_spoken.size() == 1 and _spoken[0][2] == &"ally_died" and _spoken[0][0] != rina, "서비스: 동료 사망 목격 대사")
	_spoken.clear()
	EventBus.master_skill_cast.emit(load("res://resources/skills/command.tres") as MasterSkillData)
	EventBus.master_skill_cast.emit(load("res://resources/skills/command.tres") as MasterSkillData)
	await _frames(2)
	_check(_spoken.size() <= 1, "서비스: 쿨다운으로 연속 대사 억제 (=%d)" % _spoken.size())
	arena.free()

	print("RESULT fail=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
