extends Node

const DURATION: float = 0.6
const HEIGHT: float = 56.0
const SCALE_GAIN: float = 0.3
const STUN_PARTICLES = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/enemy_stun_particles.gd")

var _enemy: Node
var _active: bool = false
var _stunned: bool = false
var _stun_duration: float = 0.0
var _player_index: int = 0
var _impact_rate: float = 0.2
var _hit_targets: Dictionary = {}
var _motion_frame: int = -1
var _motion: Dictionary = {}
var _elapsed: float = 0.0
var _start: Vector2
var _end: Vector2
var _base_transform: Transform2D
var _launch_height: float = 0.0
var _height: float = 0.0
var _launch_rotation: float = 0.0
var _mode: int
var _body_disabled: bool
var _contact_disabled: bool
var _contact_active: bool
var _prevent_contact: bool
var _can_move: bool
var _move_locked: bool
var _nodes: Array = []
var _pooled_collisions: Array = []
var _stun_particles: Node2D = null


func _ready() -> void:
    set_physics_process(false)


func launch(enemy: Node, direction: Vector2, distance: float, player_index: int, stun_duration: float) -> void:
    _enemy = enemy
    if !_active and !_stunned:
        _impact_rate = 0.02 if _uses_script(enemy, "boss.gd") else 0.2
        _mode = enemy.mode
        _body_disabled = enemy._collision.disabled
        _contact_disabled = enemy._hitbox.is_disabled()
        _contact_active = enemy._hitbox.active
        _prevent_contact = enemy._prevent_contact_damage
        _can_move = enemy._can_move
        _move_locked = enemy._move_locked
        _interrupt_attacks()
        _base_transform = enemy._animation.transform
        _suspend(enemy)
    _active = true
    _stunned = false
    if _stun_particles != null:
        _stun_particles.hide()
    _player_index = player_index
    _stun_duration = stun_duration
    _hit_targets.clear()
    _motion_frame = -1
    _launch_height = _height
    _launch_rotation = enemy._animation.rotation - _base_transform.get_rotation()
    _elapsed = 0.0
    _start = enemy.global_position
    var target: Vector2 = _start + direction * distance
    _end = Vector2(clamp(target.x, enemy._min_pos.x, enemy._max_pos.x), clamp(target.y, enemy._min_pos.y, enemy._max_pos.y))
    enemy._can_move = false
    enemy._move_locked = true
    enemy._prevent_contact_damage = true
    enemy._hitbox.active = false
    enemy._hitbox.disable()
    enemy._collision.set_deferred("disabled", true)
    for saved in _nodes:
        if saved.has("body_disabled") and is_instance_valid(saved.node):
            saved.node.set_deferred("disabled", true)
    enemy.set_deferred("mode", RigidBody2D.MODE_STATIC)
    _clear_velocity()
    set_physics_process(true)


func _interrupt_attacks() -> void:
    var attack = _enemy._current_attack_behavior
    if _uses_script(attack, "jump_attack_behavior.gd") and (attack._is_jumping or attack._has_landed):
        _body_disabled = false
        _contact_disabled = false
        _prevent_contact = false
        _can_move = true
        _move_locked = false
    if _uses_script(attack, "charging_attack_behavior.gd") and (!attack._unlock_move_timer.is_stopped() or !attack._recovery_timer.is_stopped() or _enemy.is_playing_shoot_animation()):
        _can_move = true
        _move_locked = false
    if _uses_script(attack, "shooting_attack_behavior.gd") and attack.move_locked and (_enemy.is_playing_shoot_animation() or attack._recovery_cooldown > 0):
        _can_move = true
        _move_locked = false
    for behavior in _enemy._all_attack_behaviors:
        # A charge reset can emit move_unlocked and start a recovery timer.
        # Let those state transitions run, then stop the stale recovery.
        if _uses_script(behavior, "charging_attack_behavior.gd"):
            var charging = behavior
            charging.reset()
            charging._recovery_timer.stop()
            if behavior == attack:
                _enemy.bonus_speed = 0
                _enemy.mass = charging._original_mass
        elif _uses_script(behavior, "jump_attack_behavior.gd"):
            var jumping = behavior
            if jumping._is_jumping:
                var progress: float = clamp((jumping._jump_timer - jumping.jump_delay) / jumping.jump_duration, 0.0, 1.0)
                _enemy.global_position = jumping._start_position.linear_interpolate(jumping._target_position, progress)
            jumping.reset()
        elif _uses_script(behavior, "shooting_attack_behavior.gd"):
            var projectile_damage: int = behavior.projectile_damage
            behavior.reset()
            behavior.projectile_damage = projectile_damage
            behavior._recovery_cooldown = 0
        elif !_uses_script(behavior, "spawning_attack_behavior.gd") and !_uses_script(behavior, "detect_evolution_attack_behavior.gd"):
            # Preserve finite spawn budgets and the boss's current phase selection.
            behavior.reset()
    _enemy._animation_player.play("idle")
    _enemy._animation_player.advance(0.0)
    _enemy._animation_player.playback_speed = _enemy._idle_playback_speed


