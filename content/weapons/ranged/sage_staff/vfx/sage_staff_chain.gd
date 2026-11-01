extends "res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/shared/star_chain_attack.gd"

const ART = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const EFFECT = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const LINK_COUNT: int = EFFECT.CHAIN_COUNT

var _stats: RangedWeaponStats


func start(source, first_target: Enemy) -> void:
    _weapon = source._hitbox.from
    _main = source._main
    _stats = source._weapon_stats
    _hitbox.from = _weapon
    _hitbox.set_damage(source._hitbox.damage, Hitbox.HitboxArgs.new().set_from_weapon_stats(_stats))
    _hitbox.effect_scale = source._hitbox.effect_scale
    _hitbox.speed_percent_modifier = source._hitbox.speed_percent_modifier
    _hitbox.damage_tracking_key_hash = source._hitbox.damage_tracking_key_hash
    _hitbox.player_attack_id = source._hitbox.player_attack_id
    for effect in source._hitbox.effects:
        _hitbox.effects.append(effect.duplicate())
    _hitbox.projectiles_on_hit = source._hitbox.projectiles_on_hit.duplicate()
    _hitbox.ignored_objects = source._hitbox.ignored_objects.duplicate()
    _hitbox.ignored_objects.append(first_target)
    _hitbox.set_meta("fantasy_damage_color", ART.COLORS[EFFECT.Element.THUNDER])
    _hitbox.connect("hit_something", self, "_on_hit")
    WeaponService.fantasy_connect_hitbox_events(_hitbox, _weapon)
    var previous: Vector2 = first_target._hurtbox.global_position
    _points.append(previous)
    for _i in range(LINK_COUNT):
        var nearest: Enemy = null
        var distance_squared: float = float(_stats.max_range) * float(_stats.max_range)
        for enemy in source._target_index.candidates(_main, previous, _stats.max_range):
            if not _valid_target(enemy) or _targets.has(enemy) or _hitbox.ignored_objects.has(enemy):
                continue
            var distance: float = previous.distance_squared_to(enemy._hurtbox.global_position)
            if distance < distance_squared:
                nearest = enemy
                distance_squared = distance
        if nearest == null:
            break
        _targets.append(nearest)
        previous = nearest._hurtbox.global_position
        _points.append(previous)
    if _targets.empty():
        _finish_attack()
        return
    modulate.a = ProgressData.settings.explosion_opacity


func _physics_process(delta: float) -> void:
    if not _source_is_active():
        _finish_attack()
        return
    _age += delta
    _advance_chain()
    if is_queued_for_deletion():
        return
    if _age >= _get_chain_lifetime():
        _finish_attack()
        return
    update()


func _on_hit(target: Node, damage: int) -> void:
    _hitbox.ignored_objects.append(target)
    RunData.manage_life_steal(_stats, _weapon.player_index)
    _weapon.on_weapon_hit_something(target, damage, _hitbox)


func _draw() -> void:
    _draw_chain(_points)


func _hit_chain_target(target: Enemy, previous: Vector2) -> void:
    _hitbox.set_knockback(previous.direction_to(target._hurtbox.global_position), _stats.knockback, _stats.knockback_piercing)
    ._hit_chain_target(target, previous)
