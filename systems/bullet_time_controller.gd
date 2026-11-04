class_name BulletTimeController
extends Node
## EventBus.bullet_time_requested 소스 집합 기반 time_scale 제어 + 비네팅/로우패스 연출.

@export var slow_scale: float = 0.15
@export var transition_time: float = 0.12   ## 실시간(초)
@export var vignette: CanvasItem            ## 선택: 비네팅 오버레이
@export var lowpass_cutoff_hz: float = 900.0
@export var audio_bus: StringName = &"Master"

var _sources: Dictionary = {}               ## StringName -> true
var _active: bool = false
var _from: float = 1.0
var _to: float = 1.0
var _t0_usec: int = 0
var _bus_idx: int = -1
var _fx_idx: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_lowpass()
	if vignette:
		vignette.modulate.a = 0.0
		vignette.visible = false
	EventBus.bullet_time_requested.connect(_on_requested)
	set_process(false)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _bus_idx >= 0 and _fx_idx >= 0:
		AudioServer.remove_bus_effect(_bus_idx, _fx_idx)
		_fx_idx = -1


func is_active() -> bool:
	return _active


func _on_requested(source: StringName, active: bool) -> void:
	if active:
		_sources[source] = true
	else:
		_sources.erase(source)
	var want: bool = not _sources.is_empty()
	if want == _active:
		return
	_active = want
	_apply(want)
	EventBus.bullet_time_toggled.emit(want)


func _apply(on: bool) -> void:
	# 4.3 Tween 은 time_scale 영향을 받으므로 실시간(usec) 기준 수동 보간
	_from = Engine.time_scale
	_to = slow_scale if on else 1.0
	_t0_usec = Time.get_ticks_usec()
	if vignette:
		vignette.visible = true
	_set_lowpass(on)
	set_process(true)


func _process(_delta: float) -> void:
	var t: float = 1.0
	if transition_time > 0.0:
		t = clampf(float(Time.get_ticks_usec() - _t0_usec) / (transition_time * 1_000_000.0), 0.0, 1.0)
	Engine.time_scale = lerpf(_from, _to, t)
	if vignette:
		vignette.modulate.a = inverse_lerp(1.0, slow_scale, Engine.time_scale)
	if t >= 1.0:
		set_process(false)
		if vignette and not _active:
			vignette.visible = false


func _setup_lowpass() -> void:
	_bus_idx = AudioServer.get_bus_index(audio_bus)
	if _bus_idx < 0:
		return
	var fx: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	fx.cutoff_hz = lowpass_cutoff_hz
	AudioServer.add_bus_effect(_bus_idx, fx)
	_fx_idx = AudioServer.get_bus_effect_count(_bus_idx) - 1
	AudioServer.set_bus_effect_enabled(_bus_idx, _fx_idx, false)


func _set_lowpass(on: bool) -> void:
	if _bus_idx >= 0 and _fx_idx >= 0:
		AudioServer.set_bus_effect_enabled(_bus_idx, _fx_idx, on)
