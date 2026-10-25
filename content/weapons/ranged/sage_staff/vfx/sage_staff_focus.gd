extends Node2D

const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")

const ART = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const RELEASE_DURATION: float = 0.80
const ECHO_DURATION: float = 0.95
const MAX_ECHOES: int = 24

onready var _circle: Sprite = $Circle
onready var _resonance: Sprite = $"../Resonance"
onready var _anchor: Node2D = $"../Muzzle"
onready var _weapon: Node2D = get_parent().get_parent()
onready var _host: Node2D = _weapon.get_parent()

var _age: float = 0.0
var _spin: float = 0.0
var _flow: float = 0.0
var _casting: float = 0.0
var _opening: float = 0.0
var _pulse: float = 0.0
var _pulse_target: float = 0.0
var _release_age: float = RELEASE_DURATION
var _emitting: bool = false
var _field_position: Vector2
var _host_position: Vector2
var _field_angle: float = 0.0
var _field_transform: Transform2D
var _echoes: Array = []
var _core_color: Color = ART.COLORS[EFFECT.Element.WATER]
var _target_color: Color = ART.COLORS[EFFECT.Element.WATER]
var _element_impulses: PoolRealArray = PoolRealArray([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _element_pulses: PoolRealArray = PoolRealArray([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
    var gradient: Gradient = Gradient.new()
    gradient.offsets = PoolRealArray([0.0, 1.0 / 6.0, 2.0 / 6.0, 0.5, 4.0 / 6.0, 5.0 / 6.0, 1.0])
    var colors: PoolColorArray = PoolColorArray(ART.COLORS)
    colors.append(ART.COLORS[EFFECT.Element.WATER])
    gradient.colors = colors
    var palette: GradientTexture = GradientTexture.new()
    palette.width = 128
    palette.gradient = gradient
    _circle.material.set_shader_param("palette", palette)
    _resonance.material.set_shader_param("palette", palette)
    reset_anchor()
    _process(0.0)


func reset_anchor() -> void:
    _host_position = _host.global_position
    _field_position = _anchor.global_position
    _field_angle = _weapon.global_rotation
    _echoes.clear()
    _update_anchor(0.0)


func _update_anchor(delta: float) -> void:
    var host_position: Vector2 = _host.global_position
    _field_position += host_position - _host_position
    _host_position = host_position
    _field_position = _field_position.linear_interpolate(_anchor.global_position, 1.0 - exp(-delta * 3.2))
    _field_angle = lerp_angle(_field_angle, _weapon.global_rotation, 1.0 - exp(-delta * 2.0))
    var base_scale: Vector2 = _weapon.global_scale.abs()
    _field_transform = Transform2D(Vector2.RIGHT.rotated(_field_angle) * base_scale.x,
        Vector2.DOWN.rotated(_field_angle) * base_scale.y, _field_position)
    global_transform = _field_transform


func set_casting(value: bool) -> void:
    if _emitting and not value:
        _release_age = 0.0
        for i in range(ART.COLORS.size()):
            _emit_echo(i)
    _emitting = value


func flash(element: int) -> void:
    _pulse_target = 1.0
    _element_impulses[element] = 1.0
    _target_color = ART.COLORS[element]
    _emit_echo(element)


func _emit_echo(element: int) -> void:
    _echoes.append({"age": 0.0, "element": element,
        "angle": float(element) * TAU / 6.0 + sin(_flow * 1.7) * 0.16,
        "origin": _field_transform * _circle.transform})
    if _echoes.size() > MAX_ECHOES:
        _echoes.pop_front()


func _process(delta: float) -> void:
    _age += delta
    _update_anchor(delta)
    _release_age = min(RELEASE_DURATION, _release_age + delta)
    _pulse_target *= exp(-delta * 8.0)
    _pulse = lerp(_pulse, _pulse_target, 1.0 - exp(-delta * 24.0))
    _casting = lerp(_casting, 1.0 if _emitting else 0.0, 1.0 - exp(-delta * 10.0))
    _opening = lerp(_opening, _casting, 1.0 - exp(-delta * 4.0))
    _spin += delta * (0.10 + _opening * 0.18)
    _flow += delta * (0.85 + _opening * 1.40)
    _core_color = _core_color.linear_interpolate(_target_color, 1.0 - exp(-delta * 10.0))
    var decay: float = exp(-delta * 6.0)
    var response: float = 1.0 - exp(-delta * 26.0)
    for i in range(_element_pulses.size()):
        _element_impulses[i] *= decay
        _element_pulses[i] = lerp(_element_pulses[i], _element_impulses[i], response)
    for i in range(_echoes.size() - 1, -1, -1):
        _echoes[i].age += delta
        if _echoes[i].age >= ECHO_DURATION:
            _echoes.remove(i)
    modulate.a = ProgressData.settings.projectile_opacity
    _resonance.modulate.a = modulate.a
    var lean: float = -0.16 + sin(_age * 0.65) * 0.10
    var radius: float = 0.60 * (1.0 + _opening * 0.08)
    var x_axis: Vector2 = Vector2(cos(_spin), sin(_spin)).rotated(lean) * radius
    var y_axis: Vector2 = Vector2(-sin(_spin), cos(_spin)).rotated(lean) * radius
    _circle.transform = Transform2D(x_axis, y_axis, Vector2.ZERO)
    _circle.material.set_shader_param("flow", _flow)
    _circle.material.set_shader_param("energy", _opening)
    _circle.material.set_shader_param("pulse", _pulse)
    _circle.material.set_shader_param("release_progress", _release_age / RELEASE_DURATION)
    _circle.material.set_shader_param("pulses_a", Vector3(_element_pulses[0], _element_pulses[1], _element_pulses[2]))
    _circle.material.set_shader_param("pulses_b", Vector3(_element_pulses[3], _element_pulses[4], _element_pulses[5]))
    _resonance.material.set_shader_param("flow", _flow)
    _resonance.material.set_shader_param("orbit_spin", _field_angle - get_parent().global_rotation + _spin)
    _resonance.material.set_shader_param("energy", _casting)
    _resonance.material.set_shader_param("pulse", _pulse)
    _resonance.material.set_shader_param("tint", _core_color)
    update()


func _draw() -> void:
    var field_inverse: Transform2D = global_transform.affine_inverse()
    var glow: Color = _core_color
    glow.a = 0.09 + _opening * 0.10 + _pulse * 0.10
    var size: float = 34.0 + _opening * 14.0
    var core: Vector2 = to_local(_anchor.global_position)
    draw_texture_rect(ART.GLOW, Rect2(core - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, glow)
    for i in range(_element_pulses.size()):
        var angle: float = float(i) * TAU / 6.0
        var pulse: float = _element_pulses[i]
        var travel: float = fposmod(_flow * 0.24 + float(i) * 0.19, 1.0)
        var radius: float = 128.0 * (0.54 + travel * 0.47)
        var point: Vector2 = _circle.transform.basis_xform(Vector2.RIGHT.rotated(angle + travel * 0.12) * radius)
        var color: Color = ART.COLORS[i].linear_interpolate(Color.white, 0.12 + pulse * 0.12)
        var envelope: float = sin(travel * PI)
        color.a = envelope * (0.18 + _opening * 0.24 + pulse * 0.26)
        size = 6.0 + pulse * 4.0 + envelope * 3.0
        draw_texture_rect(ART.SPARK, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)
        color.a *= 0.28
        size *= 2.2
        draw_texture_rect(ART.GLOW, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)
    for echo in _echoes:
        var t: float = echo.age / ECHO_DURATION
        var distance: float = 72.0 + (1.0 - pow(1.0 - t, 2.0)) * 120.0
        var angle: float = echo.angle + t * 0.42
        var point: Vector2 = field_inverse.xform(echo.origin.xform(Vector2.RIGHT.rotated(angle) * distance))
        var color: Color = ART.COLORS[echo.element]
        color.a = smoothstep(0.0, 0.12, t) * pow(1.0 - t, 1.6) * 0.58
        var extent: Vector2 = Vector2(5.0, 13.0) * (0.65 + (1.0 - t) * 0.35)
        var direction: Vector2 = field_inverse.basis_xform(echo.origin.basis_xform(Vector2.RIGHT.rotated(angle)))
        draw_set_transform(point, direction.angle() + PI * 0.5, Vector2.ONE)
        draw_texture_rect(ART.SHARD, Rect2(-extent * 0.5, extent), false, color)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        color.a *= 0.22
        size = 18.0 + t * 12.0
        draw_texture_rect(ART.GLOW, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)
