extends Reference

static func fa_handle_selected_upgrade_hooks(upgrade_data: UpgradeData) -> void:
	if upgrade_data == null:
		return

	for effect in upgrade_data.effects:
		if effect == null or effect.get_id() != "fantasy_music_override_track":
			continue

		_fantasy_handle_music_override_track(effect)

static func _fantasy_handle_music_override_track(effect: Effect) -> void:
	if effect.selection_sound_path != "":
		var selection_sound: AudioStream = load(effect.selection_sound_path) as AudioStream
		if selection_sound != null:
			SoundManager.play(selection_sound, 0, 0)

	if effect.bgm_stream_path != "":
		var bgm_stream: AudioStream = load(effect.bgm_stream_path) as AudioStream
		if bgm_stream != null:
			MusicManager.fa_play_override_once(bgm_stream, 0)