func _suspend(node: Node) -> void:
    # Keep damage/status processing and already emitted projectiles alive.
    if node == self or node == _stun_particles or node == _enemy.effect_behaviors or _uses_script(node, "projectile.gd"):
        return
    if node == _enemy._burning_timer or node == _enemy._flash_timer or node == _enemy._burning_particles:
        return
    var saved: Dictionary = {"node": node, "process": node.is_processing(), "physics": node.is_physics_processing()}
    if _uses_script(node, "hitbox.gd") and node != _enemy._hitbox:
        saved["contact_active"] = node.active
        saved["contact_disabled"] = node.is_disabled()
        node.active = false
        node.disable()
    if node is CollisionShape2D and node.get_parent() is RigidBody2D and node != _enemy._collision:
        saved["body_disabled"] = node.disabled
        node.set_deferred("disabled", true)
    if _uses_script(node, "shooting_attack_behavior.gd"):
        # Direct boss callbacks bypass process flags. Silence only this instance.
        saved["number_projectiles"] = node.number_projectiles
        node.number_projectiles = 0
        if _uses_script(node, "leaf_shooting_attack_behavior.gd"):
            saved["projectiles_per_time"] = node.projectiles_per_time
            node.projectiles_per_time = 0
    if node is Timer:
        saved["paused"] = node.paused
        node.paused = true
    if node is AnimationPlayer:
        saved["animation_active"] = node.is_active()
        if node != _enemy._animation_player:
            node.stop(false)
        node.set_active(false)
    _nodes.append(saved)
    node.set_process(false)
    node.set_physics_process(false)
    for child in node.get_children():
        _suspend(child)


func _physics_process(delta: float) -> void:
    if _enemy.dead or _enemy._pending_die:
        return
    var scaled_delta: float = delta * _enemy.get_time_factor()
    if _stunned:
        _elapsed += scaled_delta
        _stun_particles.advance(scaled_delta)
        _clear_velocity()
        if _elapsed >= _stun_duration:
            finish(true)
        return
    var motion: Dictionary = sample_motion(delta)
    _elapsed += scaled_delta
    var t: float = min(_elapsed / DURATION, 1.0)
    var height: float = 4.0 * t * (1.0 - t)
    _enemy.global_position = motion.to
    # Reuse one bounded height envelope, including when relaunched at the apex.
    _height = lerp(_launch_height * (1.0 - t), 1.0, height)
    var pose: Transform2D = _base_transform.scaled(Vector2.ONE * (1.0 + SCALE_GAIN * _height))
    pose = pose.rotated(_launch_rotation * (1.0 - t) + TAU * t)
    pose.origin = _base_transform.origin + Vector2.UP * HEIGHT * _height
    _enemy._animation.transform = pose
    _clear_velocity()
    _damage_collisions(motion, delta)
    if !_active or _enemy.dead or _enemy._pending_die:
        return
    if t >= 1.0:
        _land()


# Every controller shares the same frame sample, regardless of update order.
func sample_motion(delta: float) -> Dictionary:
    var frame: int = Engine.get_physics_frames()
    if _motion_frame == frame:
        return _motion
    var from: Vector2 = _enemy.global_position
    var to: Vector2 = from
    if _active:
        var t: float = min((_elapsed + delta * _enemy.get_time_factor()) / DURATION, 1.0)
        to = _start.linear_interpolate(_end, 1.0 - pow(1.0 - t, 2.0))
    _motion = {"from": from, "to": to}
    _motion_frame = frame
    return _motion


func _damage_collisions(motion: Dictionary, delta: float) -> void:
    var source: CollisionShape2D = _enemy._hurtbox._collision
    if source.disabled:
        return
    var source_transform: Transform2D = source.global_transform
    source_transform.origin += motion.from - _enemy.global_position
    var source_motion: Vector2 = motion.to - motion.from
    var source_bounds: Rect2 = _swept_bounds(source.shape, source_transform, source_motion)
    for target in _enemy._entity_spawner_ref.get_all_enemies(false).duplicate():
        if target == _enemy or !is_instance_valid(target) or target.dead or target._pending_die:
            continue
        var id: int = target.get_instance_id()
        if _hit_targets.has(id) or target._hurtbox.is_disabled():
            continue
        var target_shape: CollisionShape2D = target._hurtbox._collision
        var target_transform: Transform2D = target_shape.global_transform
        var target_motion: Vector2 = Vector2.ZERO
        var controller: Node = target._fantasy_airborne_controller
        if controller != null:
            var other: Dictionary = controller.sample_motion(delta)
            target_transform.origin += other.from - target.global_position
            target_motion = other.to - other.from
        var target_bounds: Rect2 = _swept_bounds(target_shape.shape, target_transform, target_motion)
        if !source_bounds.intersects(target_bounds, true):
            continue
        if source.shape.collide_with_motion(source_transform, source_motion, target_shape.shape, target_transform, target_motion):
            _hit_targets[id] = true
            var damage: int = max(1, int(round(_enemy.current_stats.health * _impact_rate)))
            target.fa_take_airborne_impact(damage, _player_index, _enemy)
            if !_active or _enemy.dead or _enemy._pending_die:
                return


