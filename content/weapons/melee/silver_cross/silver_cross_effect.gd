extends NullEffect


static func get_id() -> String:
    return "weapon_silver_cross"


func get_scaling_stats() -> Array:
    return [[Utils.stat_fantasy_holy_hash, 1.0]]


func get_damage(player_index: int) -> int:
    var scaling: Array = WeaponService._apply_weapon_scaling_stat_effects(get_scaling_stats(), player_index)
    var damage: int = WeaponService.apply_scaling_stats_to_damage(value, scaling, player_index)
    return WeaponService.apply_damage_bonus(damage, player_index)


func get_args(player_index: int) -> Array:
    var damage: int = get_damage(player_index)
    var text: String = "[color=%s]%s[/color]" % [Utils.ncl_get_signed_col(damage, value), str(damage)]
    if damage != value:
        text += " [color=%s]|%s[/color]" % [Utils.GRAY_COLOR_STR, str(value)]
    text += " (" + WeaponService.get_scaling_stats_icon_text(get_scaling_stats()) + ")"
    return [text]
