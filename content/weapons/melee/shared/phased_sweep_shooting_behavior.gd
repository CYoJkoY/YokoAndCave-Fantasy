extends "res://weapons/shooting_behaviors/melee_weapon_shooting_behavior.gd"

enum Phase { IDLE, WINDUP, SWEEP, RECOVER }

var phase: int = Phase.IDLE
var attack_angle: float = 0.0
var _elapsed: float = 0.0
var _duration: float = 0.0
var _sweep_duration: float = 0.0
var _recover_duration: float = 0.0
var _remainder: float = 0.0
var _rest: Vector2


func _start_attack() -> void:
    _rest = _parent.sprite.position
    attack_angle = _parent.rotation
    _elapsed = 0.0
    _remainder = 0.0
    phase = Phase.WINDUP
    _parent.set_shooting(true)
    _parent.disable_hitbox()
    _parent._hitbox.player_attack_id = _get_next_attack_id()


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
    _update_pose(_elapsed / _duration)


func _next_phase() -> void:
    _elapsed = 0.0
    if phase == Phase.WINDUP:
        phase = Phase.SWEEP
        _duration = _sweep_duration
        _parent.enable_hitbox()
        _parent.begin_swing(_rest)
        _on_sweep_started()
    elif phase == Phase.SWEEP:
        phase = Phase.RECOVER
        _duration = _recover_duration
        _parent.disable_hitbox()
        _on_sweep_finished()
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


func _update_pose(_progress: float) -> void:
    pass


func _on_sweep_started() -> void:
    pass


func _on_sweep_finished() -> void:
    pass
