extends NullEffect

const ECHO_STATS = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/phantom_gale/phantom_echo_stats.tres")


static func get_id() -> String:
    return "fantasy_phantom_gale"


func get_args(player_index: int) -> Array:
    var current = WeaponService.init_ranged_stats(ECHO_STATS, player_index, true)
    return [str(value), str(current.damage), WeaponService.get_scaling_stats_icon_text(current.scaling_stats)]
