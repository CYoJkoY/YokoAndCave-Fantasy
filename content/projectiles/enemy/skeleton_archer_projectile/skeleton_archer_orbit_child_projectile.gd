extends "res://mods-unpacked/Yoko-Fantasy/content/projectiles/enemy/enemy_projectile_limit_time.gd"

var _orbit_angle: float = 0.0
var _orbit_radius: float = 50.0
var _orbit_radius_growth: float = 0.0
var _orbit_speed: float = 8.0
var _side: Vector2 = Vector2.DOWN
var _last_orbit_offset: Vector2 = Vector2.ZERO
var _orbit_enabled: bool = false

func setup_orbit_parent(parent_projectile: Node2D, orbit_angle: float, orbit_radius: float, orbit_radius_growth: float, orbit_speed: float) -> void:
    _orbit_angle = orbit_angle
    _orbit_radius = orbit_radius
    _orbit_radius_growth = orbit_radius_growth
    _orbit_speed = orbit_speed
    var forward: Vector2 = parent_projectile.velocity.normalized() if parent_projectile.velocity.length_squared() > 0 else Vector2.RIGHT.rotated(parent_projectile.rotation)
    _side = forward.tangent()
    _last_orbit_offset = _get_orbit_offset()
    global_position += _last_orbit_offset
    _orbit_enabled = true

func _physics_process(delta) -> void:
    if _orbit_enabled:
        if lifetime <= 0:
            delta_time += delta

        _orbit_angle += _orbit_speed * delta
        var orbit_offset: Vector2 = _get_orbit_offset()
        position += orbit_offset - _last_orbit_offset
        _last_orbit_offset = orbit_offset

func stop() -> void:
    _orbit_enabled = false
    _last_orbit_offset = Vector2.ZERO
    .stop()

func _return_to_pool() -> void:
    _orbit_enabled = false
    _orbit_radius_growth = 0.0
    _side = Vector2.DOWN
    _last_orbit_offset = Vector2.ZERO
    ._return_to_pool()

func _get_orbit_offset() -> Vector2:
    return _side * cos(_orbit_angle) * (_orbit_radius + _orbit_radius_growth * delta_time)
