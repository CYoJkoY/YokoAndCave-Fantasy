extends "res://entities/units/enemies/enemy.gd"

const FANTASY_ENEMY_SPEED_MODIFIER_SERVICE = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/enemy_speed_modifier_service.gd")
const FANTASY_AIRBORNE_CONTROLLER = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/enemy_airborne_controller.gd")

var _fantasy_airborne_controller: Node = null
var _fantasy_impact_damage: int = -1

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func init(
    zone_min_pos: Vector2,
    zone_max_pos: Vector2,
    p_players_ref: Array = [],
    entity_spawner_ref = null
) -> void:
    .init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)
    _fantasy_buff_future_target()
    if Utils.plant_enemies_ids.has(enemy_id_hash):
        _fantasy_cannot_tree_damage()

func respawn() -> void:
    _fantasy_clear_airborne()
    .respawn()
    if _fantasy_airborne_controller != null:
        _fantasy_airborne_controller.restore_pooled_collisions()
        _hitbox.active = true
        # Override any deferred disable queued by a launch earlier this frame.
        _collision.set_deferred("disabled", false)
    FANTASY_ENEMY_SPEED_MODIFIER_SERVICE.clear_pooled_state(self)
    _fantasy_buff_future_target()
    if Utils.plant_enemies_ids.has(enemy_id_hash):
        _fantasy_cannot_tree_damage()

func update_target() -> void:
    .update_target()
    if Utils.plant_enemies_ids.has(enemy_id_hash):
        _fantasy_update_cannot_tree_damage_target()

func is_playing_shoot_animation() -> bool:
    var is_playing_shoot: bool =.is_playing_shoot_animation()
    if Utils.plant_enemies_ids.has(enemy_id_hash):
        is_playing_shoot = _fantasy_is_playing_shoot_animation_cannot_tree_damage(is_playing_shoot)

    return is_playing_shoot

func _on_Hurtbox_area_entered(hitbox: Area2D) -> void:
    if Utils.plant_enemies_ids.has(enemy_id_hash):
        _fantasy_cannot_damage_tree(hitbox)
    ._on_Hurtbox_area_entered(hitbox)

func get_stats_value() -> int:
    var value: int =.get_stats_value()
    value = _fantasy_bonus_drop(value)

    return value

func get_damage_value(
    dmg_value: int,
    from_player_index: int,
    armor_applied := true,
    dodgeable := true,
    is_crit := false,
    hitbox: Hitbox = null,
    is_burning := false
) -> GetDamageValueResult:
    if _fantasy_impact_damage >= 0:
        var impact_result: GetDamageValueResult = GetDamageValueResult.new()
        impact_result.value = _fantasy_impact_damage
        # Consume before damage signals can cause another, unrelated hit.
        _fantasy_impact_damage = -1
        return impact_result
    if hitbox != null and hitbox.has_meta("fantasy_kou_b_hand_self_loss"):
        var self_loss_result: GetDamageValueResult = GetDamageValueResult.new()
        self_loss_result.value = hitbox.get_meta("fantasy_kou_b_hand_self_loss")
        return self_loss_result

    var dmg_value_result: GetDamageValueResult =.get_damage_value(
        dmg_value,
        from_player_index,
        armor_applied,
        dodgeable,
        is_crit,
        hitbox,
        is_burning
    )
    dmg_value_result = _fantasy_apply_holy_damage_bonus(dmg_value_result)

    if (
        !dead
        and _outline_colors.has(Utils.CURSE_COLOR)
        and from_player_index >= 0
        and from_player_index < RunData.get_player_count()
    ):
        var curse_damage_bonus: int = RunData.get_player_effect(
            Utils.fantasy_damage_against_cursed_hash,
            from_player_index
        )
        dmg_value_result.value = int(dmg_value_result.value * (1.0 + curse_damage_bonus / 100.0))

    return dmg_value_result

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func fa_launch_airborne(direction: Vector2, distance: float, player_index: int, stun_duration: float) -> void:
    if dead or _pending_die:
        return
    if _fantasy_airborne_controller == null:
        _fantasy_airborne_controller = FANTASY_AIRBORNE_CONTROLLER.new()
        add_child(_fantasy_airborne_controller)
    _fantasy_airborne_controller.launch(self, direction, distance, player_index, stun_duration)

func fa_take_airborne_impact(value: int, player_index: int, source: Node) -> void:
    if dead or _pending_die:
        return
    var args: TakeDamageArgs = TakeDamageArgs.new(player_index)
    args.from = source
    args.armor_applied = false
    args.dodgeable = false
    var previous: int = _fantasy_impact_damage
    _fantasy_impact_damage = value
    take_damage(value, args)
    _fantasy_impact_damage = previous

