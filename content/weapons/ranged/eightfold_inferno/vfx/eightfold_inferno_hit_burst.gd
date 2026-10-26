extends Node2D

const FANTASY_PROJECTILE_VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")

const DURATION: float = 0.3

var _elapsed: float = 0.0
var _main: Node = null
var _pool_id: int = -1
var _opacity: float = 1.0
var _active: bool = false
var _flash_base_scale: float = 0.33
var _ring_base_alpha: float = 0.8

onready var _flash: Sprite = $Flash
onready var _ring: Sprite = $Ring
onready var _embers: CPUParticles2D = $Embers
onready var _flame_puffs: CPUParticles2D = $FlamePuffs
onready var _sparks: CPUParticles2D = $Sparks


func _ready() -> void:
    set_as_toplevel(true)
    visible = false
    set_process(false)


func play(pos: Vector2, main: Node, pool_id: int, scale_mult: float = 1.0, is_critical: bool = false) -> void:
    _main = main
    _pool_id = pool_id
    _elapsed = 0.0
    _active = true
    _opacity = FANTASY_PROJECTILE_VISUAL_UTILS.get_opacity()
    _flash_base_scale = 0.44 if is_critical else 0.33
    _ring_base_alpha = 0.9 if is_critical else 0.8
    global_position = pos
    scale = Vector2.ONE * max(0.2, scale_mult)
    visible = true
    set_process(true)

    _flash.visible = true
    _flash.scale = Vector2.ONE * _flash_base_scale
    _flash.rotation = rand_range(0.0, TAU)
    _flash.modulate = Color(1, 0.82, 0.34, _opacity) if not is_critical else Color(1, 0.96, 0.68, _opacity)

    _ring.visible = true
    _ring.scale = Vector2.ONE * 0.22
    _ring.modulate = Color(1, 0.78, 0.26) if is_critical else Color(1, 0.36, 0.05)
    _ring.modulate.a = _opacity * _ring_base_alpha

    _embers.emitting = true
    _embers.restart()
    _flame_puffs.amount = 8 if is_critical else 5
    _flame_puffs.emitting = true
    _flame_puffs.restart()
    _sparks.amount = 10 if is_critical else 6
    _sparks.emitting = true
    _sparks.restart()
    _embers.modulate.a = _opacity
    _flame_puffs.modulate.a = _opacity
    _sparks.modulate.a = _opacity


func _process(delta: float) -> void:
    if not _active:
        return
    _elapsed += delta
    if _elapsed >= DURATION:
        _finish()
        return

    var t: float = clamp(_elapsed / DURATION, 0.0, 1.0)
    var flash_progress: float = clamp(_elapsed / 0.13, 0.0, 1.0)
    var ring_progress: float = clamp(_elapsed / 0.21, 0.0, 1.0)

    _flash.scale = Vector2.ONE * (_flash_base_scale + 0.95 * (1.0 - pow(1.0 - flash_progress, 2.0)))
    _flash.rotation += delta * 4.0
    _flash.modulate.a = _opacity * (1.0 - flash_progress)
    _flash.visible = flash_progress < 1.0

    _ring.scale = Vector2.ONE * (0.22 + 0.95 * (1.0 - pow(1.0 - ring_progress, 2.0)))
    _ring.modulate.a = _opacity * _ring_base_alpha * (1.0 - ring_progress)
    _ring.visible = ring_progress < 1.0

    _embers.modulate.a = _opacity * (1.0 - t * 0.35)
    _flame_puffs.modulate.a = _opacity * (1.0 - t * 0.4)
    _sparks.modulate.a = _opacity * (1.0 - t * 0.3)


func _finish() -> void:
    _active = false
    _embers.emitting = false
    _flame_puffs.emitting = false
    _sparks.emitting = false
    var main: Node = _main
    _main = null
    FANTASY_PROJECTILE_VISUAL_UTILS.release_effect(self, main, _pool_id)
