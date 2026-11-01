extends NullEffect

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
static func get_id() -> String:
    return "fantasy_soul_effect"

func apply(player_index: int) -> void:
    Utils.ncl_quiet_add_stat(Utils.stat_fantasy_soul_hash, value, player_index)

    if Utils.get_scene_node()._cleaning_up: return

    var bonus: int = 10 + RunData.get_player_effect(Utils.fantasy_soul_bonus_hash, player_index)

    TempStats.add_stat(Keys.stat_percent_damage_hash, bonus, player_index)
    TempStats.add_stat(Keys.stat_attack_speed_hash, bonus, player_index)
    RunData.emit_signal("on_soul_effect", bonus, bonus, player_index)
