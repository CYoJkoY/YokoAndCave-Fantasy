extends EnemyEffectBehavior

class ActiveErosion:
    var marked_for_removal: bool = false
    var player_index: int = -1
    var damage: int = 0
    var current_times: int = 3
    var times: int = 3
    var cd: float = 0.5
    var current_cd: float = 0.5
    var crit_chance: float = 0.0
    var crit_damage: float = 1.5
    var stacks: int = 1
    var source_id: int = Keys.empty_hash
    var weapon_pos: int = -1

var active_erosions: Array = []

onready var erosion_particles: CPUParticles2D = $"ErosionParticles"
onready var erosion_glow: CPUParticles2D = $"ErosionParticles/Glow"
onready var timer: Timer = $"Timer"

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func should_add_on_spawn() -> bool:
    for player_index in range(RunData.get_player_count()):
        if Utils.fa_has_erosion(player_index): return true

    return false

func on_hurt(hitbox: Hitbox) -> void:
    var from: Node = hitbox.from

    if !is_instance_valid(from) or !("player_index" in from): return

    var from_player_index: int = from.player_index if (from.player_index != -1) else RunData.DUMMY_PLAYER_INDEX
    var item_effects: Array = RunData.get_player_effect(Utils.fantasy_erosion_hash, from_player_index)
    var speed_boost: float = max(0.01, 1.0 + Utils.get_stat(Utils.fantasy_erosion_speed_hash, from_player_index) / 100.0)
    var erosion_crit: float = Utils.get_capped_stat(Keys.stat_crit_chance_hash, from_player_index) / 100.0 \
        if RunData.get_player_effect_bool(Utils.fantasy_erosion_can_crit_hash, from_player_index) else 0.0

    for item_effect in item_effects:
        var base_damage: int = item_effect[0]
        var scaling_stats: Array = item_effect[1]
        var chance: float = item_effect[2] / 100.0
        var times: int = item_effect[3]
        var cd: float = item_effect[4] / 60.0 / speed_boost
        var crit_chance: float = item_effect[5] / 100.0 + erosion_crit
        var crit_damage: float = item_effect[6]
        var source_id: int = item_effect[7]
        fa_try_add_erosion(from_player_index, base_damage, scaling_stats, chance, times, cd, crit_chance, crit_damage, source_id)

    for effect in hitbox.effects:
        if effect.get_id() != "fantasy_erosion": continue

        var base_damage: int = effect.value
        var scaling_stats: Array = effect.scaling_stats
        var chance: float = effect.chance / 100.0
        var times: int = effect.times
        var cd: float = effect.cd / 60.0 / speed_boost
        var crit_chance: float = effect.crit_chance / 100.0 + erosion_crit
        var crit_damage: float = effect.crit_damage
        var source_id: int = effect.source_id_hash
        var weapon_pos: int = from.weapon_pos if from is Weapon else -1
        fa_try_add_erosion(from_player_index, base_damage, scaling_stats, chance, times, cd, crit_chance, crit_damage, source_id, weapon_pos)

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
func fa_try_add_erosion(from_player_index: int, base_damage: int, scaling_stats: Array, chance: float, times: int, cd: float, crit_chance: float, crit_damage: float, source_id: int, weapon_pos: int = -1) -> void:
    if !Utils.get_chance_success(chance): return

    var damage: int = Utils.ncl_get_dmg_with_scaling_stats(base_damage, scaling_stats, from_player_index)
    for existing_erosion in active_erosions:
        if existing_erosion.source_id != source_id or existing_erosion.player_index != from_player_index: continue
        if existing_erosion.weapon_pos != weapon_pos: continue
        if existing_erosion.damage != damage or existing_erosion.times != times or existing_erosion.cd != cd: continue
        if existing_erosion.crit_chance != crit_chance or existing_erosion.crit_damage != crit_damage: continue

        existing_erosion.stacks += 1
        existing_erosion.marked_for_removal = false
        return

    var erosion: ActiveErosion = ActiveErosion.new()
    erosion.player_index = from_player_index
    erosion.damage = damage
    erosion.current_times = times
    erosion.times = times
    erosion.cd = cd
    erosion.current_cd = cd
    erosion.crit_chance = crit_chance
    erosion.crit_damage = crit_damage
    erosion.stacks = 1
    erosion.source_id = source_id
    erosion.weapon_pos = weapon_pos
    active_erosions.append(erosion)

    if timer.is_stopped():
        erosion_particles.emitting = true
        erosion_glow.emitting = true
        timer.start()

func fa_on_Timer_timeout() -> void:
    for i in range(active_erosions.size() - 1, -1, -1):
        var erosion: ActiveErosion = active_erosions[i]
        erosion.current_cd -= 0.1
        while erosion.current_cd <= 0.00001 and not erosion.marked_for_removal:
            if _parent.dead or _parent._pending_die: return
            erosion.current_cd += erosion.cd
            fa_on_erosion_cd_timeout(erosion)

        if erosion.marked_for_removal: active_erosions.remove(i)

    if active_erosions.empty():
        erosion_particles.emitting = false
        erosion_glow.emitting = false
        timer.stop()

func fa_on_erosion_cd_timeout(erosion: ActiveErosion) -> void:
    var damage_args: TakeDamageArgs = Utils.ncl_create_custom_damage_args(erosion.player_index, Color.white)
    damage_args.set_meta("fantasy_erosion_gradient", true)
    var final_damage: int = erosion.damage
    var was_crit: bool = Utils.get_chance_success(erosion.crit_chance)
    if was_crit:
        final_damage = int(erosion.damage * erosion.crit_damage)

    var health_before: int = _parent.current_stats.health
    var take_damage_array: Array = _parent.take_damage(final_damage, damage_args)
    RunData.add_tracked_value(erosion.player_index, erosion.source_id, take_damage_array[1])
    if erosion.weapon_pos >= 0:
        RunData.add_weapon_dmg_dealt(erosion.weapon_pos, take_damage_array[1], erosion.player_index)
    Utils.fa_apply_direct_crit_kill_gold_rewards(
        erosion.player_index,
        was_crit,
        health_before > 0 and take_damage_array[1] >= health_before
    )

    erosion.current_times -= 1
    if erosion.current_times > 0: return

    erosion.stacks -= 1
    erosion.current_times = erosion.times
    if erosion.stacks > 0: return

    erosion.marked_for_removal = true
