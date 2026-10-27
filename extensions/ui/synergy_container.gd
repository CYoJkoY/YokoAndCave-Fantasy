extends "res://ui/menus/shop/synergy_container.gd"

const FANTASY_UNIQUE = preload("res://mods-unpacked/Yoko-Fantasy/extensions/services/unique_weapon_service.gd")

func set_synergies_text(item_data: ItemParentData, player_index: int) -> void:
    .set_synergies_text(item_data, player_index)
    if !(item_data is WeaponData): return
    for i in item_data.sets.size():
        if item_data.sets[i].my_id != FANTASY_UNIQUE.SET_ID: continue
        var panel = synergy_panels[i]
        panel._plain_text = tr("WEAPON_CLASS_FANTASY_UNIQUE_DESCRIPTION")
        panel._synergy_effects.bbcode_text = panel._plain_text
        panel._resize_to_text()
