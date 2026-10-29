extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/shared/orbit_strike_weapon.gd"

onready var _visuals: Node2D = $Sprite/BannerEffects

var _sacrifice_effect: Resource


func _ready() -> void:
    for effect in effects:
        if effect.get_id() == "weapon_bloodstained_banner_sacrifice":
            _sacrifice_effect = effect
            break
    _visuals.set_cursed(is_cursed)


func _get_thrust_height() -> float:
    return 0.0


func _start_cast_effects() -> void:
    _visuals.play_cast()


func _configure_strike_visuals(strike_vfx: Node2D) -> void:
    strike_vfx.set_cursed(is_cursed)


func _on_cast_completed() -> void:
    if _sacrifice_effect != null:
        _sacrifice_effect.on_cast_completed(_parent)


func _update_visual_effects(delta: float) -> void:
    _visuals.advance(delta, _time)
