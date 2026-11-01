extends Node2D

const MOTE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/annihilation_ray/vfx/textures/energy_mote.webp")

var _clock: float = 0.0
var _charge: float = 0.0
var _details: bool = true
var _random = RandomNumberGenerator.new()
var _motes: Array = []

onready var _orb: Sprite = $Orb
onready var _halo: Sprite = $Halo


func _ready() -> void:
    _random.randomize()
    for i in range(25):
        var mote: Dictionary = {"near": i >= 20}
        _reset_mote(mote)
        mote.phase = _random.randf()
        _motes.append(mote)


func refresh(delta: float, charge: float, flash: float, opacity: float) -> void:
    _clock += delta
    _charge = charge
    _details = ProgressData.settings.visual_effects
    if _details and charge > 0.0:
        for mote in _motes:
            mote.phase += delta / mote.duration
            if mote.phase >= 1.0:
                _reset_mote(mote)
    modulate.a = opacity
    visible = charge > 0.005 or flash > 0.005
    var tremor: Vector2 = Vector2(sin(_clock * 97.0) + sin(_clock * 139.0) * 0.4,
        cos(_clock * 83.0) + sin(_clock * 117.0) * 0.4) * charge * charge * 0.9
    var size: float = (0.05 + pow(charge, 0.85) * 0.65 + flash * 0.69) * 0.8
    _orb.position = tremor
    _orb.scale = Vector2.ONE * size * (1.0 + sin(_clock * 43.0) * charge * 0.018)
    _orb.modulate.a = min(1.0, charge * 1.7 + flash) * 0.8
    _orb.material.set_shader_param("phase", _clock)
    _orb.material.set_shader_param("charge", charge)
    _orb.material.set_shader_param("flash", flash)
    var ready_glow: float = smoothstep(0.78, 1.0, charge)
    _halo.scale = Vector2.ONE * (0.4 + charge * 0.32 + ready_glow * 0.05 + flash * 0.5) * 0.85
    _halo.modulate = Color(0.60 + ready_glow * 0.12 + flash * 0.22,
        0.28 + ready_glow * 0.10 + flash * 0.30, 1.0, charge * 0.24 + ready_glow * 0.05 + flash * 0.44)
    update()


func _draw() -> void:
    if not _details or _charge <= 0.0:
        return
    var absorption: float = smoothstep(0.0, 0.08, _charge) * (0.55 + _charge * 0.45)
    for mote in _motes:
        var phase: float = mote.phase
        var point: Vector2 = _mote_position(mote, phase)
        var tangent: Vector2 = point - _mote_position(mote, max(0.0, phase - 0.02))
        var fade: float = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.86, 1.0, phase)) * absorption * mote.opacity
        if mote.trail and phase > 0.35:
            var tail_fade: float = fade * smoothstep(0.35, 0.65, phase)
            var tip: Vector2 = point
            for segment in range(4):
                var tail: Vector2 = _mote_position(mote, phase - float(segment + 1) * 0.035)
                var length: float = tip.distance_to(tail)
                var trail_size: Vector2 = Vector2(length + 5.0, 5.0 - float(segment) * 0.7)
                draw_set_transform((tip + tail) * 0.5, (tip - tail).angle(), Vector2.ONE)
                draw_texture_rect(MOTE, Rect2(-trail_size * 0.5, trail_size), false,
                    Color(0.75, 0.52, 1.0, tail_fade * (0.42 - float(segment) * 0.09)))
                tip = tail
        var size: Vector2 = Vector2(20.0, 8.5) * (0.35 + phase * 0.8) * mote.size
        draw_set_transform(point, tangent.angle(), Vector2.ONE)
        draw_texture_rect(MOTE, Rect2(-size * 0.5, size), false, Color(0.83, 0.67, 1.0, fade))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _reset_mote(mote: Dictionary) -> void:
    mote.phase = 0.0
    mote.angle = _random.randf_range(0.0, TAU)
    mote.radius = _random.randf_range(34.0, 46.0) if mote.near else _random.randf_range(46.0, 72.0)
    mote.duration = _random.randf_range(0.40, 0.68) if mote.near else _random.randf_range(0.30, 0.55)
    mote.bend = _random.randf_range(-0.55, 0.55)
    mote.size = _random.randf_range(0.45, 0.7) if mote.near else _random.randf_range(0.75, 1.2)
    mote.opacity = _random.randf_range(0.35, 0.6) if mote.near else _random.randf_range(0.65, 0.95)
    mote.trail = not mote.near and _random.randf() < 0.33


func _mote_position(mote: Dictionary, phase: float) -> Vector2:
    var angle: float = mote.angle + sin(phase * PI * 0.5) * mote.bend
    var direction: Vector2 = Vector2(cos(angle), sin(angle))
    var surface: float = _orb.scale.x * 64.0 * 0.68 + 1.0
    var radius: float = lerp(mote.radius, surface, phase * phase)
    return direction * radius
