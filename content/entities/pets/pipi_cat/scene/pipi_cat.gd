extends "res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/howling_pet.gd"

const ANGRY_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_angry.wav")
const PURRING_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_purring.wav")
const EXIT_DISSOLVE_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/scene/pipi_cat_exit_dissolve.shader")

# The cat leaves through a four-point star iris. The corners of the sprite are
# clipped first, then the remaining diamond star shrinks into the center so the
# pet never pops out of existence between waves.
export(float) var exit_dissolve_duration: float = 0.9
export(float) var exit_star_sharpness: float = 0.62
export(float) var exit_edge_softness: float = 0.012
export(float) var exit_edge_width: float = 0.06
export(Color) var exit_edge_color: Color = Color(1.0, 1.0, 1.0, 0.85)
export(float) var exit_shadow_fade_ratio: float = 0.7

onready var _exit_shadow: Sprite = $"Animation/Offset/Shadow"

var _exit_material: ShaderMaterial = null
var _exit_sprites: Array = []
var _exit_base_materials: Dictionary = {}
var _exit_elapsed: float = 0.0
var _exit_shadow_alpha: float = 1.0
var _exit_dissolving: bool = false
var _exit_waiting_for_animation: bool = false
var _exit_released: bool = false


func _process(delta: float) -> void:
    if not _exit_dissolving:
        return

    _exit_elapsed += delta
    var duration: float = max(0.05, exit_dissolve_duration)
    var ratio: float = clamp(_exit_elapsed / duration, 0.0, 1.0)
    var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
    _apply_exit_progress(eased)
    _fade_exit_shadow(eased)

    if ratio >= 1.0:
        _finish_exit_dissolve()


func die(args = DieArgs.new()) -> void:
    .die(args)
    _start_exit_dissolve()


func death_animation_finished() -> void:
    if _exit_released:
        return
    if _exit_dissolving:
        _exit_waiting_for_animation = true
        return
    _exit_released = true
    .death_animation_finished()


func respawn() -> void:
    .respawn()
    _reset_exit_dissolve()


func _play_idle_voice() -> void:
    _play_voice(PURRING_SOUND, -12.0)


func _play_attack_voice() -> void:
    _play_voice(ANGRY_SOUND, -6.5)


func _start_exit_dissolve() -> void:
    if _exit_dissolving or _exit_released:
        return

    _exit_dissolving = true
    _exit_elapsed = 0.0
    _prepare_exit_material()
    _apply_exit_progress(0.0)
    if is_instance_valid(_exit_shadow):
        _exit_shadow_alpha = _exit_shadow.modulate.a


func _prepare_exit_material() -> void:
    if _exit_material == null:
        _exit_material = ShaderMaterial.new()
        _exit_material.shader = EXIT_DISSOLVE_SHADER

    _exit_material.set_shader_param("star_sharpness", exit_star_sharpness)
    _exit_material.set_shader_param("edge_softness", exit_edge_softness)
    _exit_material.set_shader_param("edge_width", exit_edge_width)
    _exit_material.set_shader_param("edge_color", exit_edge_color)

    if _exit_sprites.empty():
        _exit_sprites = [_normal, _angry, _tired]

    _exit_base_materials.clear()
    for sprite in _exit_sprites:
        _exit_base_materials[sprite] = sprite.material
        sprite.material = _exit_material


func _apply_exit_progress(value: float) -> void:
    if _exit_material != null:
        _exit_material.set_shader_param("progress", clamp(value, 0.0, 1.0))


func _fade_exit_shadow(eased: float) -> void:
    if not is_instance_valid(_exit_shadow):
        return
    var fade_ratio: float = clamp(eased / max(0.01, exit_shadow_fade_ratio), 0.0, 1.0)
    _exit_shadow.modulate.a = _exit_shadow_alpha * (1.0 - fade_ratio)


func _finish_exit_dissolve() -> void:
    _exit_dissolving = false
    _apply_exit_progress(1.0)
    for sprite in _exit_sprites:
        sprite.visible = false
    if is_instance_valid(_exit_shadow):
        _exit_shadow.visible = false

    if _exit_waiting_for_animation:
        _exit_waiting_for_animation = false
        _exit_released = true
        .death_animation_finished()


func _reset_exit_dissolve() -> void:
    _exit_dissolving = false
    _exit_waiting_for_animation = false
    _exit_released = false
    _exit_elapsed = 0.0
    _apply_exit_progress(0.0)

    for sprite in _exit_sprites:
        if _exit_base_materials.has(sprite):
            sprite.material = _exit_base_materials[sprite]
    _exit_base_materials.clear()

    if is_instance_valid(_exit_shadow):
        _exit_shadow.visible = true
        _exit_shadow.modulate.a = 1.0
