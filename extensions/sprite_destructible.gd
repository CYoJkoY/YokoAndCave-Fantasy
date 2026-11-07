extends "res://zones/generation_elements/sprite_destructible.gd"

const FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP: String = "fantasy_clock_flattenable_vegetation"

func _ready() -> void:
    ._ready()
    add_to_group(FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP)

func destroy_sprite() -> void:
    if destroyed:
        return

    destroyed = true
    remove_from_group(FANTASY_CLOCK_FLATTENABLE_VEGETATION_GROUP)
    .destroy_sprite()
