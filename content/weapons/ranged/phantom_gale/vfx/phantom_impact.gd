extends Node2D

const MAIN_HALO = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_thrust_impact.webp")
const ECHO_HALO = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_halo.webp")
const MAIN_SPARK = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_feather.webp")
const ECHO_SPARK = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_spark.webp")
const DURATION: float = 0.28

var _main: Node
var _elapsed: float = 0.0
var _is_echo: bool = false

onready var _halo: Sprite = $Halo
onready var _sparks: CPUParticles2D = $Sparks


func _ready() -> void:
    set_process(false)


func play(point: Vector2, angle: float, is_echo: bool, color: Color, main: Node) -> void:
    _main = main
    _elapsed = 0.0
    _is_echo = is_echo
    global_position = point
    rotation = angle
    visible = true
    modulate.a = ProgressData.settings.projectile_opacity
    _halo.texture = ECHO_HALO if is_echo else MAIN_HALO
    _halo.scale = Vector2(0.28, 0.18) if is_echo else Vector2(0.24, 0.33)
    _halo.modulate = color if is_echo else Color.white
    _sparks.texture = ECHO_SPARK if is_echo else MAIN_SPARK
    _sparks.color = color if is_echo else Color.white
    _sparks.amount = 7 if is_echo else 9
    _sparks.spread = 125.0 if is_echo else 110.0
    _sparks.initial_velocity = 160.0 if is_echo else 240.0
    _sparks.damping = 250.0 if is_echo else 480.0
    _sparks.angle_random = 0.0 if is_echo else 1.0
    _sparks.angular_velocity = 0.0 if is_echo else 60.0
    _sparks.angular_velocity_random = 0.0 if is_echo else 0.75
    _sparks.scale_amount = 0.55 if is_echo else 0.17
    _sparks.restart()
    _sparks.emitting = true
    set_process(true)


func _process(delta: float) -> void:
    _elapsed += delta
    var progress: float = min(_elapsed / DURATION, 1.0)
    modulate.a = ProgressData.settings.projectile_opacity
    _halo.scale = Vector2(0.28 + progress * 0.36, 0.18 + progress * 0.2) if _is_echo \
        else Vector2(0.24 + progress * 0.24, 0.33 + progress * 0.22)
    _halo.modulate.a = pow(max(0.0, 1.0 - _elapsed / 0.21), 2.0) if _is_echo else pow(1.0 - progress, 2.0)
    if progress >= 1.0 or _main._cleaning_up:
        _sparks.emitting = false
        visible = false
        set_process(false)
        _main.add_node_to_pool(self, get_meta("pool_id"))
