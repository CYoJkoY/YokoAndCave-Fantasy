extends EnemyProjectile

export(float) var lifetime = 0.0
export(bool) var reset_alpa = false
export(int) var reset_alpha = 0

var delta_time: float = 0.0

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _physics_process(delta) -> void:
    if lifetime <= 0: return

    delta *= _get_time_factor()
    delta_time += delta
    if delta_time < lifetime: return
    
    delta_time = 0.0
    stop()

func stop(from_screen_border: bool = false) -> void:
    if _enable_stop_delay: return

    if reset_alpa: _sprite.self_modulate.a = reset_alpha
    delta_time = 0.0
    .stop(from_screen_border)
