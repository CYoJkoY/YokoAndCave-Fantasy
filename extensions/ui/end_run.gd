extends "res://ui/menus/run/end_run.gd"

const BUTTON_SHOW_JOB = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/jobs/button_show_job_scene.tscn")

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    var job_button: MyMenuButton = BUTTON_SHOW_JOB.instance()
    job_button.attach_to_inventory(_items_container, $"MarginContainer/VBoxContainer", self)
