extends "res://weapons/melee/melee_weapon.gd"

const LIGHT: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/melee/seven_star_sword/vfx/seven_star_light.tscn")
const TARGET_INDEX = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_target_index.gd")
const ATTACK_INTERVAL: int = 7

onready var _edge: Sprite = $Sprite/Edge
onready var _runes: Sprite = $Sprite/Runes
onready var _halo: Sprite = $Sprite/Halo
onready var _sparks: CPUParticles2D = $Sprite/Sparks
onready var _trail: Node2D = $Trail

var _star_effect: Resource
var _clock: float = 0.0
var _charge: float = 0.0
var _last_cross_attack_id: int = -1


func _ready() -> void:
    for effect in effects:
        if effect.get_id() == "weapon_seven_star_sword":
            _star_effect = effect
            break
    assert(_star_effect != null, "Seven-star sword effect is missing")
    update_sprite_flipv()


func get_direction() -> float:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return _shooting_behavior.attack_angle
    return .get_direction()


func get_direction_and_calculate_target() -> float:
    var target_angle: float = .get_direction_and_calculate_target()
    return lerp_angle(rotation, target_angle, 1.0 - exp(-18.0 * get_physics_process_delta_time()))


func should_rotate_manual() -> bool:
    return false


func get_attack_aim_angle() -> float:
    if _manual_aim:
        if Utils.is_player_using_gamepad(player_index):
            return _parent.gamepad_attack_vector.angle()
        return (get_global_mouse_position() - global_position).angle()
    return .get_direction()


func should_shoot() -> bool:
    if _parent.dead or _parent.cleaning_up:
        return false
    if (_nb_shots_taken + 1) % ATTACK_INTERVAL != 0:
        return .should_shoot()
    if not WeaponService.fantasy_can_start_attack(self):
        return false
    if _manual_aim:
        return true
    var radius_squared: float = pow(_star_effect.get_radius(player_index), 2)
    for target in _targets_in_range:
        if is_valid_star_target(target) and global_position.distance_squared_to(target.global_position) <= radius_squared:
            return true
    return false


func shoot() -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        return
    update_sprite_flipv()
    var previous_type: int = next_attack_type
    .shoot()
    if _nb_shots_taken % ATTACK_INTERVAL == 0:
        next_attack_type = previous_type
    _update_detection_range()


func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    _update_detection_range()


func _update_detection_range() -> void:
    if (_nb_shots_taken + 1) % ATTACK_INTERVAL == 0:
        _range_shape.shape.radius = max(current_stats.max_range + DETECTION_RANGE, _star_effect.get_radius(player_index))
    else:
        _range_shape.shape.radius = current_stats.max_range + DETECTION_RANGE


func get_next_cooldown(at_wave_begin: bool = false) -> float:
    if not at_wave_begin and _nb_shots_taken > 0 and _nb_shots_taken % ATTACK_INTERVAL == 0:
        return _star_effect.RECOVERY * 60.0
    return .get_next_cooldown(at_wave_begin)


func reset_cooldown() -> void:
    if _nb_shots_taken > 0 and _nb_shots_taken % ATTACK_INTERVAL == 0:
        return
    .reset_cooldown()


func update_sprite_flipv() -> void:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return
    .update_sprite_flipv()
    _edge.flip_v = sprite.flip_v
    _runes.flip_v = sprite.flip_v
    _halo.flip_v = sprite.flip_v


func disable_hitbox() -> void:
    _hitbox.active = false
    .disable_hitbox()


func _physics_process(delta: float) -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        _trail.clear_trail()
        _halo.visible = false
        _runes.visible = false
        _edge.material.set_shader_param("charge", 0.0)
        set_process(false)
        set_physics_process(false)
        return
    if _manual_aim and _shooting_behavior.phase == _shooting_behavior.Phase.IDLE:
        rotation = lerp_angle(rotation, get_attack_aim_angle(), 1.0 - exp(-18.0 * delta))
    _shooting_behavior.advance(delta)
    _trail.advance(_edge, _shooting_behavior.phase == _shooting_behavior.Phase.STRIKE, delta, ProgressData.settings.explosion_opacity)


func _process(delta: float) -> void:
    _clock += delta
    var opacity: float = ProgressData.settings.explosion_opacity
    _edge.material.set_shader_param("phase", _clock)
    _edge.material.set_shader_param("charge", _charge)
    _halo.material.set_shader_param("charge", _charge)
    _halo.modulate.a = opacity
    _runes.modulate = Color(0.52, 0.85, 1.0, (0.65 + sin(_clock * 3.0) * 0.15 + _charge * 0.2) * opacity)
    _runes.position.y = sin(_clock * 2.4) * 1.5
    _sparks.modulate.a = opacity


func set_charge(value: float) -> void:
    _charge = value


func begin_strike() -> void:
    _sparks.emitting = true


func end_strike() -> void:
    _sparks.emitting = false


func is_valid_star_target(target) -> bool:
    return is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die \
        and not target.is_queued_for_deletion() and not WeaponService.fantasy_should_ignore_tree_body(self, target)


func on_weapon_hit_something(thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void:
    var create_cross: bool = hitbox == _hitbox and damage_dealt > 0 and _is_shooting \
        and not _shooting_behavior.ritual and hitbox.player_attack_id != _last_cross_attack_id \
        and is_instance_valid(thing_hit) and thing_hit is Enemy \
        and not WeaponService.fantasy_should_ignore_tree_body(self, thing_hit)
    var center: Vector2 = Vector2.ZERO
    if create_cross:
        _last_cross_attack_id = hitbox.player_attack_id
        center = thing_hit._hurtbox.global_position
    .on_weapon_hit_something(thing_hit, damage_dealt, hitbox)
    if create_cross:
        var main: Node = Utils.get_scene_node()
        if not is_instance_valid(main) or main._cleaning_up or _parent.dead or _parent.cleaning_up:
            return
        var light = LIGHT.instance()
        add_child(light)
        light.start_cross(self, main, center)


func release_star_chain() -> void:
    var main: Node = Utils.get_scene_node()
    if not is_instance_valid(main) or main._cleaning_up or _parent.dead or _parent.cleaning_up:
        return
    var target_index = TARGET_INDEX.for_scene(main)
    var selected: Array = []
    var seen: int = 0
    var radius: float = _star_effect.get_radius(player_index)
    var center: Vector2 = global_position
    for enemy in target_index.candidates(main, center, radius):
        if not is_valid_star_target(enemy) or center.distance_squared_to(enemy.global_position) > radius * radius:
            continue
        seen += 1
        if selected.size() < _star_effect.TARGET_COUNT:
            selected.append(enemy)
        else:
            var slot: int = Utils.randi_range(0, seen - 1)
            if slot < _star_effect.TARGET_COUNT:
                selected[slot] = enemy
    var ordered: Array = []
    var previous: Vector2 = muzzle.global_position
    while not selected.empty():
        var nearest = selected[0]
        var nearest_distance: float = previous.distance_squared_to(nearest.global_position)
        for candidate in selected:
            var candidate_distance: float = previous.distance_squared_to(candidate.global_position)
            if candidate_distance < nearest_distance:
                nearest = candidate
                nearest_distance = candidate_distance
        ordered.append(nearest)
        selected.erase(nearest)
        previous = nearest.global_position
    var light = LIGHT.instance()
    add_child(light)
    light.start_chain(self, main, ordered, _star_effect)
