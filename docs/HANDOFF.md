# HANDOFF — MASTER (Phase 1 Combat MVP)

최종 갱신: 2026-11-04 · 기준 커밋: `1a1bbb3` · 설계 원문: [`docs/GDD.md`](GDD.md) · 규칙: [`CLAUDE.md`](../CLAUDE.md)

## 1. 현재 상태 한눈에

| 항목 | 값 |
|---|---|
| 엔진 | Godot 4.3 stable, GDScript 정적 타이핑 강제 (`untyped_declaration=2`) |
| 렌더러 | `gl_compatibility` (PC / 모바일 / Web 공용) |
| 레포 | https://github.com/0MIZI0/MASTER-PUPPET (public) |
| 플레이 URL | https://0mizi0.github.io/MASTER-PUPPET/ (`main` push 시 자동 배포) |
| 테스트 | `tests/` headless 3종 55항목 전부 PASS |

GDD §2 Phase 1 항목 구현 상태:

| GDD 항목 | 상태 | 주요 파일 |
|---|---|---|
| 자유 이동 + RVO, 5인 분대 자율 교전 | ✅ | `entities/unit_base.gd`, `scenes/combat_arena.*` |
| 불릿 타임 (0.15, 비네팅, 로우패스) | ✅ | `systems/bullet_time_controller.gd` |
| 전술 핀 3종 + Line2D 경로 | ✅ | `systems/tactical_pin_system.gd`, `entities/tactical_pin_node.gd` |
| 분대장 역제안 (승인 버프 / 강행 충성 하락) | ✅ | `tactical_pin_system.gd`, `resources/ego_config.gd` |
| 마스터 스킬 HEAL/SHIELD/COMMAND/RECALL + 마나 | ✅ | `systems/master_skill_system.gd`, `resources/skills/*.tres` |
| 미션 모듈 (`IMissionObjective`) | ✅ 섬멸·거점 방어 / ⏳ 탈출·호위·보스전 | `systems/missions/*` |
| Dialogue Provider (템플릿 / LLM) | ✅ 템플릿·LLM 클라이언트 / ⏳ 프록시 서버 | `systems/dialogue/*`, `data/dialogue/ko_templates.json` |

## 2. 구조

```
core/        EventBus(Autoload, 신호만) · UnitRegistry(Autoload, 생존 유닛 캐시) · EnvLoader · PinTypes
resources/   *.gd = Resource 정의, *.tres = 데이터 (영웅/몬스터/스킬/미션/튜닝/대사 설정)
systems/     BulletTime · TacticalPin · MasterSkill · UnitPool · missions/ · dialogue/
entities/    UnitBase(+unit.tscn) · TacticalPinNode
scenes/      combat_arena (메인 씬, 미션 선택 = static selected_mission)
ui/          combat_hud (핀/스킬/마나/미션/역제안 팝업/결과)
data/        dialogue/ko_templates.json (export include_filter로 포함)
tests/       headless 테스트 씬 (export 제외)
tools/       deploy_web.sh, git-hooks/pre-push
```

원칙:
- 시스템 간 통신은 **EventBus 신호만** (`core/event_bus.gd` 섹션별 정리).
- 밸런스 수치는 **전부 `.tres`**: `combat_tuning_default.tres`(유닛 AI), `ego_config_default.tres`(역제안), `master_config_default.tres` + `skills/*.tres`, `missions/*.tres`, `dialogue_config_default.tres`.
- 핫패스에서 `get_nodes_in_group()` 금지 → `UnitRegistry.allies / enemies / leader` (읽기 전용, 순회 중 수정 금지). 그룹 등록은 호환용으로 병행 유지.
- 웨이브 적은 `UnitPool` 재사용 (`UnitBase.activate()/deactivate()`, `pooled=true`면 사망 시 `despawned`).

## 3. 주요 흐름

- **핀:** 드래그 → `bullet_time_requested(pin_input)` → 놓기 → 분대장 판정(`EgoConfig.evaluate(danger, fear, loyalty)`) → 그대로 `pin_committed` 또는 `counter_proposal_raised` → HUD 승인/강행(Y/N) → `counter_proposal_resolved` → `pin_committed`.
- **RECALL:** `pin_commit_requested(RETREAT, RecallPoint)` → 판정 생략, 대기 중 역제안은 `counter_proposal_cancelled`.
- **미션:** 아레나가 `MissionData.kind`로 Objective 생성 → 5Hz `_on_tick` → `mission_progress` / `mission_ended`. 공통: 아군 전멸 = 패배. 거점: 적만 존재 시 게이지↑, 아군만 존재 시↓, 100 = 함락, `survive_time` 버티면 승리, 웨이브 수·HP 성장.
- **대사:** `DialogueService`가 이벤트 → 화자 선정 → `DialogueContext`(심리 스냅샷) → Provider → (deferred) `UnitBase.say()` 말풍선 + `hero_spoke`. 우선순위: CRITICAL(역제안/결정/승패, 쿨다운 무시) · URGENT(동료 사망, 전역 쿨다운만 무시) · NORMAL.
- **LLM:** `dialogue_config.mode = LLM` + 환경변수/`user://.env`의 `DIALOGUE_PROXY_URL`(https만, localhost http 예외). 요청 `POST to_payload()` → 응답 `{"line": "..."}`. 실패·타임아웃·동시 요청 시 템플릿 폴백. **클라이언트에 API 키 없음.**

