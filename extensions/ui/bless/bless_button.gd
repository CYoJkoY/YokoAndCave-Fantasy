extends MyMenuButton

var item_popup: ItemPopup
var popup_manager: PopupManager
var _refresh_queued: bool = false

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    item_popup.connect("visibility_changed", self, "queue_refresh")
    for control in [item_popup._combine_button, item_popup._upgrade_button, item_popup._discard_button, item_popup._cancel_button, item_popup._effect_choice_container]:
        if control != null:
            control.connect("visibility_changed", self, "queue_refresh")
    popup_manager.connect("element_focused", self, "_on_popup_content_changed")
    popup_manager.connect("shop_item_focused", self, "_on_popup_content_changed")
    popup_manager.connect("element_pressed", self, "_on_element_pressed")
    queue_refresh()

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _on_popup_content_changed(_element: Control, player_index: int) -> void:
    if player_index == item_popup.player_index:
        queue_refresh()

func _on_element_pressed(_element: InventoryElement, player_index: int, _popup_focused: bool) -> void:
    if player_index == item_popup.player_index:
        queue_refresh()

func queue_refresh() -> void:
    if _refresh_queued:
        return
    _refresh_queued = true
    call_deferred("_refresh_deferred")

func _refresh_deferred() -> void:
    _refresh_queued = false
    var can_show: bool = item_popup.buttons_enabled and item_popup._is_inventory_element and item_popup._item_data != null and item_popup._pending_upgrade == null
    can_show = can_show and item_popup.is_visible_in_tree() and (not RunData.is_coop_run or item_popup._focused)
    if can_show:
        var blessing: Dictionary = Utils.fa_get_bless_info(item_popup._item_data, item_popup.player_index)
        can_show = blessing.can_bless
        if blessing.can_bless:
            text = tr("MENU_FANTASY_BLESS") + " (" + str(blessing.cost) + ")"
    visible = can_show
    focus_mode = Control.FOCUS_ALL if can_show and item_popup._focused else Control.FOCUS_NONE

    var cancel_button: Control = item_popup._cancel_button
    if item_popup._pending_upgrade != null:
        var effect_button_0: Control = item_popup._effect_button_0
        var effect_button_1: Control = item_popup._effect_button_1
        cancel_button.focus_previous = cancel_button.get_path_to(effect_button_1)
        effect_button_0.focus_next = effect_button_0.get_path_to(effect_button_1)
        effect_button_1.focus_previous = effect_button_1.get_path_to(effect_button_0)
        effect_button_1.focus_next = effect_button_1.get_path_to(cancel_button)
        return

    var buttons: Array = []
    for button in [item_popup._combine_button, item_popup._upgrade_button, item_popup._discard_button, self, cancel_button]:
        if button != null and button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL:
            buttons.append(button)
    for i in range(buttons.size()):
        var button: Control = buttons[i]
        var previous: Control = buttons[max(0, i - 1)]
        var next: Control = buttons[min(buttons.size() - 1, i + 1)]
        button.focus_neighbour_top = button.get_path_to(previous)
        button.focus_neighbour_bottom = button.get_path_to(next)
        button.focus_previous = button.get_path_to(previous)
        button.focus_next = button.get_path_to(next)
