extends "res://ui/menus/ingame/item_panel_ui.gd"

const FANTASY_PANEL_VISUALS = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/ui/unique/visuals.gd")

func _update_stylebox() -> void:
    FANTASY_PANEL_VISUALS.clear(self)
    ._update_stylebox()
    if FANTASY_PANEL_VISUALS.RULES.is_unique(item_data):
        FANTASY_PANEL_VISUALS.apply(self)
