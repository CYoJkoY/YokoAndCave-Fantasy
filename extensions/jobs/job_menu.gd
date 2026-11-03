extends PanelContainer

onready var job_container: VBoxContainer = $"JobCont"
onready var job_tabscontainer: HBoxContainer = $"JobCont/HBoxContainer"

onready var cross_button: Button = $"%CrossButton"
var focus_before_created: Control = null
onready var _item_popup = $"%ItemPopup"
onready var _pause_menu: PauseMenu = find_parent("PauseMenu") as PauseMenu

onready var job_player_conts: Array = [
    $"%JobPlayerCont1/VPlayerCont",
    $"%JobPlayerCont2/VPlayerCont",
    $"%JobPlayerCont3/VPlayerCont",
    $"%JobPlayerCont4/VPlayerCont",
]

onready var jobs_conts: Array = [
    $"%JobsCont1",
    $"%JobsCont2",
    $"%JobsCont3",
    $"%JobsCont4",
]

var scene_before_created: Node = null
var _job_ui_1: Array = [null, null, null, null]
var _job_ui_2: Array = [null, null, null, null]
var _job_ui_3: Array = [null, null, null, null]
var _jobs1: Array = [null, null, null, null]
var _jobs2: Array = [null, null, null, null]
var _job_elements_hovered: Array = [null, null, null, null]
var _job_elements_focused: Array = [null, null, null, null]
var job_tab_buts: Array = [null, null, null, null]
var menu_player_index: int = 0
var _focus_emulator: FocusEmulator = null
var _previous_focus_emulator: FocusEmulator = null
var _focus_emulator_states: Dictionary = {}
var _shop_input_enabled: bool = false
var _pause_input_enabled: bool = false

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if Utils.is_player_cancel_released(event, menu_player_index) or Utils.is_player_pause_released(event, menu_player_index):
        get_tree().set_input_as_handled()
        _fantasy_close_menu()
    elif Utils.is_player_cancel_pressed(event, menu_player_index) or Utils.is_player_action_pressed(event, menu_player_index, "ui_pause"):
        get_tree().set_input_as_handled()
    elif Utils.is_player_action_pressed(event, menu_player_index, "ltrigger") or Utils.is_player_action_pressed(event, menu_player_index, "rtrigger"):
        var direction: int = -1 if Utils.is_player_action_pressed(event, menu_player_index, "ltrigger") else 1
        var index: int = clamp(job_container.tab_container.current_tab + direction, 0, RunData.get_player_count() - 1)
        job_container._change_tab(index)
        _fantasy_focus_control(job_tab_buts[index])
        get_tree().set_input_as_handled()

func _ready():
    job_container.use_shoulder_to_swap_tab = false
    if _pause_menu != null:
        _pause_menu.connect("unpaused", self, "_fantasy_close_menu")
    if RunData.is_coop_run:
        _focus_emulator = FocusEmulator.new()
        var base: FocusEmulatorBaseData = FocusEmulatorBaseData.new()
        base.path = NodePath("..")
        base.contain_horizontal_focus = true
        base.contain_vertical_focus = true
        _focus_emulator.focus_base_data = [base]
        add_child(_focus_emulator)
        _focus_emulator.set_process_input(false)

    for player_index in range(RunData.get_player_count()):
        var job_player_cont: VBoxContainer = job_player_conts[player_index]
        _job_ui_1[player_index] = job_player_cont.get_child(0)
        _job_ui_2[player_index] = job_player_cont.get_child(1)
        _job_ui_3[player_index] = job_player_cont.get_child(2)

        var jobs_cont = jobs_conts[player_index]
        _jobs1[player_index] = jobs_cont.get_child(0)
        _jobs2[player_index] = jobs_cont.get_child(1)
        _jobs1[player_index].player_index = player_index
        _jobs2[player_index].player_index = player_index
        _jobs1[player_index]._elements.player_index = player_index
        _jobs2[player_index]._elements.player_index = player_index
        _jobs1[player_index]._label.text = tr("COOP_S1_JOB")
        _jobs2[player_index]._label.text = tr("COOP_S2_JOB")
        _fantasy_connect_inventory_container(_jobs1[player_index])
        _fantasy_connect_inventory_container(_jobs2[player_index])

        job_tab_buts[player_index] = job_tabscontainer.get_child(player_index)
        job_tab_buts[player_index].show()
        job_tab_buts[player_index].text = tr("COOP_PLAYER").format([player_index + 1])

func open_menu(p_scene_before_created: Node = null, player_index: int = 0, return_focus: Control = null) -> void:
    if visible:
        return
    scene_before_created = p_scene_before_created
    menu_player_index = player_index
    focus_before_created = return_focus
    if RunData.is_coop_run:
        _previous_focus_emulator = Utils.fa_get_menu_focus_emulator(menu_player_index)
        var background_emulators: Array = []
        if get_parent() is BaseShop:
            for i in RunData.get_player_count():
                background_emulators.append(Utils.get_focus_emulator(i))
        elif _previous_focus_emulator != null:
            background_emulators.append(_previous_focus_emulator)
        for emulator in background_emulators:
            var focus_connected: bool = get_viewport().is_connected("gui_focus_changed", emulator, "_on_focus_changed")
            _focus_emulator_states[emulator] = {
                "input_enabled": emulator.is_processing_input(),
                "visible": emulator.visible,
                "focus_connected": focus_connected,
            }
            if focus_connected:
                get_viewport().disconnect("gui_focus_changed", emulator, "_on_focus_changed")
            emulator.set_process_input(false)
            emulator.hide()
        _focus_emulator.player_index = menu_player_index
        _focus_emulator.set_process_input(true)
    if get_parent() is BaseShop:
        _shop_input_enabled = get_parent().is_processing_input()
        get_parent().set_process_input(false)
    if _pause_menu != null:
        _pause_input_enabled = _pause_menu.is_processing_input()
        _pause_menu.set_process_input(false)
    show()
    job_container._change_tab(menu_player_index)

