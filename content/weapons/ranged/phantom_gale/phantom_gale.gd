extends "res://weapons/ranged/ranged_weapon.gd"

const ECHO_STATS = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/phantom_gale/phantom_echo_stats.tres")

var _age: float = 0.0
var _release_age: float = 1.0
var _draw_cycle: float = 1.0
var _echo_count: int = 0
var _echo_args = WeaponServiceSpawnProjectileArgs.new()

onready var _draw_vfx: Node2D = $Sprite/DrawRig
onready var _spectral_edges: Sprite = $Sprite/SpectralEdges
onready var _hand_glow: Sprite = $Sprite/HandGlow
onready var _flash: Sprite = $Sprite/Flash


func _ready() -> void:
    for effect in effects:
        if effect.get_id() == "fantasy_phantom_gale":
            _echo_count = effect.value
            break
    assert(_echo_count > 0)
    _echo_args.from_player_index = player_index


func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    if at_wave_begin:
        _draw_cycle = max(1.0, _current_cooldown)


func shoot() -> void:
    _release_age = 0.0
    .shoot()
    _draw_cycle = max(1.0, _current_cooldown)


func _process(delta: float) -> void:
    _age += delta
    _release_age = min(1.0, _release_age + delta)
    var release_duration: float = clamp(_draw_cycle / 60.0 * 0.48, 0.045, 0.13)
    var flash: float = pow(max(0.0, 1.0 - _release_age / release_duration), 2.0)
    var draw_amount: float = smoothstep(0.08, 0.92, 1.0 - _current_cooldown / _draw_cycle)
    var opacity: float = ProgressData.settings.projectile_opacity
    _draw_vfx.refresh(delta, draw_amount, _release_age, flash, sprite.flip_v, opacity)
    _spectral_edges.flip_v = sprite.flip_v
    _hand_glow.flip_v = sprite.flip_v
    _spectral_edges.scale = Vector2.ONE * (1.01 + sin(_age * 3.8) * 0.012 + draw_amount * 0.018 + flash * 0.04)
    _spectral_edges.position.x = sin(_age * 2.7) * 0.8 - draw_amount * 2.5 - flash * 2.0
    _spectral_edges.modulate.a = opacity
    _spectral_edges.material.set_shader_param("release_flash", flash)
    _spectral_edges.material.set_shader_param("draw_strength", draw_amount)
    _hand_glow.modulate = Color(0.47, 0.87, 0.77, (0.1 + draw_amount * 0.13 + flash * 0.3) * opacity)
    _flash.position = muzzle.position
    _flash.scale = Vector2(0.25 + (1.0 - flash) * 0.13, 0.2 + (1.0 - flash) * 0.16)
    _flash.modulate = Color(1.0, 1.0, 1.0, flash * 0.8 * opacity)


func on_weapon_hit_something(thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void:
    .on_weapon_hit_something(thing_hit, damage_dealt, hitbox)
    if hitbox == null or not (thing_hit is Enemy):
        return
    var projectile = hitbox.get_parent()
    if projectile.has_method("configure_echo") and not projectile.is_echo:
        call_deferred("_release_phantoms", thing_hit, hitbox.player_attack_id)


func _release_phantoms(hit_enemy: Node, attack_id: int) -> void:
    var main = Utils.get_scene_node()
    if _parent.dead or _parent.cleaning_up or main._cleaning_up:
        return
    var echo_stats = WeaponService.init_ranged_stats(ECHO_STATS, player_index, true)
    echo_stats.burning_data.from = self
    var origin: Vector2 = _parent.global_position + Vector2(0, -18)
    for i in range(_echo_count):
        var angle: float = rotation + (i - (_echo_count - 1) / 2.0) * 0.65
        var projectile = WeaponService.spawn_projectile(origin, echo_stats, angle, self, _echo_args)
        projectile._hitbox.player_attack_id = attack_id
        projectile.configure_echo(i, hit_enemy)
        on_projectile_shot(projectile)
