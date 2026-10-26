extends "res://weapons/ranged/ranged_weapon.gd"

const EXPLOSION_SCENE = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/annihilation_ray/vfx/annihilation_impact.tscn")

var _clock: float = 0.0
var _release_age: float = 1.0
var _cycle_cooldown: float = 1.0
var _blast_stats: MeleeWeaponStats
var _blast_effect = ExplodingEffect.new()

onready var _panel: Sprite = $Sprite/Panel
onready var _reactor: Sprite = $Sprite/Reactor
onready var _charge: Node2D = $Sprite/Charge


func _ready() -> void:
    _charge.position = muzzle.position
    for effect in effects:
        if effect.get_id() == "fantasy_annihilation_ray":
            _blast_stats = effect.get_explosion_stats()
            break
    assert(_blast_stats != null)
    _blast_effect.explosion_scene = EXPLOSION_SCENE
    _blast_effect.scale = 1.0
    _blast_effect.base_smoke_amount = 1
    _blast_effect.sound_db_mod = -24
    _clock = rand_range(0.0, TAU)


func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    if at_wave_begin:
        _cycle_cooldown = max(1.0, _current_cooldown)


func shoot() -> void:
    _release_age = 0.0
    .shoot()
    _cycle_cooldown = max(1.0, _current_cooldown)


func _process(delta: float) -> void:
    _clock += delta
    _release_age = min(1.0, _release_age + delta)
    var charge: float = clamp(1.0 - _current_cooldown / _cycle_cooldown, 0.0, 1.0)
    if _is_shooting or _parent.cleaning_up or _parent.dead:
        charge = 0.0
    var flash: float = pow(max(0.0, 1.0 - _release_age / 0.24), 2.0)
    var opacity: float = ProgressData.settings.projectile_opacity
    _panel.modulate = Color(0.78 + flash * 0.22, 0.55 + charge * 0.4, 1.0, 0.5 + charge * 0.5)
    _reactor.modulate = Color(0.65, 0.42, 1.0, (0.07 + charge * 0.21 + flash * 0.32) * opacity)
    _reactor.position = Vector2(sin(_clock * 23.0), cos(_clock * 31.0)) * charge * 0.8
    _charge.refresh(delta, charge, flash, opacity)


func update_sprite_flipv() -> void:
    .update_sprite_flipv()
    _panel.flip_v = sprite.flip_v
    _reactor.flip_v = sprite.flip_v


func detonate_ray(pos: Vector2, source_hitbox: Hitbox) -> void:
    if _parent.cleaning_up or _parent.dead:
        return
    var args = WeaponService.fantasy_explosion_args_from_hitbox(source_hitbox, player_index)
    args.pos = pos
    args.damage = WeaponService.get_explosion_damage(_blast_stats, player_index)
    args.scaling_stats = _blast_stats.scaling_stats
    WeaponService.fantasy_spawn_weapon_explosion(_blast_effect, args, self, source_hitbox.player_attack_id)
