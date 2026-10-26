extends Node2D

const FANTASY_PROJECTILE_VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")

const DURATION: float = 0.78

var _elapsed: float = 0.0
var _main: Node = null
var _pool_id: int = -1
var _opacity: float = 1.0
var _active: bool = false
var _rune_angle: float = 0.0
var _rune_scale: Vector2 = Vector2.ONE
var _rune_inner_scale: Vector2 = Vector2.ONE
var _ground_glow_scale: Vector2 = Vector2.ONE

onready var _ground_layer: Node2D = $GroundLayer
onready var _rune: Sprite = $GroundLayer/Rune
onready var _rune_inner: Sprite = $GroundLayer/RuneInner
onready var _ground_glow: Sprite = $GroundLayer/GroundGlow
onready var _flash: Sprite = $Flash
onready var _shockwave: Sprite = $Shockwave
onready var _inner_ring: Sprite = $InnerRing
onready var _core_glow: Sprite = $CoreGlow
onready var _embers: CPUParticles2D = $Embers
onready var _flame_puffs: CPUParticles2D = $FlamePuffs
onready var _sparks: CPUParticles2D = $Sparks
onready var _smoke: CPUParticles2D = $Smoke


func _ready() -> void:
    _rune_scale = _rune.scale
    _rune_inner_scale = _rune_inner.scale
    _ground_glow_scale = _ground_glow.scale
    set_as_toplevel(true)
    visible = false
    set_process(false)


func play(pos: Vector2, main: Node, pool_id: int) -> void:
    _main = main
    _pool_id = pool_id
    _elapsed = 0.0
    _active = true
    _opacity = FANTASY_PROJECTILE_VISUAL_UTILS.get_opacity()
    global_position = pos
    _rune_angle = rand_range(0.0, TAU)
    visible = true
    set_process(true)
    _reset_visuals()


func _reset_visuals() -> void:
    _rune.scale = _rune_scale * 0.32
    _rune.rotation = 0.0
    _rune.modulate = Color(1, 0.78, 0.38, _opacity * 0.95)
    _rune.material.set_shader_param("strength", 1.0)
    _rune.material.set_shader_param("energy", 1.0)
    _rune.material.set_shader_param("spin", _rune_angle)
    _rune.material.set_shader_param("seed", 3.0)
    _rune_inner.scale = _rune_inner_scale * 0.45
    _rune_inner.rotation = 0.0
    _rune_inner.modulate = Color(1, 0.48, 0.14, _opacity * 0.75)
    _rune_inner.material.set_shader_param("strength", 0.9)
    _rune_inner.material.set_shader_param("energy", 1.0)
    _rune_inner.material.set_shader_param("spin", -_rune_angle)
    _rune_inner.material.set_shader_param("seed", 9.0)
    _ground_glow.scale = _ground_glow_scale * 0.7
    _ground_glow.modulate = Color(1, 0.30, 0.05, _opacity * 0.45)

    _ground_layer.visible = true
    _ground_layer.modulate = Color(1, 1, 1, 1)

    _flash.scale = Vector2.ONE * 0.39
    _flash.rotation = rand_range(0.0, TAU)
    _flash.modulate = Color(1, 0.92, 0.62, _opacity)
    _flash.visible = true

    _shockwave.scale = Vector2.ONE * 0.3
    _shockwave.modulate = Color(1, 0.42, 0.06, _opacity * 0.9)
    _shockwave.visible = true

    _inner_ring.scale = Vector2.ONE * 0.22
    _inner_ring.modulate = Color(1, 0.76, 0.24, _opacity * 0.8)
    _inner_ring.visible = true

    _core_glow.scale = Vector2.ONE * 0.92
    _core_glow.modulate = Color(1, 0.44, 0.08, _opacity * 0.85)
    _core_glow.visible = true

    _embers.modulate.a = _opacity
    _flame_puffs.modulate.a = _opacity
    _sparks.modulate.a = _opacity
    _smoke.modulate.a = _opacity

    _embers.emitting = true
    _embers.restart()
    _flame_puffs.emitting = true
    _flame_puffs.restart()
    _sparks.emitting = true
    _sparks.restart()
    _smoke.emitting = true
    _smoke.restart()


func _process(delta: float) -> void:
    if not _active:
        return
    _elapsed += delta
    if _elapsed >= DURATION:
        _finish()
        return
    var t: float = clamp(_elapsed / DURATION, 0.0, 1.0)

    var reveal: float = clamp(_elapsed / 0.16, 0.0, 1.0)
    var reveal_ease: float = 1.0 - pow(1.0 - reveal, 3.0)
    var ground_fade: float = 1.0 - smoothstep(0.42, 1.0, t)

    _rune.scale = _rune_scale * (0.32 + 0.78 * reveal_ease)
    _rune.material.set_shader_param("spin", _rune_angle + _elapsed * 0.55)
    _rune.modulate = Color(1, 0.78, 0.38, _opacity * ground_fade * 0.95)
    _rune_inner.scale = _rune_inner_scale * (0.45 + 0.55 * reveal_ease)
    _rune_inner.material.set_shader_param("spin", -_rune_angle - _elapsed * 1.15)
    _rune_inner.modulate = Color(1, 0.48, 0.14, _opacity * ground_fade * 0.75)
    _ground_glow.scale = _ground_glow_scale * (0.7 + 0.35 * reveal_ease)
    _ground_glow.modulate = Color(1, 0.30, 0.05, _opacity * ground_fade * (0.45 + 0.15 * sin(_elapsed * 18.0)))

    var flash_progress: float = clamp(_elapsed / 0.16, 0.0, 1.0)
    _flash.scale = Vector2.ONE * (0.39 + 1.2 * (1.0 - pow(1.0 - flash_progress, 2.0)))
    _flash.rotation += delta * 2.4
    _flash.modulate = Color(1, 0.92, 0.62, _opacity * (1.0 - flash_progress))
    _flash.visible = flash_progress < 1.0

    var wave_progress: float = clamp(_elapsed / 0.48, 0.0, 1.0)
    _shockwave.scale = Vector2.ONE * (0.3 + 1.75 * (1.0 - pow(1.0 - wave_progress, 2.0)))
    _shockwave.modulate = Color(1, 0.42, 0.06, _opacity * 0.9 * (1.0 - wave_progress))
    _shockwave.visible = wave_progress < 1.0

    var inner_progress: float = clamp(_elapsed / 0.32, 0.0, 1.0)
    _inner_ring.scale = Vector2.ONE * (0.22 + 1.05 * (1.0 - pow(1.0 - inner_progress, 2.0)))
    _inner_ring.modulate = Color(1, 0.76, 0.24, _opacity * 0.8 * (1.0 - inner_progress))
    _inner_ring.visible = inner_progress < 1.0

    var glow_progress: float = clamp(_elapsed / 0.34, 0.0, 1.0)
    _core_glow.scale = Vector2.ONE * (0.92 + 1.0 * glow_progress)
    _core_glow.modulate = Color(1, 0.44, 0.08, _opacity * 0.85 * (1.0 - glow_progress))
    _core_glow.visible = glow_progress < 1.0


func _finish() -> void:
    _active = false
    _embers.emitting = false
    _flame_puffs.emitting = false
    _sparks.emitting = false
    _smoke.emitting = false
    var main: Node = _main
    _main = null
    FANTASY_PROJECTILE_VISUAL_UTILS.release_effect(self, main, _pool_id)
