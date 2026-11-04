class_name PinTypes
extends RefCounted
## 전술 핀 타입 공용 정의.

enum Type { MOVE, FOCUS, RETREAT }

const COLORS: Array[Color] = [
	Color(0.29, 0.53, 0.91), # MOVE  청
	Color(0.85, 0.22, 0.22), # FOCUS 적
	Color(0.92, 0.78, 0.25), # RETREAT 황
]
