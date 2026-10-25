extends "res://weapons/ranged/ranged_weapon.gd"

const BASE_ORBIT_RADIUS_X: float = 72.0
const BASE_ORBIT_RADIUS_Y: float = 42.0
const THRUST_DURATION: float = 0.48
const THRUST_HEIGHT: float = 22.0
const ORBIT_GROUP: String = "fantasy_orbit_strike_weapons"

var _time: float = 0.0
var _orbit_phase: float = 0.0
var _is_thrusting: bool = false
var _thrust_elapsed: float = 0.0


func _init_orbit_pose() -> void:
    add_to_group(ORBIT_GROUP)
    visible = true
    sprite.visible = true
    var animation_node: Node = _parent.get_node_or_null("Animation")
    if animation_node != null:
        animation_node.z_index = 1
    get_parent().z_index = 0
    _update_orbit_position_and_motion(0.0)


func attach(_attach_to: Vector2, _attach_idle_angle: float) -> void:
    _update_orbit_position_and_motion(0.0)


func update_sprite_flipv() -> void:
    sprite.flip_v = false


func _update_orbit_position_and_motion(delta: float) -> void:
    var orbiting_weapons: Array = []
    for weapon in _parent.current_weapons:
        if is_instance_valid(weapon) and weapon.is_in_group(ORBIT_GROUP):
            orbiting_weapons.append(weapon)
    if not orbiting_weapons.has(self):
        orbiting_weapons.append(self)

    var total_weapons: int = orbiting_weapons.size()
    var my_index: int = orbiting_weapons.find(self)

    _orbit_phase += delta * 0.35

    var angle: float = (float(my_index) / float(total_weapons)) * TAU - PI / 2.0 + _orbit_phase
    var rx: float = BASE_ORBIT_RADIUS_X + min(total_weapons, 6) * 3.0
    var ry: float = BASE_ORBIT_RADIUS_Y + min(total_weapons, 6) * 2.0
    var local_orbit_pos: Vector2 = Vector2(cos(angle) * rx, sin(angle) * ry)

    var in_foreground: bool = sin(angle) > 0.05
    z_index = 2 if in_foreground else 0
    z_as_relative = true

    var breath_y: float = sin(_time * 2.6 + float(my_index) * 1.3) * 5.5
    var breath_sway: float = sin(_time * 1.8 + float(my_index) * 1.1) * 0.045
    var breath_scale: float = 1.0 + sin(_time * 2.2 + float(my_index) * 0.9) * 0.025

    var thrust_y: float = 0.0
    var thrust_scale_bonus: float = 0.0
    if _is_thrusting:
        _thrust_elapsed += delta
        if _thrust_elapsed < THRUST_DURATION:
            var t: float = clamp(_thrust_elapsed / THRUST_DURATION, 0.0, 1.0)
            var pulse: float = 0.0
            if t < 0.35:
                var u: float = t / 0.35
                pulse = u * u * (3.0 - 2.0 * u)
            else:
                var v: float = (t - 0.35) / 0.65
                var cos_fall: float = (cos(v * PI) + 1.0) * 0.5
                pulse = pow(cos_fall, 1.25)
            thrust_y = -_get_thrust_height() * pulse
            thrust_scale_bonus = pulse * 0.07
        else:
            _is_thrusting = false

    position = local_orbit_pos + Vector2(0, breath_y + thrust_y)
    rotation = -PI / 2.0 + breath_sway

    if is_instance_valid(sprite):
        sprite.flip_v = false
        sprite.scale = Vector2.ONE * (breath_scale + thrust_scale_bonus)


func _get_thrust_height() -> float:
    return THRUST_HEIGHT
