extends Reference


static func update_capsule_sweep(collision: CollisionShape2D, previous: Vector2, current: Vector2) -> void:
    var motion: Vector2 = current - previous
    collision.global_position = (previous + current) * 0.5
    collision.global_rotation = motion.angle() + PI * 0.5
    collision.shape.height = motion.length()
