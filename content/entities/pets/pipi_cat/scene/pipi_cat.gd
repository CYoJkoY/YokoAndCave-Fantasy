extends Pet

enum State { ARMED, CHARGING, BLOWING, COOLDOWN }

const FANTASY_VISUAL_PARTS_SYNC = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/visual_parts_sync.gd")

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

var is_pipi_cat: bool = true

onready var _parts_offset: Node2D = $Animation/Offset
onready var _trigger_shape: CollisionShape2D = $TargetTriggerZone/CollisionShape2D
onready var _normal: Sprite = $Animation/Offset/Normal
onready var _angry: Sprite = $Animation/Offset/Angry
onready var _tired: Sprite = $Animation/Offset/Tired

var _visual_parts_sync = FANTASY_VISUAL_PARTS_SYNC.new()
var _pipi_effect: PipiCatEffect
var _state: int = State.ARMED
var _state_time_left: float = 0.0
var _targets_in_range: Array = []

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    _visual_parts_sync.setup_from(_parts_offset, sprite)
    _set_visual_state(State.ARMED)

func update_animation(movement: Vector2) -> void:
    .update_animation(movement)
    _parts_offset.scale.x = sprite.scale.x * _parts_offset.scale.y

func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void:
    ._set_outlines(alpha, desaturation)
    _visual_parts_sync.sync_from(sprite)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    _pipi_effect = effect as PipiCatEffect
    charge_duration = _pipi_effect.get_charge_duration(player_index)
    cooldown_duration = _pipi_effect.get_cooldown_duration(player_index)
    blow_radius = _pipi_effect.blow_radius
    blow_strength = _pipi_effect.blow_strength
    # The scene shares subresources; each cat needs its own detection radius.
    _trigger_shape.shape = _trigger_shape.shape.duplicate()
    _trigger_shape.shape.radius = blow_radius

func die(args: = DieArgs.new()) -> void:
    _set_targetable(false)
    .die(args)

func respawn() -> void:
    # The spawner registers targetable pets after respawn() returns. Registering
    # here as well would add a duplicate entry that erase() cannot fully remove,
    # so this only restores the state machine.
    .respawn()
    _state = State.ARMED
    _state_time_left = 0.0
    _targets_in_range.clear()
    _set_visual_state(State.ARMED)

func _physics_process(delta: float) -> void:
    if dead or _end_of_wave:
        return

    match _state:
        State.ARMED:
            _try_charge()

        State.CHARGING:
            _prune_targets()
            if _targets_in_range.empty():
                _set_state(State.ARMED)
                _state_time_left = 0.0
                return

            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _blow_away_enemies()

        State.BLOWING:
            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _enter_cooldown()

        State.COOLDOWN:
            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _set_state(State.ARMED)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _blow_away_enemies() -> void:
    _set_state(State.BLOWING)
    _state_time_left = max(0.1, _animation_player.get_animation("angry_trigger").length)
    var blow_distance: float = _get_blow_distance()
    var stun_duration: float = _pipi_effect.get_stun_duration(player_index)
    for enemy in _targets_in_range.duplicate():
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            continue

        var direction: Vector2 = enemy.global_position - global_position
        if direction.length_squared() == 0:
            direction = Vector2.RIGHT
        enemy.fa_launch_airborne(direction.normalized(), blow_distance, player_index, stun_duration)

func _get_blow_distance() -> float:
    var zone_size: Vector2 = ZoneService.get_current_zone_rect().size
    return min(zone_size.x, zone_size.y) * _get_blow_distance_fraction()

func _prune_targets() -> void:
    for i in range(_targets_in_range.size() - 1, -1, -1):
        var enemy = _targets_in_range[i]
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            _targets_in_range.remove(i)

func _try_charge() -> void:
    _prune_targets()
    if _targets_in_range.empty():
        return
    _set_state(State.CHARGING)
    _state_time_left = charge_duration

func _get_blow_distance_fraction() -> float:
    return PipiCatEffect.BLOW_DISTANCE_MAP_FRACTION * blow_strength / PipiCatEffect.BLOW_STRENGTH_REFERENCE

func _enter_cooldown() -> void:
    _set_state(State.COOLDOWN)
    _state_time_left = cooldown_duration

func _set_state(next_state: int) -> void:
    if _state == next_state:
        return

    var was_targetable: bool = _is_targetable_state(_state)
    _state = next_state
    var is_targetable: bool = _is_targetable_state(next_state)
    if was_targetable != is_targetable:
        _set_targetable(is_targetable)
    _set_visual_state(next_state)

func _set_visual_state(state: int) -> void:
    _normal.visible = state == State.ARMED or state == State.CHARGING
    _tired.visible = state == State.COOLDOWN
    _angry.visible = state == State.BLOWING

    if state == State.COOLDOWN:
        _animation_player.play("tired_idle")
    elif state == State.CHARGING or state == State.BLOWING:
        _animation_player.play("angry_trigger")
    elif state == State.ARMED:
        _animation_player.play("idle")

func _is_targetable_state(state: int) -> bool:
    return state != State.COOLDOWN

func _set_targetable(targetable: bool) -> void:
    if not is_instance_valid(_entity_spawner_ref):
        return

    var targetable_pets: Array = _entity_spawner_ref.targetable_pets
    if targetable:
        if not can_be_targeted_by_enemies:
            return
        if not targetable_pets.has(self):
            targetable_pets.push_back(self)
        return

    if not targetable_pets.has(self):
        return

    targetable_pets.erase(self)
    if _entity_spawner_ref._cleaning_up:
        return

    # Removing the pet only affects future target refreshes. Enemies already
    # locked on it keep a stale target until their next refresh, so retarget
    # them once here instead of revisiting every enemy each frame.
    _retarget_enemies_away_from_self()

func _retarget_enemies_away_from_self() -> void:
    for enemy in _entity_spawner_ref.get_all_enemies(false):
        if not is_instance_valid(enemy) or enemy.dead:
            continue
        if enemy.current_target != self:
            continue
        enemy.update_target()

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
func _on_TargetTriggerZone_body_entered(body: Node) -> void:
    if body.dead or body._pending_die:
        return

    if not _targets_in_range.has(body):
        _targets_in_range.append(body)

    if _state == State.ARMED:
        _try_charge()

func _on_TargetTriggerZone_body_exited(body: Node) -> void:
    _targets_in_range.erase(body)

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
    if anim_name != "angry_trigger":
        return

    if _state == State.BLOWING:
        _enter_cooldown()
