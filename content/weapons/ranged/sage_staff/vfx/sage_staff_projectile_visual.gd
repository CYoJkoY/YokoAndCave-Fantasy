extends Node2D

const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const ART = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const Phase = EFFECT.Phase
const SCATTER_DURATION: float = EFFECT.SCATTER_DURATION
const HOVER_DURATION: float = EFFECT.HOVER_DURATION
const TRAIL_LIFETIME: float = 0.12
const HIT_FADE_DURATION: float = 0.10
const RANGE_FADE_DURATION: float = 0.16

onready var _body: Node2D = get_parent()
onready var _sprite: Sprite = $"../Sprite"
onready var _energy_trail: Line2D = $"../EnergyTrail"

var _element: int = EFFECT.Element.WATER
var _phase: int = Phase.SCATTER
var _alive: bool = false
var _elapsed: float = 0.0
var _visual_age: float = 0.0
var _visual_seed: float = 0.0
var _launch_age: float = -1.0
var _launch_origin: Vector2
var _end_age: float = -1.0
var _end_duration: float = RANGE_FADE_DURATION
var _end_origin: Vector2
var _end_target: Vector2
var _end_scale: Vector2
var _trail: PoolVector2Array = PoolVector2Array()
var _trail_times: PoolRealArray = PoolRealArray()


func _ready() -> void:
    set_process(false)


func start(element: int, visual_seed: float) -> void:
    _element = element
    _phase = Phase.SCATTER
    _alive = true
    _elapsed = 0.0
    _visual_age = 0.0
    _visual_seed = visual_seed
    _launch_age = -1.0
    _end_age = -1.0
    _trail = PoolVector2Array([global_position])
    _trail_times = PoolRealArray([0.0])
    _sprite.visible = true
    _sprite.position = Vector2.ZERO
    _sprite.modulate = Color.white
    _sprite.scale = Vector2.ONE * 0.67
    _sprite.rotation = -_body.rotation
    _sprite.material.set_shader_param("tint", ART.COLORS[_element])
    _sprite.material.set_shader_param("element", _element)
    _sprite.material.set_shader_param("seed", _visual_seed)
    _sprite.material.set_shader_param("age", 0.0)
    _sprite.material.set_shader_param("charge", 0.0)
    _sprite.material.set_shader_param("flight", 0.0)
    _sprite.material.set_shader_param("launch", 0.0)
    _energy_trail.clear_points()
    _energy_trail.visible = false
    _energy_trail.material.set_shader_param("tint", ART.COLORS[_element])
    _energy_trail.material.set_shader_param("seed", _visual_seed)
    _energy_trail.material.set_shader_param("age", 0.0)
    set_process(true)
    update()


func hover() -> void:
    _phase = Phase.HOVER
    _trail.resize(0)
    _trail_times.resize(0)
    _energy_trail.visible = false


func launch(reset_trail: bool, elapsed: float) -> void:
    _phase = Phase.FLIGHT
    _elapsed = elapsed
    if reset_trail:
        _trail = PoolVector2Array([global_position])
        _trail_times = PoolRealArray([_elapsed])
    _launch_age = 0.0
    _launch_origin = global_position
    _sprite.material.set_shader_param("flight", 1.0)
    _update_energy_trail()


func advance_motion(elapsed: float) -> void:
    _elapsed = elapsed
    if _phase != Phase.HOVER and (_trail.empty() or _trail[_trail.size() - 1].distance_squared_to(global_position) >= 4.0):
        _trail.append(global_position)
        _trail_times.append(_elapsed)
    while not _trail.empty() and (_trail.size() > 12 or _elapsed - _trail_times[0] > TRAIL_LIFETIME \
        or (_trail.size() > 2 and _trail[0].distance_squared_to(global_position) > 16384.0)):
        _trail.remove(0)
        _trail_times.remove(0)
    _update_energy_trail()


func stop(on_hit: bool, hit_position: Vector2) -> void:
    _alive = false
    _end_age = 0.0
    _end_duration = HIT_FADE_DURATION if on_hit else RANGE_FADE_DURATION
    _end_origin = global_position
    _end_target = hit_position if on_hit else _end_origin
    _end_scale = _sprite.scale
    if _phase != Phase.HOVER:
        if _trail.empty() or _trail[_trail.size() - 1].distance_squared_to(global_position) >= 4.0:
            _trail.append(global_position)
            _trail_times.append(_elapsed)
        else:
            _trail[_trail.size() - 1] = global_position
    _update_energy_trail()


func reset() -> void:
    _alive = false
    _end_age = -1.0
    _launch_age = -1.0
    _sprite.visible = false
    _sprite.position = Vector2.ZERO
    _sprite.modulate = Color.white
    _trail.resize(0)
    _trail_times.resize(0)
    _energy_trail.clear_points()
    _energy_trail.visible = false
    set_process(false)
    update()


