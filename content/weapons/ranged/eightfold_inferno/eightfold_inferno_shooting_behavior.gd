extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"

const RECOVERY_DURATION: float = 0.6


func shoot(_distance: float) -> void:
    var weapon = _parent
    var weapon_stats = weapon.current_stats

    var projectile_count: int = max(1, int(weapon_stats.nb_projectiles))
    var origin: Vector2 = weapon.get_cast_origin()
    var base_angle: float = weapon.rotation

    if weapon_stats.shooting_sounds.size() > 0:
        SoundManager.play(Utils.get_rand_element(weapon_stats.shooting_sounds), weapon_stats.sound_db_mod, 0.16)

    weapon.set_shooting(true)
    var attack_id: int = _get_next_attack_id()

    _ranged_spawn_projectile_args.effects = weapon.effects
    _ranged_spawn_projectile_args.from_player_index = weapon.player_index
    _ranged_spawn_projectile_args.deferred = false

    for i in range(projectile_count):
        var angle: float = base_angle + TAU * float(i) / float(projectile_count)
        _ranged_spawn_projectile_args.knockback_direction = Vector2.RIGHT.rotated(angle)
        var projectile = WeaponService.spawn_projectile(origin, weapon_stats, angle, weapon, _ranged_spawn_projectile_args)
        projectile._hitbox.player_attack_id = attack_id
        projectile.configure_wave(i)
        emit_signal("projectile_shot", projectile)

    weapon.tween.interpolate_callback(weapon, RECOVERY_DURATION, "set_shooting", false)
    weapon.tween.start()
