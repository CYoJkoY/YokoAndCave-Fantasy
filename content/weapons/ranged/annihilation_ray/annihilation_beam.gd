extends "res://projectiles/player_projectile.gd"

const DAMAGE_DURATION: float = 0.085
const DURATION: float = 0.34
const VISUAL_PADDING: float = 64.0
const BASE_RANGE: float = 800.0
const BASE_WIDTH: float = 22.0
const MIN_WIDTH: float = 14.0
const MAX_WIDTH: float = 44.0

var _age: float = 0.0
var _alive: bool = false
var _length: float = 800.0
var _width_scale: float = 1.0

onready var _wake: Sprite = $Wake
onready var _flare: Sprite = $Flare
onready var _sparks: CPUParticles2D = $Sparks


func shoot_ex(p_from: Node, pos: Vector2, _velocity: Vector2, p_rotation: float,
    p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array,
    hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    _age = 0.0
    _alive = true
    player_index = p_from.player_index
    _length = max(40.0, p_weapon_stats.max_range + PROJECTILE_HALF_ADDITIONAL_DISTANCE)
    _width_scale = clamp(float(p_weapon_stats.max_range) / BASE_RANGE, MIN_WIDTH / BASE_WIDTH, MAX_WIDTH / BASE_WIDTH)
    .shoot_ex(p_from, pos, Vector2.ZERO, p_rotation, p_weapon_stats,
        damage_tracking_key, effects, hitbox_args, knockback_direction)
    _time_until_max_range = INF
    _hitbox._collision.position = Vector2(_length * 0.5, 0)
    _hitbox._collision.shape.extents = Vector2(_length * 0.5, BASE_WIDTH * _width_scale * 0.5)
    _sprite.position = Vector2(_length * 0.5, 0)
    _sprite.scale.x = (_length + VISUAL_PADDING * 2.0) / 512.0
    _sprite.material.set_shader_param("beam_length", _length)
    _sprite.material.set_shader_param("beam_padding", VISUAL_PADDING)
    _wake.position = _sprite.position
    _wake.scale.x = _sprite.scale.x
    modulate.a = ProgressData.settings.projectile_opacity
    _sparks.emitting = false
    _sparks.scale.y = _width_scale
    _sparks.restart()
    _sparks.emitting = ProgressData.settings.visual_effects
    _refresh_visuals()


func _physics_process(delta: float) -> void:
    if not _alive:
        return
    if not is_instance_valid(_hitbox.from) or _hitbox.from.is_queued_for_deletion() \
        or _hitbox.from._parent.dead or _hitbox.from._parent.cleaning_up:
        stop()
        return
    _age += delta
    if _age >= DAMAGE_DURATION and _hitbox.active:
        _hitbox.active = false
        _hitbox.disable()
    if _age >= DURATION:
        stop()
        return
    _refresh_visuals()


func _refresh_visuals() -> void:
    var reveal: float = min(1.0, _age / 0.025)
    var fade: float = pow(1.0 - clamp((_age - 0.075) / (DURATION - 0.075), 0.0, 1.0), 1.5)
    _sprite.scale.y = _width_scale * (0.7 + reveal * 0.3) * (0.18 + fade * 0.82)
    _sprite.modulate.a = fade
    _sprite.material.set_shader_param("phase", _age)
    _wake.scale.y = _width_scale * (0.6 + (1.0 - fade) * 0.7)
    _wake.modulate = Color(0.42, 0.12, 1.0, fade * 0.32)
    _flare.scale = Vector2(1.0, _width_scale) * (0.15 + fade * 0.24)
    _flare.modulate = Color(0.87, 0.7, 1.0, fade)


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    if not _alive or not _hitbox.active or _hitbox.ignored_objects.has(thing_hit):
        return
    _hitbox.ignored_objects.append(thing_hit)
    emit_signal("hit_something", thing_hit, damage_dealt)
    RunData.manage_life_steal(_weapon_stats, player_index)
    if is_instance_valid(_hitbox.from):
        _hitbox.from.detonate_ray(thing_hit.global_position, _hitbox)
    if _piercing <= 0:
        _hitbox.active = false
        _hitbox.disable()
    else:
        _piercing -= 1
        if _hitbox.damage > 0:
            _hitbox.damage = max(1, _hitbox.damage - (_hitbox.damage * _weapon_stats.piercing_dmg_reduction))


func stop() -> void:
    if not _alive:
        return
    _alive = false
    _sparks.emitting = false
    .stop()
