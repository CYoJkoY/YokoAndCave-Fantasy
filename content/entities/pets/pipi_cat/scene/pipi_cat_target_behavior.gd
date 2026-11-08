extends PlayerOwnerTargetBehavior

export(bool) var target_player_if_no_target = true
export(String) var pet_id = ""
export(bool) var exclude_elite_and_boss_target = true

func _on_Range_body_entered(_body: Node2D) -> void:
    pass

func _on_Range_body_exited(_body: Node2D) -> void:
    pass
