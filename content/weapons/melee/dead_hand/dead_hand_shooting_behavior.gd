extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/shared/phased_sweep_shooting_behavior.gd"

const HALF_ANGLE: float = 1.25

var _radius: float = 0.0
var _side: float = -1.0


func shoot(distance: float) -> void:
    shooting_data = MeleeShootingData.new(_parent.current_stats, _parent.player_index)
    var duration: float = shooting_data.get_shooting_total_duration()
    _duration = duration * 0.24
    _sweep_duration = duration * 0.38
    _recover_duration = duration - _duration - _sweep_duration
    var swing_distance: float = min(_parent.current_stats.max_range, max(MIN_SWEEP_DISTANCE, distance))
    _radius = max(0.0, swing_distance - 88.0)
    _side = -_side
    _start_attack()
    _parent.prepare_swing(_side, _radius + 88.0)


func _update_pose(t: float) -> void:
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


func _on_sweep_started() -> void:
    SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.10)


func _on_sweep_finished() -> void:
    _parent.end_swing(_rest, _side)
