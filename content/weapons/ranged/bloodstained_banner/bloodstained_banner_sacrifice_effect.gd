extends NullEffect

var _damage_args = TakeDamageArgs.new(-1)


func _init() -> void:
    _damage_args.dodgeable = false
    _damage_args.armor_applied = false
    _damage_args.bypass_invincibility = true


static func get_id() -> String:
    return "weapon_bloodstained_banner_sacrifice"


func on_cast_completed(player: Node) -> void:
    _damage_args.from = player
    var _damage_taken: Array = player.take_damage(value, _damage_args)
