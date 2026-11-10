extends NullEffect

const RECOVERY: float = 0.96
const TARGET_COUNT: int = 7
const BASE_RADIUS: int = 800
const CROSS_RADIUS: int = 128


static func get_id() -> String:
    return "weapon_seven_star_sword"


func get_scaling_stats() -> Array:
    return [[Keys.stat_melee_damage_hash, 1.25], [Utils.stat_fantasy_holy_hash, 1.25]]


func get_damage(player_index: int) -> int:
    var scaling: Array = WeaponService._apply_weapon_scaling_stat_effects(get_scaling_stats(), player_index)
    return WeaponService.apply_damage_bonus(WeaponService.apply_scaling_stats_to_damage(value, scaling, player_index), player_index)


func get_radius(player_index: int) -> float:
    return float(Utils.ncl_get_int_num_with_scaling_stats(BASE_RADIUS, [[Keys.stat_range_hash, 0.5]], player_index))


func get_args(player_index: int) -> Array:
    var text: String = Utils.fa_format_damage_with_scaling_stats(get_damage(player_index), value, get_scaling_stats())
    var radius: String = Utils.ncl_get_int_num_text_with_scaling_stats(BASE_RADIUS, [[Keys.stat_range_hash, 0.5]], {"player_index": player_index})
    return [text, radius, str(RECOVERY), str(CROSS_RADIUS)]
