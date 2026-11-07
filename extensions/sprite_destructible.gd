extends "res://zones/generation_elements/sprite_destructible.gd"

const FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP: String = "fantasy_clock_flattenable_vegetation"

func _ready() -> void:
    add_to_group(FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP)
    call_deferred("_fantasy_notify_clock_towers")

func _fantasy_notify_clock_towers() -> void:
    if destroyed:
        return

    for clock_tower in get_tree().get_nodes_in_group("fantasy_clock_tower_area"):
        clock_tower.fantasy_flatten_vegetation(self)

func destroy_sprite() -> void:
    if destroyed:
        return

    destroyed = true
    remove_from_group(FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP)
    .destroy_sprite()
