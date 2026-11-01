extends "res://ui/menus/shop/item_description.gd"

const FANTASY_DESCRIPTION_VISUALS = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/ui/unique/visuals.gd")

func set_item(item_data: ItemParentData, player_index: int, item_count: int = 1) -> void:
    FANTASY_DESCRIPTION_VISUALS.clear(_name)
    FANTASY_DESCRIPTION_VISUALS.clear(icon_panel)
    .set_item(item_data, player_index, item_count)
    if !FANTASY_DESCRIPTION_VISUALS.RULES.is_unique(item_data): return
    if silhouette_locked_items and item_data._is_silhouette_in_codex(): return
    _name.text = tr(item_data.name)
    _name.modulate = Color.white
    FANTASY_DESCRIPTION_VISUALS.apply(_name)
    FANTASY_DESCRIPTION_VISUALS.apply(icon_panel, true)

func set_custom_data(name: String, icon: Resource) -> void:
    FANTASY_DESCRIPTION_VISUALS.clear(_name)
    FANTASY_DESCRIPTION_VISUALS.clear(icon_panel)
    .set_custom_data(name, icon)
