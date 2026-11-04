# Project: MASTER - Game Design & Technical Specification

## 1. Overview & Target Environment
- **Concept:** 웹소설 《픽 미 업!》 모티브의 '마스터' 시점 다크 판타지 오토배틀러 & 영웅단 매니지먼트 로그라이크.
- **Engine & Language:** Godot 4.x / GDScript (100% Static Typing 강제: `untyped_declaration = 2`).
- **Platform & Viewport:** PC & Mobile(iPhone/Web Wasm) 크로스 타겟. **가로 모드(Landscape, 1920x1080 기준 19.5:9 Safe Area 대응)**.
- **Color Palette:** `#17161b`, `#1f1d24`, `#8e8896`, `#c9c6cf`, `#e9e3d7` (저채도 애쉬 그레이/바이올렛 베이스 + 적색/청색 포인트).

## 2. Core Gameplay Mechanics (Phase 1: Combat MVP)
### 2.1. Free-Movement Auto-Battler
- **이동 및 물리:** `NavigationRegion2D` + `NavigationAgent2D` 기반 자유 이동 및 RVO(상호 회피).
- **분대 규모:** 기본 5인 1분대 편성. 클래스(전위, 원거리, 지원 등) 사거리와 AI 가중치에 따라 자율 교전.
- **미션 모듈화:** 단일 규격 인터페이스(`IMissionObjective`)를 통해 `섬멸`, `거점 방어`, `호위`, `탈출`, `보스전` 등 다양한 승리 조건 확장.

### 2.2. Master Intervention & Bullet Time
- **불릿 타임 (Bullet Time):** 마스터가 화면을 터치/드래그하여 전술 핀을 지정하는 동안, 또는 분대장의 '역제안' 발생 시 `Engine.time_scale = 0.15` 적용 및 비네팅/오디오 로우패스 연출.
- **전술 핀 (Tactical Pin):** 전장 좌표에 `[집결/이동(청색)]`, `[일점사(적색)]`, `[후퇴(황색)]` 마커 생성 및 `Line2D` 경로 시각화.
- **마스터 스킬 (HUD):** 마스터 마나를 소모하여 `[HEAL(보급/회복)]`, `[SHIELD]`, `[COMMAND]`, `[RECALL(귀환)]` 발동.

### 2.3. Ego System & Counter-Proposal (자아 및 역제안)
- **심리 스탯:** 모든 영웅은 `Sanity`(정신력), `Loyalty`(충성도), `Fear`(공포도) 및 `memory_log: Array[String]` 보유.
- **명령 수용 판정:** 마스터의 전술 핀 생성 시 분대장의 `Loyalty`, `Fear`, 위험도 평가를 통해 수용 여부 결정.
- **역제안 (Counter-Proposal):** 무모한 명령 판정 시 분대장이 말풍선(`!`)과 함께 대안 좌표(엄폐물, 함정 유인 등)에 역제안 핀을 생성. 마스터가 이를 승인하면 교감 버프(공격력/사기 상승) 발동, 강행 시 `Loyalty` 하락.

## 3. Lobby Base & Meta Systems (Phase 2~3)
- **대기실 (Side-View Base):** 단면도 구조(숙소, 훈련장, 대장간). Utility AI 기반으로 영웅들이 자율 행동 및 히든 특성 자력 각성.
- **제4의 벽 상호작용:** 영웅 포커스(줌인) 시 마스터(화면 정면)를 응시하며 반응.
- **합성(Synthesis) 딜레마:** 저등급 영웅을 재료로 소모 시 대기실 내 목격 영웅들의 `Fear` 상승 및 `Loyalty` 하락.
- **BM & 편의성 확장 구조:** 밸런스 외적 요소(시설 대기열 슬롯, 전술 프리셋 슬롯, 전투 리플레이 로그, 추모관 및 스킨 테마)를 Feature Flag / Entitlement 데이터로 분리 관리.

## 4. Architecture, Security & Optimization Rules
- **Data-Driven Design:** 모든 영웅/몬스터/스킬/미션 정의는 커스텀 `Resource`(`class_name HeroData extends Resource`)로 분리.
- **Dialogue Provider 추상화:** 로컬 JSON 템플릿(`TemplateDialogueProvider`)과 외부 LLM 연동(`LLMDialogueProvider`)을 교체 가능하도록 인터페이스로 분리.
- **Security & Backend Ready:**
  - 세이브 데이터(로스터, 영구 사망, 재화)는 로컬 캐시와 원격 DB(Supabase 등 REST/RPC 연동) 동기화 인터페이스로 추상화하여 세이브 위변조 및 강제 종료 치트 방지.
  - 모든 외부 API 호출은 환경변수(`.env`) 및 서버 프록시 경유를 전제로 설계.
- **Directory Layout:**
  res://
  ├── core/       # EventBus(Autoload), GameManager, EnvLoader, SaveSyncService
  ├── resources/  # Resource 스크립트 정의 (.gd) 및 데이터 파일 (.tres)
  ├── systems/    # TacticalPinSystem, BulletTimeController, EgoCalculator, DialogueService
  ├── entities/   # UnitBase, HeroUnit, MonsterUnit, TacticalPinNode
  ├── scenes/     # CombatArena.tscn, LobbyBase.tscn
  └── ui/         # CombatHUD.tscn, HeroPortraitCard.tscn, CounterProposalPopup.tscn
