extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/shared/orbit_weapon_pose.gd"

onready var _focus: Node2D = $Sprite/Focus


func _ready() -> void:
    _init_orbit_pose()
    _focus.reset_anchor()


func _physics_process(delta: float) -> void:
    if _parent.dead or _parent.cleaning_up:
        return
    _time += delta
    _update_orbit_position_and_motion(delta)


func should_rotate_manual() -> bool:
    return false


func get_direction() -> float:
    return rotation


func get_direction_and_calculate_target() -> float:
    .get_direction_and_calculate_target()
    return rotation


func get_orb_aim_direction() -> Vector2:
    if Utils.is_player_using_gamepad(player_index):
        return _parent.gamepad_attack_vector.normalized()
    return muzzle.global_position.direction_to(get_global_mouse_position())


func begin_cast() -> void:
    _is_thrusting = true
    _thrust_elapsed = 0.0
    _focus.set_casting(true)


func on_orb_emitted(element: int) -> void:
    _focus.flash(element)


func finish_cast() -> void:
    _focus.set_casting(false)


func should_shoot() -> bool:
    if _shooting_behavior.is_emitting() or not WeaponService.fantasy_can_start_attack(self):
        return false
    if not .should_shoot():
        return false
    return _manual_aim or _current_target[1] <= current_stats.max_range


func get_max_range() -> int:
    return current_stats.max_range


func get_max_rand_cooldown(_cooldown_basis: int) -> float:
    return 0.0
