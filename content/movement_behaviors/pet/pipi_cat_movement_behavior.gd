extends MovementBehavior

# Pipi Cat movement, self-contained: wander around the owner, hover with a
# state-driven rhythm and tremble while the cat winds up. The slowdown during
# charge, blow and cooldown also lives here, so the pet script only owns the
# state machine.

const WANDER_MIN_RADIUS: float = 90.0
const WANDER_ARRIVE_DISTANCE: float = 40.0
const WANDER_TURN_LIMIT: float = 2.4
const WANDER_CATCH_UP_MAX_FACTOR: float = 2.5
const WANDER_TIME_MIN: float = 2.5
const WANDER_TIME_MAX: float = 4.5

export(bool) var mirror_facing: bool = true
export(float) var zone_padding: float = 30.0
export(float) var facing_threshold: float = 4.0
export(float) var wander_radius: float = 240.0
export(float) var wander_acceleration: float = 260.0

export(float) var hover_height: float = 0.0
export(float) var hover_amplitude: float = 4.2
export(float) var hover_speed: float = 2.4
export(float) var hover_secondary_ratio: float = 0.285714
export(float) var hover_secondary_speed_ratio: float = 2.416667
export(float) var hover_secondary_phase: float = 0.0
export(float) var sway_distance: float = 0.0
export(float) var sway_angle: float = 0.0
export(float) var sway_speed: float = 0.0
export(float) var tilt_max: float = 0.35
export(float) var tilt_speed: float = 6.0
export(float) var shadow_min_scale: float = 0.8
export(float) var shadow_min_alpha: float = 0.65

export(NodePath) var hover_target_path: NodePath = NodePath("Animation/Offset")
export(NodePath) var tilt_target_path: NodePath = NodePath("Animation/Offset")
export(NodePath) var shadow_path: NodePath = NodePath("Animation/Offset/Shadow")

export(float) var charge_speed_factor: float = 0.4
export(float) var blow_speed_factor: float = 0.7
export(float) var cooldown_speed_factor: float = 0.55

export(float) var howl_shake_amplitude: float = 1.6
export(float) var howl_shake_speed: float = 34.0
export(float) var howl_hover_amplitude_factor: float = 1.2
export(float) var howl_hover_speed_factor: float = 1.35
export(float) var cooldown_hover_amplitude_factor: float = 0.6
export(float) var cooldown_hover_speed_factor: float = 0.8

var _velocity: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _initialized: bool = false

var _motion_time: float = 0.0
var _tilt: float = 0.0

var _hover_target: Node2D = null
var _tilt_target: Node2D = null
var _shadow: Sprite = null
var _shadow_ground_offset: Vector2 = Vector2.ZERO
var _shadow_base_scale: Vector2 = Vector2.ONE
var _hover_rest_position: Vector2 = Vector2.ZERO
var _body_rest_y: float = 0.0


func init(parent: Node) -> Node:
    .init(parent)
    _disable_hole_collision_response()

    _hover_target = _parent.get_node_or_null(hover_target_path) as Node2D
    _tilt_target = _parent.get_node_or_null(tilt_target_path) as Node2D
    if _tilt_target == null:
        _tilt_target = _hover_target
    assert(_hover_target != null, "PipiCatMovementBehavior needs a hover target node")
    _hover_rest_position = _hover_target.position

    _shadow = _parent.get_node_or_null(shadow_path) as Sprite
    if is_instance_valid(_shadow):
        _shadow_ground_offset = _shadow.global_position - _parent.global_position
        _shadow_base_scale = _shadow.global_scale.abs()

    _body_rest_y = _hover_target.global_position.y - _parent.global_position.y
    _wander_target = _parent.global_position
    _wander_angle = rand_range(-PI, PI)
    _initialized = true
    reset_motion()
    return self


func reset_motion() -> void:
    _velocity = Vector2.ZERO
    _tilt = 0.0
    _motion_time = rand_range(0.0, TAU)
    if is_instance_valid(_hover_target):
        _hover_target.position = _hover_rest_position
    if is_instance_valid(_tilt_target):
        _tilt_target.rotation = 0.0


func reset_wander() -> void:
    _wander_angle = rand_range(-PI, PI)
    _wander_timer = 0.0
    if is_instance_valid(_parent):
        _wander_target = _parent.global_position
    reset_motion()


