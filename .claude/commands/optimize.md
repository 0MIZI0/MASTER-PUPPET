지정된 GDScript를 감사하고 수정된 코드만 출력해:
1. 모든 변수/매개변수/반환값에 정적 타이핑(Static Typing) 100% 강제.
2. _process / _physics_process 내 메모리 할당(new, 배열 생성) 및 get_node 탐색 제거 -> EventBus 시그널 또는 캐싱으로 전환.
3. 하드코딩된 밸런스 수치를 커스텀 Resource(.tres) 속성으로 분리.
