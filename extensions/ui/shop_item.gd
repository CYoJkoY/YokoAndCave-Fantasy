extends "res://ui/menus/shop/shop_item.gd"

const FANTASY_SHOP_VISUALS = preload("res://mods-unpacked/Yoko-Fantasy/extensions/ui/unique/visuals.gd")

func _set_panel_lock_style() -> void:
    var panel: Control = _item_description.icon_panel if RunData.is_coop_run else _panel
    FANTASY_SHOP_VISUALS.clear(panel)
    ._set_panel_lock_style()
    if FANTASY_SHOP_VISUALS.RULES.is_unique(item_data):
        FANTASY_SHOP_VISUALS.apply(panel, RunData.is_coop_run)
