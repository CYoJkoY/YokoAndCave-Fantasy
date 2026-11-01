extends Node2D

const VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")
const BLOOM = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/apocalypse/vfx/textures/curse_bloom.webp")

onready var _field: Sprite = $Field
onready var _core: Sprite = $Core
onready var _motes: CPUParticles2D = $Motes
onready var _burst: CPUParticles2D = $Burst

var energy: float = 0.0
var _radius: float = -1.0
var _time: float = 0.0
var _active: bool = true
var _cursed: bool = false
var _waves: Array = []
var _blooms: Array = []
var _burst_cd: float = 0.0


func set_radius(radius: float) -> void:
    radius = max(1.0, radius)
    if is_equal_approx(_radius, radius): return
    _radius = radius
    _field.scale = Vector2.ONE * radius / 256.0
    _motes.emission_sphere_radius = radius * 0.9


func set_cursed(cursed: bool) -> void:
    _cursed = cursed
    _field.material.set_shader_param("cursed", 1.0 if cursed else 0.0)


func set_active(active: bool) -> void:
    if _active == active: return
    _active = active
    visible = active
    _motes.emitting = active
    if not active:
        _burst.emitting = false
        _waves.clear()
        _blooms.clear()
        update()
        energy = 0.0


func play_pulse() -> void:
    energy = 1.0
    if _waves.size() >= 3: _waves.pop_front()
    _waves.append(0.0)
    if _burst_cd <= 0.0:
        _burst.restart()
        _burst.emitting = true
        _burst_cd = 0.16


func add_bloom(world_position: Vector2) -> void:
    if _blooms.size() >= 32: _blooms.pop_front()
    _blooms.append([world_position, 0.0, rand_range(-PI, PI)])


func _process(delta: float) -> void:
    if not _active: return
    _time += delta
    _burst_cd -= delta
    energy = max(0.0, energy - delta * 3.2)
    modulate.a = VISUAL_UTILS.get_opacity()
    for i in range(_waves.size() - 1, -1, -1):
        _waves[i] += delta
        if _waves[i] > 0.8: _waves.remove(i)
    var wave_ages: Color = Color(-1.0, -1.0, -1.0, 0.0)
    for i in range(_waves.size()): wave_ages[i] = _waves[i]
    _field.material.set_shader_param("age", _time)
    _field.material.set_shader_param("energy", energy)
    _field.material.set_shader_param("waves", wave_ages)
    _core.rotation = -_time * 0.13
    _core.scale = Vector2.ONE * (0.7 + sin(_time * 2.2) * 0.035 + energy * 0.18)
    _core.modulate = Color(0.55, 0.22, 0.92, 0.48 + energy * 0.35) if not _cursed else Color(0.78, 0.16, 0.8, 0.6 + energy * 0.3)
    if _blooms.empty(): return
    for i in range(_blooms.size() - 1, -1, -1):
        _blooms[i][1] += delta
        if _blooms[i][1] >= 0.55: _blooms.remove(i)
    update()


func _draw() -> void:
    for bloom in _blooms:
        var t: float = bloom[1] / 0.55
        var size: float = lerp(32.0, 100.0, pow(t, 0.6))
        var tint: Color = Color(0.78, 0.38, 1.0).linear_interpolate(Color(0.15, 0.75, 0.48), t)
        tint.a = sin(pow(t, 0.45) * PI) * 0.8
        draw_set_transform(to_local(bloom[0]), bloom[2] + t * 0.4, Vector2.ONE)
        draw_texture_rect(BLOOM, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), false, tint)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
