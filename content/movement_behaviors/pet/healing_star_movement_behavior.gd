extends MovementBehavior

# Healing Star movement, self-contained: wander around the owner, then dash
# toward a nearby consumable. The star keeps every movement detail in this one
# script, so nothing here depends on a shared floating/howling chain.

enum State { WANDER, SEEK_CONSUMABLE }

const WANDER_MIN_RADIUS: float = 90.0
const WANDER_ARRIVE_DISTANCE: float = 40.0
const WANDER_TURN_LIMIT: float = 2.4
const WANDER_CATCH_UP_MAX_FACTOR: float = 2.5
const WANDER_TIME_MIN: float = 2.5
const WANDER_TIME_MAX: float = 4.5

const HOVER_AMPLITUDE: float = 4.2
const HOVER_SPEED: float = 2.4
const HOVER_SECONDARY_RATIO: float = 0.285714
const HOVER_SECONDARY_SPEED_RATIO: float = 2.416667
const TILT_MAX: float = 0.35
const TILT_LERP_SPEED: float = 4.0
const SEEK_TILT_LERP_SPEED: float = 6.0
const SHADOW_MIN_SCALE: float = 0.8
const SHADOW_MIN_ALPHA: float = 0.65

export(bool) var mirror_facing: bool = false
export(float) var zone_padding: float = 30.0
export(float) var facing_threshold: float = 4.0
export(float) var wander_radius: float = 240.0
export(float) var wander_speed: float = 160.0
export(float) var wander_acceleration: float = 750.0
export(float) var seek_speed: float = 640.0
export(float) var seek_acceleration: float = 1500.0

export(NodePath) var hover_target_path: NodePath = NodePath("Animation")
export(NodePath) var tilt_target_path: NodePath = NodePath("Animation/Offset")
export(NodePath) var shadow_path: NodePath = NodePath("Animation/Offset/Shadow")

var _velocity: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _initialized: bool = false

var _state: int = State.WANDER
var _consumable_target = null
var _current_spin_speed: float = 1.0

var _body_sprite: Sprite = null
var _trail_particles: CPUParticles2D = null

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
    assert(_hover_target != null, "HealingStarMovementBehavior needs a hover target node")
    _hover_rest_position = _hover_target.position

    _shadow = _parent.get_node_or_null(shadow_path) as Sprite
    if is_instance_valid(_shadow):
        _shadow_ground_offset = _shadow.global_position - _parent.global_position
        _shadow_base_scale = _shadow.global_scale.abs()

    _body_rest_y = _hover_target.global_position.y - _parent.global_position.y
    _body_sprite = _parent.get_node_or_null("Animation/Offset/Body") as Sprite
    _trail_particles = _parent.get_node_or_null("Animation/TrailParticles") as CPUParticles2D

    _wander_target = _parent.global_position
    _wander_angle = rand_range(-PI, PI)
    _initialized = true
    reset_motion()
    return self


func reset_state() -> void:
    _state = State.WANDER
    _consumable_target = null
    _current_spin_speed = 1.0
    if is_instance_valid(_body_sprite):
        _body_sprite.rotation = 0.0
    if is_instance_valid(_trail_particles):
        _trail_particles.emitting = false
    reset_wander()


func reset_wander() -> void:
    _wander_angle = rand_range(-PI, PI)
    _wander_timer = 0.0
    if is_instance_valid(_parent):
        _wander_target = _parent.global_position
    reset_motion()


func reset_motion() -> void:
    _velocity = Vector2.ZERO
    _tilt = 0.0
    _motion_time = rand_range(0.0, TAU)
    if is_instance_valid(_hover_target):
        _hover_target.position = _hover_rest_position
    if is_instance_valid(_tilt_target):
        _tilt_target.rotation = 0.0


func set_consumable_target(target) -> void:
    _consumable_target = target
    _state = State.SEEK_CONSUMABLE


func clear_consumable_target() -> void:
    _consumable_target = null
    _state = State.WANDER
    _pick_wander_target()


func get_consumable_target():
    return _consumable_target


func is_seeking() -> bool:
    return _state == State.SEEK_CONSUMABLE


func get_velocity() -> Vector2:
    return _velocity


func get_speed_ratio() -> float:
    return clamp(_velocity.length() / max(1.0, seek_speed), 0.0, 1.0)


