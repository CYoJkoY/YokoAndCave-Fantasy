extends "res://projectiles/player_explosion.gd"

const DURATION: float = 0.48

var _age: float = 0.0
var _damage_age: float = 0.0
var _active: bool = false

onready var _bloom: Sprite = $Bloom
onready var _ring: Sprite = $Ring
onready var _sparks: CPUParticles2D = $Sparks


func _ready() -> void:
    set_process(false)
    set_physics_process(false)


func start_explosion() -> void:
    _age = 0.0
    _damage_age = 0.0
    _active = true
    _hitbox.from = self
    _hitbox.active = true
    _hitbox.enable()
    _hitbox.player_attack_id = -1
    visible = true
    modulate.a = ProgressData.settings.explosion_opacity
    _sparks.emitting = false
    _sparks.restart()
    _sparks.emitting = ProgressData.settings.visual_effects
    _refresh_visuals()
    set_process(true)
    set_physics_process(true)


func _physics_process(delta: float) -> void:
    if not _active:
        return
    if not sound_played:
        ._physics_process(delta)
        set_physics_process(true)
        return
    _damage_age += delta
    if _damage_age >= 0.06:
        _hitbox.active = false
        _hitbox.disable()
        set_physics_process(false)


func _process(delta: float) -> void:
    if not _active:
        return
    _age += delta
    _refresh_visuals()
    if _age >= DURATION:
        _active = false
        _sparks.emitting = false
        set_process(false)
        set_physics_process(false)
        end_explosion()


func _refresh_visuals() -> void:
    var progress: float = clamp(_age / DURATION, 0.0, 1.0)
    _sprite.material.set_shader_param("progress", progress)
    var shock: float = 1.0 - pow(1.0 - min(1.0, _age / 0.24), 3.0)
    _ring.scale = Vector2.ONE * (0.18 + shock * 0.9)
    _ring.modulate = Color(0.8, 0.5, 1.0, pow(1.0 - progress, 1.6))
    _ring.rotation = progress * 0.2
    _bloom.scale = Vector2.ONE * (0.65 + shock * 0.55)
    _bloom.modulate = Color(0.65, 0.3, 1.0, pow(max(0.0, 1.0 - _age / 0.25), 2.0))


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    _hitbox.ignored_objects.append(thing_hit)
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)
