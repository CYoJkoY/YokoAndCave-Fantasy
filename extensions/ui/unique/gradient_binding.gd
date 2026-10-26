extends Node

const GRADIENT = preload("res://mods-unpacked/Yoko-Fantasy/extensions/ui/unique/gradient.gdshader")

var target: Control
var original_material: Material
var gradient_material: ShaderMaterial
var active: bool = false

func _ready() -> void:
    target = get_parent()
    gradient_material = ShaderMaterial.new()
    gradient_material.shader = GRADIENT
    target.connect("resized", self, "_update_width")

func apply(soft_background: bool = false) -> void:
    if !active:
        original_material = target.material
        active = true
    gradient_material.set_shader_param("soft_background", soft_background)
    target.material = gradient_material
    _update_width()

func clear() -> void:
    if !active: return
    target.material = original_material
    active = false

func _update_width() -> void:
    gradient_material.set_shader_param("control_size", target.rect_size)
