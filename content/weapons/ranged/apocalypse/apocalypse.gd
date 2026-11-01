extends "res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/shared/floating_spell_weapon.gd"

const MAX_RANGE_BONUS: int = 50

onready var _visuals: Node2D = $ApocalypseField

var _field_radius: float = 0.0
var _pulse_targets: Array = []


func _ready() -> void:
    _visuals.set_cursed(is_cursed)


func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    _field_radius = min(current_stats.max_range, stats.max_range + MAX_RANGE_BONUS)
    _range_shape.shape.radius = _field_radius + DETECTION_RANGE
    $ApocalypseField.set_radius(_field_radius)


func is_manual_aim() -> bool:
    return false


func get_direction() -> float:
    return 0.0


func get_direction_and_calculate_target() -> float:
    return 0.0


func update_sprite_flipv() -> void:
    sprite.flip_v = false


func _process(_delta: float) -> void:
    _visuals.set_active(not _parent.dead and not _parent.cleaning_up)


func should_shoot() -> bool:
    if not WeaponService.fantasy_can_start_attack(self):
        return false
    _pulse_targets.clear()
    var radius_squared: float = _field_radius * _field_radius
    for target in _targets_in_range:
        if is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die:
            if global_position.distance_squared_to(target.global_position) <= radius_squared:
                _pulse_targets.append(target)
    return not _pulse_targets.empty()


func emit_erosion_pulse(attack_id: int) -> void:
    if _parent.dead or _parent.cleaning_up or is_queued_for_deletion():
        _pulse_targets.clear()
        return
    _hitbox.player_attack_id = attack_id
    _hitbox.ignored_objects.clear()
    _hitbox.active = true
    _visuals.play_pulse()
    var radius_squared: float = _field_radius * _field_radius
    for target in _pulse_targets:
        if not is_instance_valid(target) or target.dead or target._pending_die:
            continue
        if global_position.distance_squared_to(target.global_position) > radius_squared:
            continue
        target.hurt_area_entered_deferred(_hitbox)
    _hitbox.active = false
    _pulse_targets.clear()


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)
    _visuals.add_bloom(thing_hit.global_position)