func get_velocity() -> Vector2:
    return _velocity


func get_speed_ratio() -> float:
    return clamp(_velocity.length() / _get_reference_speed(), 0.0, 1.0)


func get_target_position():
    return _wander_target


func _physics_process(delta: float) -> void:
    if not _initialized or not is_instance_valid(_parent) or _parent.dead or _parent._end_of_wave:
        return

    var desired_velocity: Vector2 = _get_desired_velocity(delta)
    _velocity = _velocity.move_toward(desired_velocity, _get_acceleration() * delta)
    _parent.global_position += _velocity * delta
    _clamp_to_zone()

    if mirror_facing and abs(_velocity.x) >= facing_threshold:
        _parent.update_animation(Vector2(_velocity.x, 0.0))


func _process(delta: float) -> void:
    if not _initialized or not is_instance_valid(_parent) or _parent.dead or _parent._end_of_wave:
        return

    _motion_time += delta
    _update_hover(delta)


func _get_desired_velocity(delta: float) -> Vector2:
    var anchor: Vector2 = _get_anchor()
    var distance_to_anchor: float = _parent.global_position.distance_to(anchor)
    var speed_factor: float = _get_speed_factor()

    if distance_to_anchor > wander_radius:
        # Chase the nearest point of the wander ring so a running player never strands the pet.
        _wander_target = resolve_position_in_bounds(anchor + (_parent.global_position - anchor).normalized() * wander_radius)
        _wander_timer = 0.0
        speed_factor *= clamp(distance_to_anchor / wander_radius, 1.0, WANDER_CATCH_UP_MAX_FACTOR)
    else:
        _wander_timer -= delta
        if _wander_timer <= 0.0 or _parent.global_position.distance_squared_to(_wander_target) < WANDER_ARRIVE_DISTANCE * WANDER_ARRIVE_DISTANCE:
            _pick_wander_target()

    var cruise_speed: float = max(0.0, _get_wander_speed() * speed_factor)
    return _parent.global_position.direction_to(_wander_target) * cruise_speed


func _clamp_to_zone() -> void:
    var clamped_position: Vector2 = resolve_position_in_bounds(_parent.global_position)
    if clamped_position.x != _parent.global_position.x:
        _velocity.x = 0.0
    if clamped_position.y != _parent.global_position.y:
        _velocity.y = 0.0
    _parent.global_position = clamped_position


func resolve_position_in_bounds(pos: Vector2) -> Vector2:
    # Flying pets ignore forbidden zones; pits are handled by the collision
    # exceptions installed in init().
    return clamp_position_to_zone(pos)


func clamp_position_to_zone(pos: Vector2) -> Vector2:
    return Vector2(
        clamp(pos.x, ZoneService.current_zone_min_position.x + zone_padding, ZoneService.current_zone_max_position.x - zone_padding),
        clamp(pos.y, ZoneService.current_zone_min_position.y + zone_padding, ZoneService.current_zone_max_position.y - zone_padding)
    )


func _get_acceleration() -> float:
    return wander_acceleration


func _get_wander_speed() -> float:
    return _parent.get_move_speed()


func _get_reference_speed() -> float:
    return max(1.0, _get_wander_speed())


func _get_speed_factor() -> float:
    if _parent.is_charging():
        return charge_speed_factor
    if _parent.is_blowing():
        return blow_speed_factor
    if _parent.is_cooling_down():
        return cooldown_speed_factor
    return 1.0


func _pick_wander_target() -> void:
    _wander_angle += rand_range(-WANDER_TURN_LIMIT, WANDER_TURN_LIMIT)
    var offset: Vector2 = Vector2(cos(_wander_angle), sin(_wander_angle)) * rand_range(min(WANDER_MIN_RADIUS, wander_radius), wander_radius)
    _wander_target = resolve_position_in_bounds(_get_anchor() + offset)
    _wander_timer = rand_range(WANDER_TIME_MIN, WANDER_TIME_MAX)


func _get_anchor() -> Vector2:
    if _parent.player_index >= 0 and _parent.player_index < _parent.players_ref.size():
        var pet_owner: Player = _parent.players_ref[_parent.player_index]
        if is_instance_valid(pet_owner):
            return pet_owner.global_position
    return (ZoneService.current_zone_min_position + ZoneService.current_zone_max_position) * 0.5


