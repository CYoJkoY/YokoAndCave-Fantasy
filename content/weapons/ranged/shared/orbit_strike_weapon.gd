extends "res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/shared/orbit_weapon_pose.gd"

const VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")
const STRIKE_ATTACK: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/shared/orbit_strike_attack.tscn")

const FALLBACK_SOUND: AudioStream = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/myriad_thunder/myriad_thunder.wav")

export(PackedScene) var strike_scene
export(String) var targeting_effect_id

var _recoil_remaining: float = 0.0
var _pending_targets: Array = []
var _targeting_effect: Resource


func _ready() -> void:
    disable_target_tracking()
    for effect in effects:
        if effect.get_id() == targeting_effect_id:
            _targeting_effect = effect
            break
    assert(_targeting_effect != null, "Orbit strike targeting effect is missing")
    assert(strike_scene != null, "Orbit strike scene is missing")
    _init_orbit_pose()


func is_manual_aim() -> bool:
    return false


func get_direction() -> float:
    return rotation


func get_direction_and_calculate_target() -> float:
    return rotation


func _physics_process(delta: float) -> void:
    if not is_instance_valid(_parent) or _parent.dead or _parent.cleaning_up:
        _pending_targets.clear()
        _recoil_remaining = 0.0
        _is_shooting = false
        return

    if _recoil_remaining > 0.0:
        _recoil_remaining = max(0.0, _recoil_remaining - delta)
        if _recoil_remaining <= 0.0:
            _is_shooting = false

    visible = true
    if is_instance_valid(sprite):
        sprite.visible = true

    _time += delta
    _update_orbit_position_and_motion(delta)
    _update_visual_effects(delta)


func should_shoot() -> bool:
    if not WeaponService.fantasy_can_start_attack(self):
        return false

    var main = Utils.get_scene_node()
    if not is_instance_valid(main) or main._cleaning_up or main._entity_spawner == null:
        return false

    _pending_targets = _collect_targets(main)
    return not _pending_targets.empty()


func shoot() -> void:
    var main = Utils.get_scene_node()
    if not is_instance_valid(main) or main._cleaning_up or main._entity_spawner == null:
        _is_shooting = false
        return

    if is_queued_for_deletion() or not is_physics_processing():
        _is_shooting = false
        return

    if not is_instance_valid(_parent) or _parent.dead or _parent.cleaning_up or current_stats == null:
        _is_shooting = false
        return

    for i in range(_pending_targets.size() - 1, -1, -1):
        if not is_valid_strike_target(_pending_targets[i]):
            _pending_targets.remove(i)
    if _pending_targets.empty():
        _pending_targets = _collect_targets(main)
    if _pending_targets.empty():
        _is_shooting = false
        return

    var targets: Array = _pending_targets
    _pending_targets = []

    var original_stats: RangedWeaponStats = WeaponService.fantasy_begin_custom_ranged_attack(self)
    _recoil_remaining = current_stats.recoil_duration * 2.0

    _is_thrusting = true
    _thrust_elapsed = 0.0
    _start_cast_effects()

    _play_cast_sound()

    var attack = STRIKE_ATTACK.instance()
    add_child(attack)
    attack.connect("strike_started", self, "_spawn_strike_visuals", [main])
    attack.start(self, targets, main)

    WeaponService.fantasy_end_custom_ranged_attack(self, original_stats)

    _is_shooting = _recoil_remaining > 0.0
    _on_cast_completed()


func _play_cast_sound() -> void:
    if current_stats != null and not current_stats.shooting_sounds.empty():
        var snd = Utils.get_rand_element(current_stats.shooting_sounds)
        if snd != null:
            SoundManager.play(snd, current_stats.sound_db_mod, 0.15)
            return

    SoundManager.play(FALLBACK_SOUND, -4, 0.15)


func _collect_targets(main: Node) -> Array:
    var attack_stats: RangedWeaponStats = WeaponService.fantasy_get_next_ranged_attack_stats(self)
    var center: Vector2 = global_position
    var max_range_sq: float = float(attack_stats.max_range) * float(attack_stats.max_range)
    var candidates: Array = []
    var in_range: Array = []
    for enemy in main._entity_spawner.get_all_enemies(false):
        if is_valid_strike_target(enemy):
            candidates.append(enemy)
            if center.distance_squared_to(enemy.global_position) <= max_range_sq:
                in_range.append(enemy)
    for neutral in main._entity_spawner.neutrals:
        if is_valid_strike_target(neutral):
            if center.distance_squared_to(neutral.global_position) <= max_range_sq:
                in_range.append(neutral)
    if in_range.empty():
        return []
    var nearest: Unit = in_range[0]
    var nearest_distance: float = center.distance_squared_to(nearest.global_position)
    for target in in_range:
        var distance: float = center.distance_squared_to(target.global_position)
        if distance < nearest_distance:
            nearest = target
            nearest_distance = distance
    candidates.erase(nearest)
    var targets: Array = [nearest]
    var projectile_bonus: int = attack_stats.nb_projectiles - stats.nb_projectiles
    var extra_count: int = int(min(max(0, _targeting_effect.value + projectile_bonus), candidates.size()))
    for i in range(extra_count):
        var selected_index: int = Utils.randi_range(i, candidates.size() - 1)
        var selected: Unit = candidates[selected_index]
        candidates[selected_index] = candidates[i]
        candidates[i] = selected
        targets.append(selected)
    return targets


func is_valid_strike_target(target) -> bool:
    return (
        is_instance_valid(target)
        and target is Unit
        and not target.dead
        and not target._pending_die
        and not WeaponService.fantasy_should_ignore_tree_body(self, target)
    )


func _spawn_strike_visuals(target: Unit, main: Node) -> void:
    var pool_id: int = strike_scene.get_instance_id()
    var strike_vfx: Node2D = VISUAL_UTILS.get_pooled_effect(strike_scene, main)
    strike_vfx.set_pool_id(pool_id)
    _configure_strike_visuals(strike_vfx)
    strike_vfx.start_strike(target.global_position, target, 1.0, _get_strike_tint())


func _get_strike_tint() -> Color:
    return Color.white


func _configure_strike_visuals(_strike_vfx: Node2D) -> void:
    pass


func _start_cast_effects() -> void:
    pass


func _update_visual_effects(_delta: float) -> void:
    pass


func _on_cast_completed() -> void:
    pass