func _swept_bounds(shape: Shape2D, transform: Transform2D, motion: Vector2) -> Rect2:
    var extents: Vector2
    if shape is RectangleShape2D:
        extents = shape.extents
    elif shape is CapsuleShape2D:
        extents = Vector2(shape.radius, shape.height * 0.5 + shape.radius)
    else:
        # Enemy hurtboxes use circles; Godot 3 has no Shape2D.get_rect().
        assert(shape is CircleShape2D, "Unsupported enemy hurtbox shape")
        extents = Vector2.ONE * shape.radius
    var bounds: Rect2 = transform.xform(Rect2(-extents, extents * 2.0))
    return bounds.merge(Rect2(bounds.position + motion, bounds.size))


func _land() -> void:
    _active = false
    _stunned = true
    _height = 0.0
    _elapsed = 0.0
    _hit_targets.clear()
    _enemy._animation.transform = _base_transform
    _enemy._collision.set_deferred("disabled", _body_disabled)
    for saved in _nodes:
        if saved.has("body_disabled") and is_instance_valid(saved.node):
            saved.node.set_deferred("disabled", saved.body_disabled)
    if _stun_duration <= 0.0:
        finish(true)
    else:
        if _stun_particles == null:
            _stun_particles = STUN_PARTICLES.new()
            _enemy.add_child(_stun_particles)
        _stun_particles.start(_enemy.sprite, _enemy)


func _clear_velocity() -> void:
    _enemy.knockback_vector = Vector2.ZERO
    _enemy._current_movement = Vector2.ZERO
    _enemy._last_move_input = Vector2.ZERO
    _enemy._last_knockback_value = Vector2.ZERO
    _enemy._integrate_forces_velocity = Vector2.ZERO
    _enemy.linear_velocity = Vector2.ZERO
    _enemy.angular_velocity = 0.0


func finish(landed: bool) -> void:
    if !_active and !_stunned:
        return
    _active = false
    _stunned = false
    if _stun_particles != null:
        _stun_particles.hide()
    _hit_targets.clear()
    _height = 0.0
    set_physics_process(false)
    _enemy._animation.transform = _base_transform
    _clear_velocity()
    _enemy.set_deferred("mode", _mode)
    for saved in _nodes:
        var node: Node = saved.node
        if !is_instance_valid(node):
            continue
        if saved.has("contact_active"):
            node.active = saved.contact_active if landed else false
            node.get_node("Collision").set_deferred("disabled", saved.contact_disabled if landed else true)
        if saved.has("body_disabled"):
            node.set_deferred("disabled", saved.body_disabled if landed else true)
        if !landed and (saved.has("contact_active") or saved.has("body_disabled")):
            _pooled_collisions.append(saved)
        if saved.has("number_projectiles"):
            node.number_projectiles = saved.number_projectiles
            node._shots_taken = 0
        if saved.has("projectiles_per_time"):
            node.projectiles_per_time = saved.projectiles_per_time
        node.set_process(saved.process)
        node.set_physics_process(saved.physics)
        if node is Timer:
            node.paused = saved.paused
        if node is AnimationPlayer:
            node.set_active(saved.animation_active)
    _nodes.clear()
    _enemy._prevent_contact_damage = _prevent_contact
    _enemy._can_move = _can_move
    _enemy._move_locked = _move_locked
    _enemy._hitbox.active = _contact_active if landed else false
    if landed:
        _enemy._collision.set_deferred("disabled", _body_disabled)
        var disable_contact: bool = _contact_disabled if _prevent_contact else false
        _enemy._hitbox.get_node("Collision").set_deferred("disabled", disable_contact)


func restore_pooled_collisions() -> void:
    for saved in _pooled_collisions:
        var node: Node = saved.node
        if !is_instance_valid(node):
            continue
        if saved.has("contact_active"):
            node.active = saved.contact_active
            node.get_node("Collision").set_deferred("disabled", saved.contact_disabled)
        if saved.has("body_disabled"):
            node.set_deferred("disabled", saved.body_disabled)
    _pooled_collisions.clear()


# Avoid preloading Enemy's subclasses while ModLoader is extending Enemy.
func _uses_script(node: Node, filename: String) -> bool:
    var script: Script = node.get_script()
    while script != null:
        if script.resource_path.ends_with("/" + filename):
            return true
        script = script.get_base_script()
    return false