조작: 드래그 = 핀 (1/2/3 = 집결/일점사/후퇴), Y/N = 역제안 승인/강행, Q/W/E/R = 스킬, 우상단 버튼 = 미션 전환·재시작.

## 4. 작업 방법

```bash
GODOT=/usr/local/bin/godot            # PATH에서 안 잡힐 수 있음 — 절대 경로 사용
$GODOT --headless --path . --import    # 새 리소스/폰트 추가 후
for t in test_master_skills test_missions test_dialogue; do
  $GODOT --headless --path . res://tests/$t.tscn     # RESULT fail=0, exit 0 이어야 함
done
tools/deploy_web.sh --no-push          # 웹 빌드만 (build/web)
```

- **배포:** `git push origin main` → pre-push 훅이 백그라운드로 `deploy_web.sh --wait-remote <sha>` 실행 (import → 스크립트 오류 검사 → Web export → `gh-pages` 강제 갱신). 로그 `.git/deploy_web.log`. 건너뛰기 `SKIP_DEPLOY=1 git push`.
- **새 머신:** `git config core.hooksPath tools/git-hooks`, `gh auth login && gh auth setup-git`, Godot 4.3 + Web export 템플릿 필요.
- **테스트는 `.tscn` 씬으로** 작성 (`-s` 스크립트 모드에선 Autoload가 컴파일 시 안 보임).

## 5. 함정 (이미 겪은 것)

| 증상 | 원인 / 대처 |
|---|---|
| 웹에서 한글 □ | 웹엔 시스템 폰트 폴백 없음 → `assets/fonts/NotoSansKR-Medium-subset.ttf`(한글 11,172자 서브셋)를 `gui/theme/custom_font`로 지정함. 새 글리프(한자 등) 필요 시 서브셋 재생성 |
| 종료 시 `resources still in use` / `ObjectDB leaked` | Godot 4.3에서 **자기 타입을 반환하는 static 팩토리**가 원인이었음 → 인스턴스 메서드로 (`TemplateDialogueProvider.load_file`) |
| pre-push 안에서 배포 시 main push 거부 | 연결이 30초 묶임 → 백그라운드 + 원격 반영 대기 방식으로 해결 |
| `.json`이 웹 빌드에 없음 | `export_presets.cfg` `include_filter="data/*.json"` 필요 (비리소스 파일) |
| 빌드 산출물이 import됨 | `build/.gdignore` 유지 |
| 동기 Provider 대사가 팝업보다 먼저 도착 | `DialogueService._deliver_deferred` (call_deferred)로 해결 — 지우지 말 것 |

## 6. 미해결 / 다음 작업 후보

**확인 필요 (실기기)**
- 아이폰 가로 모드에서 HUD 배치: 스킬 바 ↔ 역제안 팝업 가로 ~50px 겹침 가능, 말풍선 가독성, 버튼 터치 크기.
- 입력은 마우스 이벤트 기반(터치→마우스 에뮬레이션 기본값). 멀티터치/핀치 미대응.

**밸런스**
- 거점 방어가 무입력에서도 대부분 승리 (6회 중 6승, 생존 1~3명) → `missions/defend_outpost.tres`의 `wave_size_growth` / `wave_hp_growth` 상향 검토.
- 섬멸은 시작 위치가 서로 감지 범위 밖이라 핀 없이는 교전이 시작되지 않음 (의도 여부 결정 필요).

**기능**
- 미션: 탈출(RECALL 봉인/비용 2배 권고), 호위·보스전은 Phase 2 이후 권고 (패널 결론).
- 거점 방어 중 Fear 기반 "후퇴 역제안" 연동 (패널 제안, 미구현).
- LLM 프록시 서버 (예: Supabase Edge Function, 키는 서버 시크릿) — 클라이언트는 준비됨.
- Phase 2: 대기실(Side-View Base), Utility AI, 합성 딜레마, 영구 사망 세이브 동기화.

**정리**
- `core/event_bus.gd`, `resources/hero_data.gd`는 2026-11-04 웹 빌드 디컴파일로 복구되어 **문서 주석이 없음**.
- `gh` 토큰이 서버에 평문 저장 (`~/.config/gh/hosts.yml`) — 공용 서버면 `gh auth logout`.
