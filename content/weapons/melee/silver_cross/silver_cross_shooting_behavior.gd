extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/shared/phased_sweep_shooting_behavior.gd"

var _radius: float = 0.0
var _side: float = -1.0


func shoot(distance: float) -> void:
    shooting_data = MeleeShootingData.new(_parent.current_stats, _parent.player_index)
    var step: float = 1.0 / Engine.iterations_per_second
    var duration: float = max(step * 8.0, shooting_data.get_shooting_total_duration())
    _duration = max(step, duration * 0.26)
    _sweep_duration = max(step * 4.0, duration * 0.32)
    _recover_duration = duration - _duration - _sweep_duration
    var swing_distance: float = min(_parent.current_stats.max_range, max(MIN_SWEEP_DISTANCE, distance))
    _radius = max(0.0, swing_distance - 140.0)
    _side = -1.0 if _parent.sprite.flip_v else 1.0
    _start_attack()
    _parent.prepare_swing(_side, _radius)


func _update_pose(t: float) -> void:
    var eased: float = t * t * (3.0 - 2.0 * t)
    if phase == Phase.WINDUP:
        var angle: float = -_side * PI * 0.5
        _parent.sprite.position = _rest.linear_interpolate(_rest + Vector2.RIGHT.rotated(angle) * _radius, eased)
        _parent.sprite.rotation = angle * eased
        _parent.set_charge(eased * 0.65)
    elif phase == Phase.SWEEP:
        var progress: float
        if t < 0.42:
            progress = 0.42 * pow(t / 0.42, 2.4)
        else:
            progress = 0.42 + 0.58 * (1.0 - pow((1.0 - t) / 0.58, 2.4))
        var angle: float = _side * (progress - 0.5) * PI
        _parent.sprite.position = _rest + Vector2.RIGHT.rotated(angle) * _radius
        _parent.sprite.rotation = angle
        _parent.update_swing(progress)
    else:
        var angle: float = _side * PI * 0.5
        _parent.sprite.position = (_rest + Vector2.RIGHT.rotated(angle) * _radius).linear_interpolate(_rest, eased)
        _parent.sprite.rotation = angle * (1.0 - eased) + _side * sin(t * PI) * pow(1.0 - t, 2.0) * 0.42
        _parent.set_charge((1.0 - t) * 0.35)


func _on_sweep_started() -> void:
    SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.12)


func _on_sweep_finished() -> void:
    _parent.end_swing()


func cancel_attack() -> void:
    if phase == Phase.SWEEP:
        _parent.end_swing()
    .cancel_attack()
