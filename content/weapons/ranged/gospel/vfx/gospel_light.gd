extends Node2D

const VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")

var _time: float = 0.0
var _energy: float = 0.0
var _active: bool = true

onready var _aura: Sprite = $Aura
onready var _motes: CPUParticles2D = $Motes


func set_active(active: bool) -> void:
    if _active == active:
        return
    _active = active
    visible = active
    _motes.emitting = active


func play_pulse() -> void:
    _energy = 1.0


func _process(delta: float) -> void:
    if not _active:
        return
    _time += delta
    _energy = max(0.0, _energy - delta * 3.5)
    position = get_parent().offset
    modulate.a = VISUAL_UTILS.get_opacity()
    _aura.scale = Vector2.ONE * (1.2 + sin(_time * 2.2) * 0.05 + _energy * 0.12)
    _aura.modulate.a = 0.3 + sin(_time * 2.2) * 0.04 + _energy * 0.14
