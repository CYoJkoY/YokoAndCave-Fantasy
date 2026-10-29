extends "res://ui/menus/run/weapon_selection.gd"

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _get_all_possible_elements(player_index: int) -> Array:
    var elements: Array = ._get_all_possible_elements(player_index)
    for weapon in _fantasy_get_additional_starting_weapons(player_index):
        var insert_at: int = elements.size()
        var already_present: bool = false
        for index in range(elements.size()):
            var element = elements[index]
            if element is WeaponData and element.my_id == weapon.my_id:
                already_present = true
                break
            if insert_at != elements.size(): continue
            if !(element is WeaponData) or (weapon.type == WeaponType.MELEE and element.type == WeaponType.RANGED):
                insert_at = index
        if !already_present:
            elements.insert(insert_at, weapon)
    return elements

func _get_unlocked_elements(player_index: int) -> Array:
    var elements: Array = ._get_unlocked_elements(player_index)
    for weapon in _fantasy_get_additional_starting_weapons(player_index):
        if ProgressData.weapons_unlocked.has(weapon.weapon_id_hash) and !elements.has(weapon.my_id_hash):
            elements.append(weapon.my_id_hash)
    return elements

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _fantasy_get_additional_starting_weapons(player_index: int) -> Array:
    return ProgressData.get_dlc_data("Yoko-Fantasy").get_additional_starting_weapons(RunData.get_player_character(player_index))
