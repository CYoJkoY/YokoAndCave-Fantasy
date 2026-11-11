extends MovementBehavior

# Root of the pet movement family: a pet that wanders around its owner.
# This layer owns the shared locomotion loop (velocity integration, zone
# bounds, facing) and the wander intent itself. Flying pets build on it
# through floating_pet_movement_behavior.gd and only add their hover
# presentation.
#
# Pets walk on the ground by default and steer around pits; a flying branch
# overrides _should_avoid_forbidden_zones() to pass over them.

const WANDER_MIN_RADIUS: float = 90.0
const WANDER_ARRIVE_DISTANCE: float = 40.0
const WANDER_TURN_LIMIT: float = 2.4
const WANDER_CATCH_UP_MAX_FACTOR: float = 2.5
const WANDER_TIME_MIN: float = 2.5
const WANDER_TIME_MAX: float = 4.5

export(float) var zone_padding: float = 30.0
export(float) var facing_threshold: float = 4.0
export(bool) var mirror_facing: bool = true

export(float) var wander_radius: float = 240.0
export(float) var wander_acceleration: float = 260.0

var _velocity: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0
var _initialized: bool = false


func init(parent: Node) -> Node:
    .init(parent)
    _wander_target = _parent.global_position
    _wander_angle = rand_range(-PI, PI)
    _initialized = true
    return self


func reset_motion() -> void:
    _velocity = Vector2.ZERO


func reset_wander() -> void:
    _wander_angle = rand_range(-PI, PI)
    _wander_timer = 0.0
    if is_instance_valid(_parent):
        _wander_target = _parent.global_position
    reset_motion()


func get_velocity() -> Vector2:
    return _velocity


func get_speed_ratio() -> float:
    return clamp(_velocity.length() / max(1.0, _get_reference_speed()), 0.0, 1.0)


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
    var resolved_position: Vector2 = clamp_position_to_zone(pos)
    if _should_avoid_forbidden_zones():
        resolved_position = ZoneService.push_out_of_forbidden(resolved_position)
    return resolved_position


func clamp_position_to_zone(pos: Vector2) -> Vector2:
    return Vector2(
        clamp(pos.x, ZoneService.current_zone_min_position.x + zone_padding, ZoneService.current_zone_max_position.x - zone_padding),
        clamp(pos.y, ZoneService.current_zone_min_position.y + zone_padding, ZoneService.current_zone_max_position.y - zone_padding)
    )


func _get_acceleration() -> float:
    return wander_acceleration


func _get_reference_speed() -> float:
    return max(1.0, _get_wander_speed())


func _get_wander_speed() -> float:
    return _parent.get_move_speed()


func _get_speed_factor() -> float:
    return 1.0


func _should_avoid_forbidden_zones() -> bool:
    return true


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
