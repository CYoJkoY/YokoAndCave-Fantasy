extends NullEffect


static func get_id() -> String:
    return "fantasy_annihilation_ray"


func get_explosion_stats() -> MeleeWeaponStats:
    var blast_stats = MeleeWeaponStats.new()
    blast_stats.damage = value
    blast_stats.scaling_stats = [[Keys.stat_curse_hash, 1.0]]
    return blast_stats


func get_args(player_index: int) -> Array:
    var blast_stats = get_explosion_stats()
    var damage: int = WeaponService.get_explosion_damage(blast_stats, player_index)
    var damage_text: String = "[color=%s]%s[/color]" % [Utils.ncl_get_signed_col(damage, value), str(damage)]
    if damage != value:
        damage_text += " [color=%s]|%s[/color]" % [Utils.GRAY_COLOR_STR, str(value)]
    damage_text += " (" + WeaponService.get_scaling_stats_icon_text(blast_stats.scaling_stats) + ")"
    return [damage_text]
