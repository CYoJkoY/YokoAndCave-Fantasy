extends Reference

enum Flight {ORBIT, APPROACH, RETURN}

const IDLE_RADIUS: float = 210.0
const CRUISE_SPEED: float = 540.0
const ATTACK_SPEED: float = 1450.0
const ACCELERATION: float = 9000.0

var position: Vector2
var velocity: Vector2
var target: Node2D
var state: int = Flight.ORBIT
var cooldown: float = 0.0
var _angle: float = 0.0
var _last_center: Vector2
var _age: float = 0.0


func initialize(center: Vector2, weapon_center: Vector2, radius: float, index: int, count: int, phase: float) -> void:
    _angle = TAU * float(index) / count + phase
    _last_center = center
    _place_orbit(center, get_orbit_radius(center, weapon_center, radius))


func begin_pass(next_target: Node2D) -> void:
    target = next_target
    state = Flight.APPROACH
    _age = 0.0


func finish_pass() -> void:
    if state != Flight.APPROACH:
        return
    target = null
    state = Flight.RETURN
    _age = 0.0


func advance(delta: float, center: Vector2, weapon_center: Vector2, radius: float) -> void:
    if delta <= 0.0:
        return
    cooldown = max(0.0, cooldown - delta)
    var displacement: Vector2 = center - _last_center
    position += displacement
    _last_center = center
    if displacement.length_squared() > 16384.0:
        finish_pass()
    var orbit_radius: float = get_orbit_radius(center, weapon_center, radius)
    var angular_speed: float = CRUISE_SPEED / IDLE_RADIUS
    _angle = wrapf(_angle + angular_speed * delta, -PI, PI)
    if state == Flight.ORBIT:
        _place_orbit(center, orbit_radius)
        return

    _age += delta
    if state == Flight.APPROACH and _age > 0.95:
        finish_pass()
    var slot: Vector2 = Vector2.RIGHT.rotated(_angle) * orbit_radius
    var slot_velocity: Vector2 = slot.rotated(PI * 0.5) * angular_speed
    var desired_velocity: Vector2
    if state == Flight.APPROACH:
        desired_velocity = (target.global_position - position).normalized() * ATTACK_SPEED
    else:
        desired_velocity = (slot_velocity + (center + slot - position) * 7.0).clamped(ATTACK_SPEED)
    velocity = velocity.move_toward(desired_velocity, ACCELERATION * delta)
    position += velocity * delta

    var from_weapon: Vector2 = position - weapon_center
    if from_weapon.length_squared() > radius * radius:
        var normal: Vector2 = from_weapon.normalized()
        position = weapon_center + normal * max(0.0, radius)
        velocity -= normal * max(0.0, velocity.dot(normal))
    if state == Flight.RETURN and position.distance_squared_to(center + slot) < 400.0 and velocity.distance_squared_to(slot_velocity) < 10000.0:
        state = Flight.ORBIT
        _place_orbit(center, orbit_radius)


static func get_orbit_radius(center: Vector2, weapon_center: Vector2, radius: float) -> float:
    return min(IDLE_RADIUS, max(0.0, radius - center.distance_to(weapon_center)))


func _place_orbit(center: Vector2, radius: float) -> void:
    var offset: Vector2 = Vector2.RIGHT.rotated(_angle) * radius
    position = center + offset
    velocity = offset.rotated(PI * 0.5) * (CRUISE_SPEED / IDLE_RADIUS)