func _process(delta: float) -> void:
    _visual_age += delta
    if _launch_age >= 0.0:
        _launch_age += delta
    if _alive:
        var charge: float = clamp((_elapsed - SCATTER_DURATION) / HOVER_DURATION, 0.0, 1.0) if _phase == Phase.HOVER else 0.0
        _sprite.material.set_shader_param("age", _visual_age)
        _sprite.material.set_shader_param("charge", charge)
        _sprite.material.set_shader_param("launch", exp(-_launch_age * 18.0) if _launch_age >= 0.0 else 0.0)
        var visual_angle: float = PI * 0.5 if _phase == Phase.FLIGHT else -_body.rotation + sin(_visual_age * 4.0 + _visual_seed) * 0.24
        _sprite.rotation = lerp_angle(_sprite.rotation, visual_angle, 1.0 - exp(-delta * 24.0))
        var breath: float = sin(_visual_age * 8.0 + _visual_seed)
        _sprite.scale = Vector2.ONE * (0.67 + breath * 0.025 + charge * 0.035)
        if _phase == Phase.HOVER:
            _sprite.scale *= Vector2(1.0 - charge * 0.10 + breath * 0.035, 1.0 + charge * 0.09 - breath * 0.025)
    elif _end_age >= 0.0:
        _end_age = min(_end_duration, _end_age + delta)
        var progress: float = _end_age / _end_duration
        var gather: float = smoothstep(0.0, 0.55, progress)
        _sprite.global_position = _end_origin.linear_interpolate(_end_target, gather)
        _sprite.scale = _end_scale * lerp(1.0, 0.35, smoothstep(0.0, 1.0, progress))
        _sprite.modulate.a = _get_visual_fade()
        _sprite.visible = _sprite.modulate.a > 0.0
        _sprite.material.set_shader_param("age", _visual_age)
        _sprite.material.set_shader_param("launch", 0.0)
        _update_energy_trail()
    if _energy_trail.visible:
        _energy_trail.material.set_shader_param("age", _visual_age)
    update()


func _draw() -> void:
    var fade: float = _get_visual_fade()
    var color: Color = ART.COLORS[_element]
    if _alive:
        var birth: float = min(1.0, _visual_age / 0.08)
        if _phase != Phase.FLIGHT:
            for i in range(3):
                var angle: float = _visual_age * (2.2 + i * 0.35) + i * 2.4 + _visual_seed
                var point: Vector2 = Vector2(cos(angle), sin(angle * 1.3) * 0.70) * (18.0 + sin(angle * 1.7) * 5.0)
                var extent: Vector2 = Vector2.ONE * (9.0 + sin(angle) * 3.0)
                color.a = (0.24 + (sin(angle * 1.7) + 1.0) * 0.16) * birth
                draw_set_transform(point, -_body.rotation, Vector2.ONE)
                draw_texture_rect(ART.SPARK, Rect2(-extent * 0.5, extent), false, color)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if _launch_age >= 0.0 and _launch_age < 0.18:
        var t: float = _launch_age / 0.18
        color.a = pow(1.0 - t, 1.8) * fade * 0.32
        var center: Vector2 = to_local(_launch_origin)
        var extent: Vector2 = Vector2.ONE * (42.0 + t * 38.0)
        draw_texture_rect(ART.GLOW, Rect2(center - extent * 0.5, extent), false, color)
        color.a *= 1.6
        draw_texture_rect(ART.FLARE, Rect2(center - Vector2.ONE * 26.0, Vector2.ONE * 52.0), false, color)


func _update_energy_trail() -> void:
    var fade: float = _get_visual_fade()
    _energy_trail.visible = _phase != Phase.HOVER and _trail.size() >= 2 and fade > 0.0
    if not _energy_trail.visible:
        return
    var points: PoolVector2Array = PoolVector2Array()
    points.resize(_trail.size())
    var head: Vector2 = _sprite.global_position
    var collapse: float = 1.0 - fade
    for i in range(_trail.size()):
        var point: Vector2 = _trail[i]
        if i > 0 and i < _trail.size() - 1:
            point = _trail[i - 1] * 0.25 + point * 0.5 + _trail[i + 1] * 0.25
        points[i] = to_local(point.linear_interpolate(head, collapse))
    points[points.size() - 1] = to_local(head)
    _energy_trail.points = points
    var strength: float = 1.0 if _phase == Phase.FLIGHT else 0.50 * (1.0 - smoothstep(0.18, SCATTER_DURATION, _elapsed))
    _energy_trail.width = 40.0 * strength * lerp(0.35, 1.0, fade)
    _energy_trail.modulate.a = fade * strength


func _get_visual_fade() -> float:
    if _alive:
        return 1.0
    if _end_age < 0.0:
        return 0.0
    return 1.0 - smoothstep(0.0, 1.0, _end_age / _end_duration)
