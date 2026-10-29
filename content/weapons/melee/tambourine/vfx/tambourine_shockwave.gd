extends "res://projectiles/player_explosion.gd"

const SHOCKWAVE_SCHEDULER = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/tambourine/tambourine_scheduler.gd")
const DAMAGE_NUMBER_COLOR: Color = Color("f5e6be")

var _scheduler: Node


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	visible = false
	_hitbox.set_meta("fantasy_damage_color", DAMAGE_NUMBER_COLOR)
	_hitbox.set_meta("fantasy_tambourine_damage", true)


func start_explosion() -> void:
	_hitbox.from = self
	_hitbox.player_attack_id = -1
	_hitbox.enable()
	_explosion_smoke.emitting = false
	sound_played = true
	_scheduler = SHOCKWAVE_SCHEDULER.for_scene(Utils.get_scene_node())
	_scheduler.track_explosion(self)


func set_tint(tint: Color) -> void:
	_scheduler.spawn_visual(self, tint)
