extends "res://ui/menus/shop/coop_shop.gd"

const FANTASY_COOP_SHOP_SERVICE = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/shop_service.gd")
const BUTTON_SHOW_JOB = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/jobs/button_show_job_scene.tscn")

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    FANTASY_COOP_SHOP_SERVICE._fantasy_on_shop_ready(self)
    for player_index in RunData.get_player_count():
        var job_button: MyMenuButton = BUTTON_SHOW_JOB.instance()
        job_button.menu_player_index = player_index
        job_button.attach_to_inventory(_get_gear_container(player_index).items_container, $Content, self)

func _on_element_pressed(element: InventoryElement, player_index: int, popup_focused: bool) -> void:
    if popup_focused:
        ._on_element_pressed(element, player_index, popup_focused)
        return

    if element.item is ItemData:
        if _focused_shop_item[player_index] != null:
            _focused_shop_item[player_index]._can_be_selected(false)
        FANTASY_COOP_SHOP_SERVICE._fantasy_show_item_popup(self, element, player_index)
        _get_coop_player_container(player_index).on_show_focused_inventory_popup()
        return

    ._on_element_pressed(element, player_index, popup_focused)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _fantasy_on_popup_bless_pressed(
    item_popup: ItemPopup,
    get_gear_container: FuncRef,
    update_stats: FuncRef,
    player_index: int
) -> void:
    FANTASY_COOP_SHOP_SERVICE._fantasy_on_popup_bless_pressed(
        self, item_popup, get_gear_container, update_stats, player_index
    )
    if not item_popup.visible:
        _get_coop_player_container(player_index).on_hide_focused_inventory_popup()