func _update_hover(delta: float) -> void:
    var motion_factor: float = _get_hover_motion_factor()
    var hover_speed_value: float = _get_hover_speed()
    var primary_wave: float = sin(_motion_time * hover_speed_value)
    var secondary_wave: float = sin(_motion_time * hover_speed_value * hover_secondary_speed_ratio + hover_secondary_phase) * hover_secondary_ratio
    var sway: float = sin(_motion_time * sway_speed) * motion_factor
    var jitter: Vector2 = _get_hover_jitter()
    _hover_target.position = _hover_rest_position + Vector2(
        sway * sway_distance + jitter.x,
        -hover_height + (primary_wave + secondary_wave) * _get_hover_amplitude() * motion_factor + jitter.y
    )

    var target_tilt: float = _get_tilt_target()
    _tilt = lerp(_tilt, target_tilt, min(1.0, _get_tilt_lerp_speed() * delta))
    if is_instance_valid(_tilt_target):
        _tilt_target.rotation = _tilt + sway * sway_angle

    _update_shadow()


func _get_hover_motion_factor() -> float:
    if _is_howling():
        return howl_hover_amplitude_factor
    if _parent.is_cooling_down():
        return cooldown_hover_amplitude_factor
    return 1.0


func _get_hover_height() -> float:
    return hover_height


func _get_hover_amplitude() -> float:
    return hover_amplitude


func _get_hover_speed() -> float:
    if _is_howling():
        return hover_speed * howl_hover_speed_factor
    if _parent.is_cooling_down():
        return hover_speed * cooldown_hover_speed_factor
    return hover_speed


func _get_hover_jitter() -> Vector2:
    if not _is_howling():
        return Vector2.ZERO
    return Vector2(
        sin(_motion_time * howl_shake_speed),
        cos(_motion_time * howl_shake_speed * 1.37)
    ) * howl_shake_amplitude


func _is_howling() -> bool:
    return _parent.is_charging() or _parent.is_blowing()


func _update_shadow() -> void:
    if not is_instance_valid(_shadow):
        return

    var hover: float = _body_rest_y - (_hover_target.global_position.y - _parent.global_position.y)
    var hover_ratio: float = clamp(hover / max(1.0, hover_height + hover_amplitude * 1.2), 0.0, 1.0)
    var shadow_size: Vector2 = _shadow_base_scale * lerp(1.0, shadow_min_scale, hover_ratio)
    # Rebuild the world transform to cancel inherited animation, tilt and mirroring.
    _shadow.global_transform = Transform2D(
        Vector2(shadow_size.x, 0.0),
        Vector2(0.0, shadow_size.y),
        _parent.global_position + _shadow_ground_offset
    )
    _shadow.modulate.a = lerp(1.0, shadow_min_alpha, hover_ratio)


func _get_tilt_target() -> float:
    return clamp(_velocity.x / _get_reference_speed(), -1.0, 1.0) * tilt_max


func _get_tilt_lerp_speed() -> float:
    return tilt_speed


func _disable_hole_collision_response() -> void:
    var body: RigidBody2D = _parent as RigidBody2D
    if body == null:
        return
    var tree: SceneTree = body.get_tree()
    if tree == null:
        # init() normally runs after the pet joins the tree; retry on entry.
        if not body.is_connected("tree_entered", self, "_disable_hole_collision_response"):
            body.connect("tree_entered", self, "_disable_hole_collision_response", [], CONNECT_ONESHOT)
        return
    if not tree.is_connected("node_added", self, "_on_scene_tree_node_added"):
        tree.connect("node_added", self, "_on_scene_tree_node_added")
    _add_hole_exceptions(tree.root)


func _on_scene_tree_node_added(node: Node) -> void:
    # A composite pit scene attaches its holes as children before the container
    # enters the tree, so only the container emits this signal. Walk the added
    # subtree instead of checking the node alone.
    _add_hole_exceptions(node)


func _add_hole_exceptions(node: Node) -> void:
    if node is Hole:
        _add_hole_exception(node as PhysicsBody2D)
        return
    for child in node.get_children():
        _add_hole_exceptions(child)


func _add_hole_exception(hole: PhysicsBody2D) -> void:
    var body: RigidBody2D = _parent as RigidBody2D
    if body == null or hole == null:
        return
    body.add_collision_exception_with(hole)
