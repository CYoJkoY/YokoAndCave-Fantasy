extends Reference

const BINDING = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/ui/unique/gradient_binding.gd")
const RULES = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/unique_weapon_service.gd")

static func clear(control: Control) -> void:
    var binding: Node = control.get_node_or_null("FantasyUniqueGradient")
    if binding != null: binding.clear()

static func apply(control: Control, soft_background: bool = false) -> void:
    var binding: Node = control.get_node_or_null("FantasyUniqueGradient")
    if binding == null:
        binding = BINDING.new()
        binding.name = "FantasyUniqueGradient"
        control.add_child(binding)
    binding.apply(soft_background)
