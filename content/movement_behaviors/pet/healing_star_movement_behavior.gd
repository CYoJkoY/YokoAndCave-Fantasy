extends "res://mods-unpacked/YokoAndCave-Fantasy/content/movement_behaviors/pet/floating_pet_movement_behavior.gd"

# Healing star branch: inherits the shared wander around the owner and
# accelerates toward consumables. The pet keeps ownership of scanning,
# claiming and collecting.

enum State { WANDER, SEEK_CONSUMABLE }

export(float) var wander_speed: float = 160.0
export(float) var seek_speed: float = 640.0
export(float) var seek_acceleration: float = 1500.0

var _state: int = State.WANDER
var _consumable_target = null
var _current_spin_speed: float = 1.0

var _body_sprite: Sprite = null
var _trail_particles: CPUParticles2D = null


func init(parent: Node) -> Node:
    .init(parent)
    _body_sprite = _parent.get_node_or_null("Animation/Offset/Body") as Sprite
    _trail_particles = _parent.get_node_or_null("Animation/TrailParticles") as CPUParticles2D
    return self


func reset_state() -> void:
    _state = State.WANDER
    _consumable_target = null
    _current_spin_speed = 1.0
    if is_instance_valid(_body_sprite):
        _body_sprite.rotation = 0.0
    if is_instance_valid(_trail_particles):
        _trail_particles.emitting = false
    reset_wander()


func set_consumable_target(target) -> void:
    _consumable_target = target
    _state = State.SEEK_CONSUMABLE


func clear_consumable_target() -> void:
    _consumable_target = null
    _state = State.WANDER
    _pick_wander_target()


func get_consumable_target():
    return _consumable_target


func is_seeking() -> bool:
    return _state == State.SEEK_CONSUMABLE


func get_target_position():
    if is_seeking() and is_instance_valid(_consumable_target):
        return _consumable_target.global_position
    return .get_target_position()


func _get_desired_velocity(delta: float) -> Vector2:
    if is_seeking():
        if not is_instance_valid(_consumable_target):
            return Vector2.ZERO
        return _parent.global_position.direction_to(_consumable_target.global_position) * seek_speed

    return ._get_desired_velocity(delta)


func _get_acceleration() -> float:
    return seek_acceleration if is_seeking() else wander_acceleration


func _get_wander_speed() -> float:
    return wander_speed


func _get_reference_speed() -> float:
    return seek_speed


func _get_tilt_target() -> float:
    if not is_seeking():
        return 0.0
    return clamp(_velocity.x / max(1.0, seek_speed), -1.0, 1.0) * tilt_max


func _get_tilt_lerp_speed() -> float:
    return 6.0 if is_seeking() else 4.0


func _update_extra_visuals(delta: float) -> void:
    if is_instance_valid(_body_sprite):
        var target_spin_speed: float = 1.0 + get_speed_ratio() * 3.6
        _current_spin_speed = lerp(_current_spin_speed, target_spin_speed, 5.0 * delta)
        _body_sprite.rotation += _current_spin_speed * delta

    if is_instance_valid(_trail_particles):
        var threshold: float = 0.4 if is_seeking() else 0.65
        _trail_particles.emitting = get_speed_ratio() > threshold