func show() -> void:
    .show()
    update_jobs()
    if scene_before_created != null and is_instance_valid(scene_before_created):
        scene_before_created.hide()
    _fantasy_focus_control(cross_button)

func update_jobs() -> void:
    var job_uis: Array = [_job_ui_1, _job_ui_2, _job_ui_3]
    for player_index in range(RunData.get_player_count()):
        for job_stage in range(job_uis.size()):
            var job_data: UpgradeData = RunData.fa_get_current_job(job_stage, player_index)
            if job_data:
                job_uis[job_stage][player_index].set_job(job_data, player_index)

        var jobs1: InventoryContainer = _jobs1[player_index]
        var jobs2: InventoryContainer = _jobs2[player_index]
        jobs1._elements.set_elements(ItemService.fa_get_sorted_jobs_for_menu(0))
        jobs2._elements.set_elements(ItemService.fa_get_sorted_jobs_for_menu(1))

func _on_CrossButton_pressed() -> void:
    _fantasy_close_menu()

func _fantasy_close_menu() -> void:
    if not visible:
        return
    hide()
    _fantasy_reset_job_popup_state()
    if _focus_emulator != null:
        _focus_emulator.set_process_input(false)
        _focus_emulator.focused_control = null
    if scene_before_created != null and is_instance_valid(scene_before_created):
        scene_before_created.show()
    if focus_before_created != null and is_instance_valid(focus_before_created):
        Utils.focus_player_control(focus_before_created, menu_player_index, _previous_focus_emulator)
    for emulator in _focus_emulator_states:
        if is_instance_valid(emulator):
            var state: Dictionary = _focus_emulator_states[emulator]
            if state.focus_connected and not get_viewport().is_connected("gui_focus_changed", emulator, "_on_focus_changed"):
                get_viewport().connect("gui_focus_changed", emulator, "_on_focus_changed")
            if _pause_menu == null or get_tree().paused:
                emulator.set_process_input(state.input_enabled)
            emulator.visible = state.visible
    _focus_emulator_states.clear()
    if get_parent() is BaseShop:
        get_parent().set_process_input(_shop_input_enabled)
    if _pause_menu != null:
        _pause_menu.set_process_input(_pause_input_enabled and get_tree().paused)

func _fantasy_focus_control(control: Control) -> void:
    Utils.focus_player_control(control, menu_player_index, _focus_emulator)

func _fantasy_connect_inventory_container(container: InventoryContainer) -> void:
    var inventory = container._elements
    inventory.connect("element_hovered", self, "_fantasy_on_job_element_hovered")
    inventory.connect("element_unhovered", self, "_fantasy_on_job_element_unhovered")
    inventory.connect("element_focused", self, "_fantasy_on_job_element_focused")
    inventory.connect("element_unfocused", self, "_fantasy_on_job_element_unfocused")

func _fantasy_on_job_element_hovered(element: InventoryElement) -> void:
    var player_index: int = element.player_index

    _fantasy_focus_control(element)
    _job_elements_hovered[player_index] = element
    _job_elements_focused[player_index] = element
    _fantasy_display_job_element(element, player_index)

func _fantasy_on_job_element_unhovered(element: InventoryElement) -> void:
    var player_index: int = element.player_index
    if _job_elements_hovered[player_index] == element:
        _job_elements_hovered[player_index] = null
        _fantasy_on_job_element_unfocused(element)

func _fantasy_on_job_element_focused(element: InventoryElement) -> void:
    var player_index: int = element.player_index

    _job_elements_focused[player_index] = element
    _fantasy_display_job_element(element, player_index)

func _fantasy_on_job_element_unfocused(element: InventoryElement) -> void:
    var player_index: int = element.player_index
    if _job_elements_focused[player_index] == element:
        _job_elements_focused[player_index] = null
        _item_popup.hide()

func _fantasy_display_job_element(element: InventoryElement, player_index: int) -> void:
    var job_data: UpgradeData = element.item
    _item_popup.player_index = player_index
    _item_popup.display_element(element)
    _fantasy_set_job_popup_category(job_data)

func _fantasy_set_job_popup_category(job_data: UpgradeData) -> void:
    var category_text: String = Utils.fa_get_job_category_text(job_data)
    _item_popup._panel._item_description._category.text = category_text

func _fantasy_reset_job_popup_state() -> void:
    _item_popup.hide()

    for player_index in range(_job_elements_hovered.size()):
        _job_elements_hovered[player_index] = null
        _job_elements_focused[player_index] = null
