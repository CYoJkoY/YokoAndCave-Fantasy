extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"

const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const EMISSION_INTERVAL: float = EFFECT.EMISSION_INTERVAL
const GOLDEN_ANGLE: float = 2.39996323

var _remaining: int = 0
var _count: int = 0
var _elapsed: float = 0.0
var _angle: float = 0.0
var _attack_id: int = 0
var _burst_stats: RangedWeaponStats


func _ready() -> void:
    set_physics_process(false)


func is_emitting() -> bool:
    return _burst_stats != null


func shoot(_distance: float) -> void:
    _parent.set_shooting(false)
    if _parent.is_queued_for_deletion() or _parent._parent.dead or _parent._parent.cleaning_up:
        return
    _burst_stats = _parent.current_stats.duplicate()
    _burst_stats.burning_data = _parent.current_stats.burning_data.duplicate()
    _count = max(1, _burst_stats.nb_projectiles)
    _remaining = _count
    _elapsed = 0.0
    _angle = rand_range(-PI, PI)
    _attack_id = _get_next_attack_id()
    _parent.begin_cast()
    SoundManager.play(Utils.get_rand_element(_burst_stats.shooting_sounds), _burst_stats.sound_db_mod, 0.2)
    set_physics_process(true)
    _emit_orb()


func _physics_process(delta: float) -> void:
    if _parent.is_queued_for_deletion() or not _parent.is_physics_processing() or _parent._parent.dead or _parent._parent.cleaning_up:
        _finish()
        return
    _elapsed += delta
    while _remaining > 0 and _elapsed >= (_count - _remaining) * EMISSION_INTERVAL:
        _emit_orb()
    if _remaining == 0 and _elapsed >= _count * EMISSION_INTERVAL:
        _finish()


func _emit_orb() -> void:
    var angle: float = _angle + GOLDEN_ANGLE * float(_count - _remaining)
    _ranged_spawn_projectile_args.effects = _parent.effects
    _ranged_spawn_projectile_args.from_player_index = _parent.player_index
    _ranged_spawn_projectile_args.knockback_direction = Vector2.RIGHT.rotated(angle)
    var projectile = WeaponService.spawn_projectile(
        _parent.muzzle.global_position, _burst_stats, angle, _parent, _ranged_spawn_projectile_args
    )
    projectile._hitbox.player_attack_id = _attack_id
    _parent.on_orb_emitted(projectile.get_element())
    emit_signal("projectile_shot", projectile)
    _remaining -= 1


func _finish() -> void:
    _parent.finish_cast()
    _remaining = 0
    _burst_stats = null
    set_physics_process(false)
