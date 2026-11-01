extends Node2D

const DURATION: float = 0.52
const LIGHT_SPEED: float = 8000.0

var _time: float = 0.0
var _emitter: Node2D
var _target_position: Vector2
var _length: float = 0.0
var _arrival_time: float = 0.0
var _impact_started: bool = false
var _envelope: float = 0.0

onready var _shaft: Sprite = $Shaft
onready var _afterglow: Sprite = $Afterglow
onready var _muzzle: Sprite = $Muzzle
onready var _impact: Node2D = $Impact
onready var _flare: Sprite = $Impact/Flare
onready var _aura: Sprite = $Impact/Aura
onready var _rays: Sprite = $Impact/Rays
onready var _sparks: CPUParticles2D = $Impact/Sparks


func _ready() -> void:
    set_as_toplevel(true)
    global_scale = Vector2.ONE
    visible = false
    set_process(false)


func fire(emitter: Node2D, target: Vector2) -> void:
    _emitter = emitter
    _target_position = target
    _time = 0.0
    _impact_started = false
    _sparks.emitting = false
    visible = true
    _update_geometry()
    _update_visuals()
    set_process(true)


func cancel() -> void:
    _emitter = null
    _sparks.emitting = false
    _impact_started = false
    visible = false
    set_process(false)


func _process(delta: float) -> void:
    _time += delta
    if _time >= DURATION or not is_instance_valid(_emitter):
        cancel()
        return
    _update_geometry()
    _update_visuals()


func _update_geometry() -> void:
    global_position = _emitter.global_position
    rotation = (_target_position - global_position).angle()
    _length = global_position.distance_to(_target_position)
    _shaft.position = Vector2(_length * 0.5, 0)
    _shaft.scale.x = _length / 256.0
    _afterglow.position = _shaft.position
    _afterglow.scale.x = _shaft.scale.x
    _impact.position = Vector2(_length, 0)
    _impact.rotation = -rotation
    _shaft.material.set_shader_param("beam_length", _length)
    _arrival_time = clamp(_length / LIGHT_SPEED, 0.025, 0.085)
    _shaft.material.set_shader_param("travel_time", _arrival_time)


func _update_visuals() -> void:
    var progress: float = _time / DURATION
    var rise: float = smoothstep(0.0, 0.035, _time)
    var fade: float = 1.0 - smoothstep(0.09, DURATION, _time)
    _envelope = rise * fade
    var tail: float = smoothstep(_arrival_time, _arrival_time + 0.06, _time) * pow(1.0 - progress, 1.5)
    _shaft.material.set_shader_param("phase", _time)
    _shaft.material.set_shader_param("fade", _envelope)
    _shaft.modulate.a = ProgressData.settings.projectile_opacity
    _afterglow.modulate = Color(0.60, 0.78, 1.0, tail * 0.25 * ProgressData.settings.projectile_opacity)
    _muzzle.modulate.a = _envelope * 0.9 * ProgressData.settings.explosion_opacity
    var impact_age: float = max(0.0, _time - _arrival_time)
    var impact_light: float = smoothstep(0.0, 0.016, impact_age) * (1.0 - smoothstep(0.065, 0.38, impact_age))
    _flare.modulate.a = impact_light
    _aura.modulate = Color(0.76, 0.85, 1.0, impact_light * 0.45)
    _rays.rotation = 0.2 + impact_age * 1.8
    _rays.modulate.a = impact_light * 0.85
    _impact.modulate.a = ProgressData.settings.explosion_opacity
    if not _impact_started and _time >= _arrival_time:
        _impact_started = true
        _sparks.restart()
        _sparks.emitting = true
    update()


func _draw() -> void:
    if not visible:
        return
    var opacity: float = _envelope * ProgressData.settings.projectile_opacity
    for i in range(3):
        var head: float = (_time - float(i) * 0.04) / 0.18
        var start: float = clamp(head - 0.26, 0.0, 1.0)
        var end: float = clamp(head, 0.0, 1.0)
        if end - start < 0.001:
            continue
        var points := PoolVector2Array()
        var colors := PoolColorArray()
        var glow_colors := PoolColorArray()
        var tint: Color = Color.from_hsv(0.5 + float(i) * 0.15, 0.45, 1.0)
        var alpha: float = (1.0 - smoothstep(1.0, 1.26, head)) * opacity
        for j in range(12):
            var u: float = float(j) / 11.0
            var t: float = lerp(start, end, u)
            var side: float = 1.0 if i % 2 == 0 else -1.0
            points.append(Vector2(t * _length, side * sin(t * PI) * (10.0 + sin(t * TAU + float(i)) * 3.0)))
            var brightness: float = sin(u * PI) * alpha
            colors.append(Color(tint.r, tint.g, tint.b, brightness * 0.8))
            glow_colors.append(Color(tint.r, tint.g, tint.b, brightness * 0.18))
        draw_polyline_colors(points, glow_colors, 7.0, true)
        draw_polyline_colors(points, colors, 1.6, true)
