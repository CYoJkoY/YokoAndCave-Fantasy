extends "res://weapons/shooting_behaviors/melee_weapon_shooting_behavior.gd"

enum Phase { IDLE, WINDUP, SWEEP, RECOVER }

const HALF_ANGLE: float = 1.25

var phase: int = Phase.IDLE
var attack_angle: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 0.0
var _sweep_duration: float = 0.0
var _recover_duration: float = 0.0
var _remainder: float = 0.0
var _radius: float = 0.0
var _side: float = -1.0
var _rest: Vector2


func shoot(distance: float) -> void:
    shooting_data = MeleeShootingData.new(_parent.current_stats, _parent.player_index)
    var duration: float = shooting_data.get_shooting_total_duration()
    _duration = duration * 0.24
    _sweep_duration = duration * 0.38
    _recover_duration = duration - _duration - _sweep_duration
    _radius = max(0.0, min(distance, _parent.current_stats.max_range) - 88.0)
    _rest = _parent.sprite.position
    attack_angle = _parent.rotation
    _side = -_side
    _elapsed = 0.0
    _remainder = 0.0
    phase = Phase.WINDUP
    _parent.set_shooting(true)
    _parent.disable_hitbox()
    _parent._hitbox.player_attack_id = _get_next_attack_id()
    _parent.prepare_swing(_side, _radius + 88.0)


func advance(delta: float) -> void:
    if phase == Phase.IDLE or delta <= 0.0:
        return
    if _elapsed >= _duration:
        _next_phase()
        if phase == Phase.IDLE:
            return
    var next_time: float = _elapsed + delta + _remainder
    _remainder = max(0.0, next_time - _duration)
    _elapsed = min(next_time, _duration)
    var t: float = _elapsed / _duration
    var eased: float = smoothstep(0.0, 1.0, t)
    if phase == Phase.WINDUP:
        var angle: float = -_side * HALF_ANGLE
        _parent.sprite.position = _rest + Vector2.RIGHT.rotated(angle) * _radius * eased
        _parent.sprite.rotation = angle * eased
        _parent.set_charge(eased)
    elif phase == Phase.SWEEP:
        var angle: float = _side * lerp(-HALF_ANGLE, HALF_ANGLE, eased)
        _parent.sprite.position = _rest + Vector2.RIGHT.rotated(angle) * _radius
        _parent.sprite.rotation = angle
        _parent.update_swing(eased)
    else:
        var angle: float = _side * HALF_ANGLE
        _parent.sprite.position = _rest + Vector2.RIGHT.rotated(angle) * _radius * (1.0 - eased)
        _parent.sprite.rotation = angle * (1.0 - eased) + _side * sin(t * PI) * (1.0 - t) * 0.15
        _parent.set_charge((1.0 - t) * 0.4)


func _next_phase() -> void:
    _elapsed = 0.0
    if phase == Phase.WINDUP:
        phase = Phase.SWEEP
        _duration = _sweep_duration
        _parent.enable_hitbox()
        _parent.begin_swing(_rest)
        SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.10)
    elif phase == Phase.SWEEP:
        phase = Phase.RECOVER
        _duration = _recover_duration
        _parent.disable_hitbox()
        _parent.end_swing(_rest, _side)
    else:
        cancel_attack()


func cancel_attack() -> void:
    _parent.disable_hitbox()
    _parent.set_shooting(false)
    if phase == Phase.IDLE:
        return
    phase = Phase.IDLE
    _remainder = 0.0
    _parent.sprite.position = _rest
    _parent.sprite.rotation = 0.0
    _parent.set_charge(0.0)
