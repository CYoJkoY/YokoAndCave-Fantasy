extends MyMenuButton

var job_menu_scene = load("res://mods-unpacked/YokoAndCave-Fantasy/extensions/jobs/job_menu.tscn")
var current_scene: Node = null
var global_scene: Node = null
var menu_player_index: int = 0

func _ready() -> void:
    for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
        var style: StyleBox = get_stylebox(style_name).duplicate()
        style.content_margin_right = 12.0
        add_stylebox_override(style_name, style)
    connect("resized", self, "_update_minimum_width")
    _update_minimum_width()

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
        _update_minimum_width()

func _update_minimum_width() -> void:
    var style: StyleBox = get_stylebox("normal")
    var text_width: float = get_font("font").get_string_size(tr(text)).x
    var icon_size: Vector2 = icon.get_size()
    var icon_height: float = max(rect_size.y, rect_min_size.y) - style.get_minimum_size().y
    var icon_width: float = icon_height * icon_size.x / icon_size.y
    var content_width: float = text_width + icon_width + get_constant("hseparation")
    rect_min_size.x = max(105.0, ceil(content_width + style.get_minimum_size().x))

func attach_to_inventory(inventory: InventoryContainer, content: Node, menu_parent: Node) -> void:
    current_scene = content
    global_scene = menu_parent
    var header: HBoxContainer = inventory.get_node("HBoxContainer")
    var sort_button: OptionButton = header.get_node("Sort_Inventory_button")
    var before_sort_index: int = sort_button.get_index()
    header.add_child(self)
    header.move_child(self, before_sort_index)
    visible = inventory.authorize_sorting
    focus_neighbour_right = get_path_to(sort_button)
    sort_button.focus_neighbour_left = sort_button.get_path_to(self)

func on_pressed() -> void:
    .on_pressed()

    var opening_player: int = FocusEmulatorSignal.get_player_index(self)
    if opening_player < 0:
        opening_player = menu_player_index
        if global_scene is IngameMainMenu:
            opening_player = global_scene.player_index

    var job_menu: PanelContainer = global_scene.get_node_or_null("JobMenu")
    if job_menu == null:
        job_menu = job_menu_scene.instance()
        job_menu.hide()
        global_scene.add_child(job_menu)
        job_menu.call_deferred("open_menu", current_scene, opening_player, self)
        return

    job_menu.call("open_menu", current_scene, opening_player, self)