func _fantasy_clear_airborne() -> void:
    _fantasy_impact_damage = -1
    if _fantasy_airborne_controller != null:
        _fantasy_airborne_controller.finish(false)

func die(args: Entity.DieArgs = Utils.default_die_args) -> void:
    _fantasy_clear_airborne()
    .die(args)

func despawn() -> void:
    _fantasy_clear_airborne()
    .despawn()

func _fantasy_apply_holy_damage_bonus(dmg_value_result: GetDamageValueResult) -> GetDamageValueResult:
    if dead or !_outline_colors.has(Utils.CURSE_COLOR):
        return dmg_value_result

    var holy_stat: float = Utils.average_all_player_stats(Utils.stat_fantasy_holy_hash)
    if holy_stat <= 0:
        return dmg_value_result

    var bonus_multiplier: float = 1.0 + (holy_stat / 100.0)
    dmg_value_result.value = int(dmg_value_result.value * bonus_multiplier)

    return dmg_value_result

func _fantasy_bonus_drop(value: int) -> int:
    for player_index in range(players_ref.size()):
        var effect_items: Array = RunData.get_player_effect(
            Utils.fantasy_bonus_drop_from_target_hash,
            player_index
        )

        for effect_item in effect_items:
            var target_id: int = effect_item[0]
            var bonus_gold: int = effect_item[1]
            if target_id != enemy_id_hash:
                continue

            value += bonus_gold

    return value

func _fantasy_buff_future_target() -> void:
    for player_index in range(players_ref.size()):
        var target_enemy_buffed: Dictionary = RunData.get_player_effect(
            Utils.fantasy_buff_future_target_enemy_hash,
            player_index
        )
        if !target_enemy_buffed.has(enemy_id_hash):
            continue

        var bonus_stats: Array = target_enemy_buffed[enemy_id_hash]
        fa_apply_stat_to_both(Utils.FANTASY_ENEMY_HP, bonus_stats[0])
        fa_apply_stat_to_both(Utils.FANTASY_ENEMY_SPEED, bonus_stats[1])
        fa_apply_stat_to_both(Utils.FANTASY_ENEMY_DAMAGE, bonus_stats[2])
        fa_apply_stat_to_both(Utils.FANTASY_ENEMY_ARMOR, bonus_stats[3])

func _fantasy_cannot_tree_damage() -> void:
    for player_index in range(players_ref.size()):
        if !RunData.get_player_effect_bool(Utils.fantasy_cannot_damage_tree_hash, player_index):
            continue

        _hitbox.ignored_objects.append(players_ref[player_index])

func _fantasy_update_cannot_tree_damage_target() -> void:
    for player_index in range(players_ref.size()):
        if !RunData.get_player_effect_bool(Utils.fantasy_cannot_damage_tree_hash, player_index):
            continue

        if current_target != players_ref[player_index]:
            continue

        current_target.disconnect("died", self, "_on_target_died")
        current_target = null
        break

func _fantasy_is_playing_shoot_animation_cannot_tree_damage(is_playing_shoot: bool) -> bool:
    for player_index in range(players_ref.size()):
        if !RunData.get_player_effect_bool(Utils.fantasy_cannot_damage_tree_hash, player_index):
            continue

        if current_target == null:
            update_target()
            return true

    return is_playing_shoot

func _fantasy_cannot_damage_tree(hitbox: Area2D) -> void:
    if (
        not is_instance_valid(hitbox)
        or not is_instance_valid(hitbox.from)
        or hitbox.from.player_index == -1
        or hitbox.from.player_index == RunData.DUMMY_PLAYER_INDEX
    ): return

    var player_index: int = hitbox.from.player_index
    if RunData.get_player_effect_bool(Utils.fantasy_cannot_damage_tree_hash, player_index):
        hitbox.ignored_objects.append(self)

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
func fa_apply_stat_to_both(target_stat: int, value: int) -> void:
    match target_stat:
        Utils.FANTASY_ENEMY_HP:
            current_stats.health += value
            max_stats.health += value
        Utils.FANTASY_ENEMY_SPEED:
            FANTASY_ENEMY_SPEED_MODIFIER_SERVICE.add_base_speed(self, value)
        Utils.FANTASY_ENEMY_DAMAGE:
            current_stats.damage += value
            max_stats.damage += value
        Utils.FANTASY_ENEMY_ARMOR:
            current_stats.armor += value
            max_stats.armor += value
