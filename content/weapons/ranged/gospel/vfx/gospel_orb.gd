extends Node2D

const VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")
const GLOW = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/gospel/vfx/textures/holy_glow.webp")
const MOTE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/gospel/vfx/textures/holy_mote.webp")
const BODY_RADIUS: float = 32.0

var attack_ready: bool = true
var _last_position: Vector2
var _last_center: Vector2
var _time: float = 0.0
var _energy: float = 0.0
var _motion: float = 0.0
var _readiness: float = 1.0
var _impact_age: float = 1.0
var _impact_position: Vector2
var _active: bool = true

onready var _sphere: Sprite = $Sphere
onready var _glow: Sprite = $Glow
onready var _motes: CPUParticles2D = $Motes
onready var _glow_size: float = BODY_RADIUS * 5.4 / float(_glow.texture.get_width())


func _ready() -> void:
    _sphere.scale = Vector2.ONE * BODY_RADIUS / (float(_sphere.texture.get_width()) * 0.21)
    _motes.emission_sphere_radius = BODY_RADIUS * 0.82


func initialize(point: Vector2, center: Vector2, phase: float, cursed: bool) -> void:
    _time = phase
    _motion = 0.0
    _last_center = center
    global_position = point
    _last_position = global_position
    _sphere.material.set_shader_param("cursed", 1.0 if cursed else 0.0)


func set_active(active: bool) -> void:
    if _active == active:
        return
    _active = active
    visible = active
    _motes.emitting = active
    if not active:
        _impact_age = 1.0
        _motion = 0.0
        update()


func advance(delta: float, point: Vector2, center: Vector2) -> void:
    global_position = point
    global_rotation = 0.0
    if center.distance_squared_to(_last_center) > 16384.0:
        _motion = 0.0
    elif delta > 0.0:
        var movement: Vector2 = point - _last_position - (center - _last_center)
        var intensity: float = clamp((movement.length() / delta - 430.0) / 550.0, 0.0, 1.0)
        _motion = lerp(_motion, intensity, 1.0 - exp(-delta * 10.0))
    _last_position = global_position
    _last_center = center


func play_impact(world_position: Vector2) -> void:
    _energy = 1.0
    _impact_age = 0.0
    _impact_position = world_position


func _process(delta: float) -> void:
    if not _active:
        return
    _time += delta
    _energy = max(0.0, _energy - delta * 4.0)
    _readiness = lerp(_readiness, 1.0 if attack_ready else 0.65, 1.0 - exp(-delta * 8.0))
    if _impact_age < 0.45:
        _impact_age += delta
        update()
    modulate.a = VISUAL_UTILS.get_opacity()
    _sphere.material.set_shader_param("age", _time)
    _sphere.material.set_shader_param("energy", _energy)
    _sphere.material.set_shader_param("readiness", _readiness)
    _sphere.material.set_shader_param("motion", _motion)
    var pulse: float = sin(_time * 1.7 - 0.55)
    _glow.scale = Vector2.ONE * _glow_size * (1.0 + _energy * 0.08 + _motion * 0.04 + pulse * 0.032)
    _glow.modulate.a = 0.42 + pulse * 0.035 + _energy * 0.12 + _motion * 0.07
    _motes.rotation = _time * 0.35


func _draw() -> void:
    if _impact_age >= 0.45:
        return
    var t: float = _impact_age / 0.45
    var size: float = lerp(80.0, 160.0, 1.0 - pow(1.0 - t, 3.0))
    var center: Vector2 = to_local(_impact_position)
    draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size),
        false, Color(1.0, 0.94, 0.72, pow(1.0 - t, 1.5) * 0.9))
    for i in range(5):
        var angle: float = float(i) * TAU / 5.0 + 0.4
        var point: Vector2 = center + Vector2.RIGHT.rotated(angle) * (12.0 + t * 48.0)
        var mote_size: float = (1.0 - t) * (13.0 if i % 2 == 0 else 8.0)
        draw_texture_rect(MOTE, Rect2(point - Vector2.ONE * mote_size * 0.5, Vector2.ONE * mote_size),
            false, Color(1.0, 0.96, 0.78, (1.0 - t) * 0.65))
