extends NullEffect

const ECHO_DELAY: float = 0.28
const ECHO_DURATION: float = 0.22
const ECHO_FADE: float = 0.52
const ECHO_RANGE_MULTIPLIER: float = 1.90
const ECHO_MAX_SCALE: float = 2.0
const ECHO_HALF_ANGLE: float = 1.75


static func get_id() -> String:
    return "weapon_dead_hand"


func get_scaling_stats() -> Array:
    return [[Keys.stat_curse_hash, 2.0]]


func get_damage(player_index: int) -> int:
    var scaling: Array = WeaponService._apply_weapon_scaling_stat_effects(get_scaling_stats(), player_index)
    var damage: int = WeaponService.apply_scaling_stats_to_damage(value, scaling, player_index)
    return WeaponService.apply_damage_bonus(damage, player_index)


func get_args(player_index: int) -> Array:
    return [str(ECHO_DELAY), Utils.fa_format_damage_with_scaling_stats(get_damage(player_index), value, get_scaling_stats())]
