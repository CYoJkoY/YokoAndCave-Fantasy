extends "res://ui/menus/shop/synergy_panel.gd"

const FANTASY_UNIQUE = preload("res://mods-unpacked/Yoko-Fantasy/extensions/services/unique_weapon_service.gd")

func set_data(set: SetData, player_index: int) -> void:
    if set.my_id != FANTASY_UNIQUE.SET_ID:
        .set_data(set, player_index)
        return
    _synergy_name.text = tr(set.name)
    _plain_text = tr("WEAPON_CLASS_FANTASY_UNIQUE_DESCRIPTION")
    _synergy_effects.bbcode_text = _plain_text
    if RunData.is_coop_run:
        _synergy_effects.add_font_override("normal_font", normal_font)
    _resize_to_text()
