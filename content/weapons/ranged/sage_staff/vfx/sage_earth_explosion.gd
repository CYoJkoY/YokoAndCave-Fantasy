extends "res://projectiles/player_explosion.gd"


func set_smoke_amount(_value: int) -> void:
    _explosion_smoke.emitting = false


func emit_smoke() -> void:
    _explosion_smoke.emitting = false
