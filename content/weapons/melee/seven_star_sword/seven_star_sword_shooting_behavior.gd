extends "res://weapons/shooting_behaviors/melee_weapon_shooting_behavior.gd"

enum Phase { IDLE, WINDUP, STRIKE, RECOVER }

var phase: int = Phase.IDLE
var attack_angle: float = 0.0
var ritual: bool = false
var _chain_released: bool = false
var _thrust: bool = true
var _elapsed: float = 0.0
var _duration: float = 0.0
var _strike_duration: float = 0.0
var _recover_duration: float = 0.0
var _remainder: float = 0.0
var _reach: float = 0.0
var _wind_angle: float = 0.0
var _end_angle: float = 0.0
var _settle_angle: float = 0.0
var _pose_angle: float = 0.0
var _rest: Vector2
var _pose_start: Vector2
var _wind: Vector2
var _end: Vector2
var _start_angle: float = 0.0
var _aim_angle: float = 0.0


func init(parent: Node) -> Node:
    .init(parent)
    _rest = _parent.sprite.position
    return self


func shoot(_distance: float) -> void:
    shooting_data = MeleeShootingData.new(_parent.current_stats, _parent.player_index)
    ritual = _parent._nb_shots_taken % _parent.ATTACK_INTERVAL == 0
    _thrust = _parent.next_attack_type == MeleeAttackType.THRUST
    attack_angle = _parent.rotation
    _start_angle = attack_angle
    _aim_angle = attack_angle if ritual else _parent.get_attack_aim_angle()
    _pose_start = _parent.sprite.position
    _pose_angle = _parent.sprite.rotation
    var side: float = -1.0 if _parent.sprite.flip_v else 1.0
    _reach = max(0.0, _parent.current_stats.max_range)
    var step: float = 1.0 / Engine.iterations_per_second
    var compact: float = clamp(shooting_data.atk_spd / 3.0, 0.0, 1.0)
    if ritual:
        _wind_angle = _pose_angle + wrapf(-PI * 0.5 - _parent.global_rotation - _pose_angle, -PI, PI)
        _end_angle = _wind_angle
        _settle_angle = 0.0
        _wind = _rest - Vector2.RIGHT.rotated(_wind_angle) * 8.0
        _end = _rest + Vector2.RIGHT.rotated(_wind_angle) * 62.0
    elif _thrust:
        _wind_angle = 0.0
        _end_angle = 0.0
        _settle_angle = -0.30 * side
        _wind = _rest + Vector2(lerp(-16.0, -6.0, compact), 0)
        _end = _rest + Vector2(_reach, 0)
    else:
        _wind_angle = -lerp(1.05, 0.72, compact) * side
        _end_angle = lerp(1.10, 0.78, compact) * side
        _settle_angle = 0.12 * side
        _wind = _rest + Vector2.RIGHT.rotated(_wind_angle) * _reach * 0.35
        _end = _rest + Vector2.RIGHT.rotated(_end_angle) * _reach * 0.35
    if ritual:
        var total: float = max(max(step * 12.0, shooting_data.get_shooting_total_duration()), 0.42)
        _duration = max(step * 3.0, total * 0.40)
        _strike_duration = max(step * 5.0, total * 0.26)
        _recover_duration = max(step * 4.0, total - _duration - _strike_duration)
    else:
        _duration = max(step * 2.0, shooting_data.recoil_duration)
        _duration = max(_duration, min(0.08, abs(wrapf(_aim_angle - _start_angle, -PI, PI)) / 32.0))
        _strike_duration = max(step * 4.0, shooting_data.atk_duration * 0.35)
        _recover_duration = max(step * 3.0, shooting_data.back_duration * 0.60)
    _elapsed = 0.0
    _remainder = 0.0
    _chain_released = false
    phase = Phase.WINDUP
    _parent.set_shooting(true)
    _parent.disable_hitbox()
    _parent._hitbox.player_attack_id = _get_next_attack_id()


func advance(delta: float) -> void:
    if delta <= 0.0:
        return
    if phase == Phase.IDLE:
        var relax: float = 1.0 - exp(-10.0 * delta)
        _parent.sprite.position = _parent.sprite.position.linear_interpolate(_rest, relax)
        _parent.sprite.rotation = lerp(_parent.sprite.rotation, 0.0, relax)
        return
    if _elapsed >= _duration:
        _next_phase()
        if phase == Phase.IDLE:
            return
    var next_time: float = _elapsed + delta + _remainder
    _remainder = max(0.0, next_time - _duration)
    _elapsed = min(next_time, _duration)
    var t: float = _elapsed / _duration
    var eased: float = 0.5 - cos(t * PI) * 0.5
    if phase == Phase.WINDUP:
        if not ritual:
            _aim_angle = _parent.get_attack_aim_angle()
        attack_angle = lerp_angle(_start_angle, _aim_angle, eased)
        _parent.rotation = attack_angle
        _parent.sprite.position = _pose_start.linear_interpolate(_wind, eased)
        _parent.sprite.rotation = lerp(_pose_angle, _wind_angle, eased)
        _parent.set_charge(eased * (1.0 if ritual else 0.55))
    elif phase == Phase.STRIKE:
        if not ritual:
            var aim_error: float = wrapf(_parent.get_attack_aim_angle() - attack_angle, -PI, PI)
            var max_turn: float = (32.0 if _thrust else 18.0) * delta
            attack_angle += clamp(aim_error, -max_turn, max_turn)
            _parent.rotation = attack_angle
        var drive: float = _strike_progress(t)
        _parent.sprite.rotation = lerp(_wind_angle, _end_angle, drive)
        if _thrust or ritual:
            _parent.sprite.position = _wind.linear_interpolate(_end, drive)
        else:
            var radius: float = _reach * (0.35 + sin(drive * PI) * 0.40)
            _parent.sprite.position = _rest + Vector2.RIGHT.rotated(_parent.sprite.rotation) * radius
        _parent.set_charge(0.65 + sin(drive * PI) * 0.35)
        if ritual and not _chain_released and drive >= 0.50:
            _chain_released = true
            _parent.release_star_chain()
    else:
        _parent.sprite.position = _end.linear_interpolate(_rest, eased)
        _parent.sprite.rotation = lerp(_end_angle, _settle_angle, eased)
        _parent.set_charge((1.0 - eased) * 0.4)


func _strike_progress(t: float) -> float:
    var peak: float = 0.62 if ritual else (0.22 if _thrust else 0.36)
    var power: float = 3.0 if ritual else 2.0
    if t < peak:
        return peak * pow(t / peak, power)
    return 1.0 - (1.0 - peak) * pow((1.0 - t) / (1.0 - peak), power)


func _next_phase() -> void:
    _elapsed = 0.0
    if phase == Phase.WINDUP:
        phase = Phase.STRIKE
        _duration = _strike_duration
        if not ritual:
            _parent._hitbox.active = true
            _parent.enable_hitbox()
        _parent.begin_strike()
        SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.12)
    elif phase == Phase.STRIKE:
        phase = Phase.RECOVER
        _duration = _recover_duration
        _parent.disable_hitbox()
        _parent.end_strike()
    else:
        phase = Phase.IDLE
        _remainder = 0.0
        _parent.set_shooting(false)
        _parent.set_charge(0.0)


func cancel_attack() -> void:
    _parent.disable_hitbox()
    _parent.set_shooting(false)
    _parent.end_strike()
    phase = Phase.IDLE
    _remainder = 0.0
    _parent.sprite.position = _rest
    _parent.sprite.rotation = 0.0
    _parent.set_charge(0.0)
