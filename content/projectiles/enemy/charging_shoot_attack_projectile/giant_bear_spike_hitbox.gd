extends "res://overlap/hitbox.gd"

onready var _additional_collisions: Array = [$CollisionMiddle, $CollisionTip]

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func enable() -> void:
    .enable()
    for collision in _additional_collisions:
        collision.set_deferred("disabled", false)

func disable() -> void:
    .disable()
    for collision in _additional_collisions:
        collision.set_deferred("disabled", true)
