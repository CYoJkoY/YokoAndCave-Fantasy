extends "res://ui/menus/pages/menu_end_run.gd"

const FANTASY_CONFIRMATION_MENU = preload("res://mods-unpacked/Yoko-Fantasy/extensions/ui/confirmation_menu.gd")

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func init() -> void:
    FANTASY_CONFIRMATION_MENU.init(self)

func _input(event: InputEvent) -> void:
    FANTASY_CONFIRMATION_MENU.handle_input(self, event)

func _on_CancelButton_pressed() -> void:
    FANTASY_CONFIRMATION_MENU.cancel(self)
