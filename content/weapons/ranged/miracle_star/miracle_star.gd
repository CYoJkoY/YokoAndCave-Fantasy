extends "res://weapons/melee/melee_weapon.gd"

const STAR_SCENE: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/miracle_star/miracle_star_summon.tscn")


func _ready() -> void:
    var star = STAR_SCENE.instance()
    star.initialize(self, Utils.get_scene_node())
    add_child(star)
