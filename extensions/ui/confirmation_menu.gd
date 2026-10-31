extends Reference

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
static func init(menu: Control) -> void:
    menu.focus_before_created = Utils.fa_get_menu_focused_control(menu, 0)
    Utils.fa_focus_menu_control(menu.get_node("Buttons/ConfirmButton"), 0)

static func handle_input(menu: Control, event: InputEvent) -> void:
    if menu.visible and event.is_action_released("ui_cancel"):
        cancel(menu)
        menu.get_tree().set_input_as_handled()

static func cancel(menu: Control) -> void:
    Utils.fa_focus_menu_control(menu.focus_before_created, 0)
    menu.emit_signal("cancel_button_pressed")