func get_target_position():
    if is_seeking() and is_instance_valid(_consumable_target):
        return _consumable_target.global_position
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
    if is_seeking():
        if not is_instance_valid(_consumable_target):
            return Vector2.ZERO
        return _parent.global_position.direction_to(_consumable_target.global_position) * seek_speed

    var anchor: Vector2 = _get_anchor()
    var distance_to_anchor: float = _parent.global_position.distance_to(anchor)
    var speed_factor: float = 1.0

    if distance_to_anchor > wander_radius:
        # Chase the nearest point of the wander ring so a running player never strands the pet.
        _wander_target = resolve_position_in_bounds(anchor + (_parent.global_position - anchor).normalized() * wander_radius)
        _wander_timer = 0.0
        speed_factor = clamp(distance_to_anchor / wander_radius, 1.0, WANDER_CATCH_UP_MAX_FACTOR)
    else:
        _wander_timer -= delta
        if _wander_timer <= 0.0 or _parent.global_position.distance_squared_to(_wander_target) < WANDER_ARRIVE_DISTANCE * WANDER_ARRIVE_DISTANCE:
            _pick_wander_target()

    return _parent.global_position.direction_to(_wander_target) * (wander_speed * speed_factor)


func _get_acceleration() -> float:
    return seek_acceleration if is_seeking() else wander_acceleration


func _clamp_to_zone() -> void:
    var clamped_position: Vector2 = resolve_position_in_bounds(_parent.global_position)
    if clamped_position.x != _parent.global_position.x:
        _velocity.x = 0.0
    if clamped_position.y != _parent.global_position.y:
        _velocity.y = 0.0
    _parent.global_position = clamped_position


func resolve_position_in_bounds(pos: Vector2) -> Vector2:
    return clamp_position_to_zone(pos)


func clamp_position_to_zone(pos: Vector2) -> Vector2:
    return Vector2(
        clamp(pos.x, ZoneService.current_zone_min_position.x + zone_padding, ZoneService.current_zone_max_position.x - zone_padding),
        clamp(pos.y, ZoneService.current_zone_min_position.y + zone_padding, ZoneService.current_zone_max_position.y - zone_padding)
    )


func _pick_wander_target() -> void:
    _wander_angle += rand_range(-WANDER_TURN_LIMIT, WANDER_TURN_LIMIT)
    var target: Vector2 = _get_anchor() \
        + Vector2(cos(_wander_angle), sin(_wander_angle)) * rand_range(min(WANDER_MIN_RADIUS, wander_radius), wander_radius)
    _wander_target = resolve_position_in_bounds(target)
    _wander_timer = rand_range(WANDER_TIME_MIN, WANDER_TIME_MAX)


func _get_anchor() -> Vector2:
    if _parent.player_index >= 0 and _parent.player_index < _parent.players_ref.size():
        var pet_owner: Player = _parent.players_ref[_parent.player_index]
        if is_instance_valid(pet_owner):
            return pet_owner.global_position
    return (ZoneService.current_zone_min_position + ZoneService.current_zone_max_position) * 0.5


func _update_hover(delta: float) -> void:
    var vertical_wave: float = sin(_motion_time * HOVER_SPEED) \
        + sin(_motion_time * HOVER_SPEED * HOVER_SECONDARY_SPEED_RATIO) * HOVER_SECONDARY_RATIO
    _hover_target.position = _hover_rest_position + Vector2(0.0, vertical_wave * HOVER_AMPLITUDE)

    var target_tilt: float = _get_tilt_target()
    var tilt_lerp_speed: float = SEEK_TILT_LERP_SPEED if is_seeking() else TILT_LERP_SPEED
    _tilt = lerp(_tilt, target_tilt, min(1.0, tilt_lerp_speed * delta))
    if is_instance_valid(_tilt_target):
        _tilt_target.rotation = _tilt

    _update_shadow()
    _update_extra_visuals(delta)


func _get_tilt_target() -> float:
    if not is_seeking():
        return 0.0
    return clamp(_velocity.x / max(1.0, seek_speed), -1.0, 1.0) * TILT_MAX


func _update_shadow() -> void:
    if not is_instance_valid(_shadow):
        return

    var hover: float = _body_rest_y - (_hover_target.global_position.y - _parent.global_position.y)
    var hover_ratio: float = clamp(hover / max(1.0, HOVER_AMPLITUDE * 1.2), 0.0, 1.0)
    var shadow_size: Vector2 = _shadow_base_scale * lerp(1.0, SHADOW_MIN_SCALE, hover_ratio)
    # Rebuild the world transform to cancel inherited animation, tilt and mirroring.
    _shadow.global_transform = Transform2D(
        Vector2(shadow_size.x, 0.0),
        Vector2(0.0, shadow_size.y),
        _parent.global_position + _shadow_ground_offset
    )
    _shadow.modulate.a = lerp(1.0, SHADOW_MIN_ALPHA, hover_ratio)


func _update_extra_visuals(delta: float) -> void:
    if is_instance_valid(_body_sprite):
        var target_spin_speed: float = 1.0 + get_speed_ratio() * 3.6
        _current_spin_speed = lerp(_current_spin_speed, target_spin_speed, 5.0 * delta)
        _body_sprite.rotation += _current_spin_speed * delta

    if is_instance_valid(_trail_particles):
        var threshold: float = 0.4 if is_seeking() else 0.65
        _trail_particles.emitting = get_speed_ratio() > threshold


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
