extends "res://visual_effects/floating_text/floating_text_manager.gd"

const EROSION_TEXT_MATERIAL = preload("res://mods-unpacked/Yoko-Fantasy/content/visual_effects/erosion_damage_text.tres")
const TAMBOURINE_TEXT_INTERVAL: float = 0.08

var _fantasy_erosion_text_pending: bool = false
var _fantasy_tambourine_texts: Dictionary = {}
var _fantasy_tambourine_text_elapsed: float = 0.0

# ══════════════════════════════════════════ Extension ══════════════════════════════════ #
func _ready() -> void:
    set_process(false)

func _process(delta: float) -> void:
    _fantasy_tambourine_text_elapsed += delta
    if _fantasy_tambourine_text_elapsed >= TAMBOURINE_TEXT_INTERVAL:
        _fantasy_flush_tambourine_texts()

func clean_up_room() -> void:
    _fantasy_flush_tambourine_texts()
    .clean_up_room()

func _exit_tree() -> void:
    for batch in _fantasy_tambourine_texts.values():
        var unit = batch.unit
        if is_instance_valid(unit) and unit.is_connected("tree_exiting", self, "_fantasy_flush_tambourine_unit"):
            unit.disconnect("tree_exiting", self, "_fantasy_flush_tambourine_unit")
    _fantasy_tambourine_texts.clear()
    set_process(false)

func _on_unit_took_damage(unit: Unit, value: int, knockback_direction: Vector2, is_crit: bool, is_dodge: bool, is_protected: bool, armor_did_something: bool, args: TakeDamageArgs, hit_type: int, is_one_shot: bool) -> void:
    if not ProgressData.settings.damage_display:
        return
    if not _cleaning_up and unit is Enemy and is_instance_valid(args.hitbox) \
            and args.hitbox.has_meta("fantasy_tambourine_damage") \
            and not args.has_meta("custom_color") and not args.has_meta("custom_icon") \
            and not args.has_meta("fantasy_erosion_gradient"):
        _fantasy_queue_tambourine_text(unit, value, args.from_player_index, args.hitbox.get_meta("fantasy_damage_color"))
        return
    var display_args: TakeDamageArgs = args
    if not args.has_meta("custom_color") and is_instance_valid(args.hitbox) and args.hitbox.has_meta("fantasy_damage_color"):
        display_args = Utils.ncl_create_custom_damage_args(args.from_player_index, args.hitbox.get_meta("fantasy_damage_color"), args.get_meta("custom_icon", Keys.empty_hash))
    var previous_erosion_text_pending: bool = _fantasy_erosion_text_pending
    _fantasy_erosion_text_pending = args.has_meta("fantasy_erosion_gradient")
    ._on_unit_took_damage(unit, value, knockback_direction, is_crit, is_dodge, is_protected, armor_did_something, display_args, hit_type, is_one_shot)
    _fantasy_erosion_text_pending = previous_erosion_text_pending

func get_floating_text() -> FloatingText:
    var is_erosion_text: bool = _fantasy_erosion_text_pending
    _fantasy_erosion_text_pending = false
    var instance: FloatingText = .get_floating_text()
    if is_erosion_text:
        instance.material = EROSION_TEXT_MATERIAL
    return instance

func on_floating_text_available(instance: FloatingText) -> void:
    if instance.material == EROSION_TEXT_MATERIAL:
        instance.material = null
    .on_floating_text_available(instance)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _fantasy_queue_tambourine_text(unit: Unit, value: int, player_index: int, color: Color) -> void:
    if _fantasy_tambourine_texts.empty():
        _fantasy_tambourine_text_elapsed = 0.0
        set_process(true)
    var unit_id: int = unit.get_instance_id()
    if not _fantasy_tambourine_texts.has(unit_id):
        _fantasy_tambourine_texts[unit_id] = {"unit": unit, "groups": {}}
        unit.connect("tree_exiting", self, "_fantasy_flush_tambourine_unit", [unit_id])
    var groups: Dictionary = _fantasy_tambourine_texts[unit_id].groups
    if not groups.has(player_index):
        groups[player_index] = {"value": 0, "color": color, "position": unit.global_position}
    var entry: Dictionary = groups[player_index]
    entry.value += value
    entry.position = unit.global_position
    if unit._pending_die:
        _fantasy_flush_tambourine_unit(unit_id)

func _fantasy_flush_tambourine_unit(unit_id: int) -> void:
    var batch: Dictionary = _fantasy_tambourine_texts[unit_id]
    _fantasy_tambourine_texts.erase(unit_id)
    var unit = batch.unit
    if is_instance_valid(unit) and unit.is_connected("tree_exiting", self, "_fantasy_flush_tambourine_unit"):
        unit.disconnect("tree_exiting", self, "_fantasy_flush_tambourine_unit")
    if ProgressData.settings.damage_display and is_inside_tree() and not get_parent().is_queued_for_deletion():
        var previous_erosion_text_pending: bool = _fantasy_erosion_text_pending
        _fantasy_erosion_text_pending = false
        for entry in batch.groups.values():
            display(str(entry.value), entry.position, entry.color, null, duration, true, direction, false)
        _fantasy_erosion_text_pending = previous_erosion_text_pending
    if _fantasy_tambourine_texts.empty():
        set_process(false)

func _fantasy_flush_tambourine_texts() -> void:
    for unit_id in _fantasy_tambourine_texts.keys():
        _fantasy_flush_tambourine_unit(unit_id)
    _fantasy_tambourine_text_elapsed = 0.0
