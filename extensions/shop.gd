extends "res://ui/menus/shop/shop.gd"

const FANTASY_SHOP_SERVICE = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/shop_service.gd")
const BUTTON_SHOW_JOB = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/jobs/button_show_job_scene.tscn")

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    FANTASY_SHOP_SERVICE._fantasy_on_shop_ready(self)
    var job_button: MyMenuButton = BUTTON_SHOW_JOB.instance()
    job_button.attach_to_inventory(_get_gear_container(0).items_container, $Content, self)

func _on_element_pressed(element: InventoryElement, player_index: int, popup_focused: bool) -> void:
    if popup_focused:
        ._on_element_pressed(element, player_index, popup_focused)
        return

    if element.item is ItemData:
        if _focused_shop_item[player_index] != null:
            _focused_shop_item[player_index]._can_be_selected(false)
        FANTASY_SHOP_SERVICE._fantasy_show_item_popup(self, element, player_index)
        _block_background.show()
        return

    ._on_element_pressed(element, player_index, popup_focused)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _fantasy_on_popup_bless_pressed(
    item_popup: ItemPopup,
    get_gear_container: FuncRef,
    update_stats: FuncRef,
    player_index: int
) -> void:
    FANTASY_SHOP_SERVICE._fantasy_on_popup_bless_pressed(
        self, item_popup, get_gear_container, update_stats, player_index
    )
