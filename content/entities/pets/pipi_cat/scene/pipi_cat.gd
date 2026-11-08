extends Pet

enum State { ARMED, CHARGING, BLOWING, COOLDOWN }

const FANTASY_VISUAL_PARTS_SYNC = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/visual_parts_sync.gd")

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

const BLOW_STRENGTH_MULTIPLIER: float = 4.0

var is_pipi_cat: bool = true

onready var _parts_offset: Node2D = $Animation/Offset
onready var _trigger_shape: CollisionShape2D = $TargetTriggerZone/CollisionShape2D
onready var _normal: Sprite = $Animation/Offset/Normal
onready var _angry: Sprite = $Animation/Offset/Angry
onready var _tired: Sprite = $Animation/Offset/Tired

var _visual_parts_sync = FANTASY_VISUAL_PARTS_SYNC.new()
var _state: int = State.ARMED
var _state_time_left: float = 0.0
var _targets_in_range: Array = []

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
    var pipi_effect: PipiCatEffect = effect as PipiCatEffect
    charge_duration = pipi_effect.get_charge_duration(player_index)
    cooldown_duration = pipi_effect.get_cooldown_duration(player_index)
    blow_radius = pipi_effect.blow_radius
    blow_strength = pipi_effect.blow_strength
    _trigger_shape.shape.radius = blow_radius

func _physics_process(delta: float) -> void:
    if dead:
        return

    _prioritize_enemies()
    _prune_targets()

    match _state:
        State.CHARGING:
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

func _on_TargetTriggerZone_body_entered(body: Node) -> void:
    if !(body is Enemy) or body.dead:
        return

    if not _targets_in_range.has(body):
        _targets_in_range.push_back(body)

    if _state == State.ARMED:
        _set_state(State.CHARGING)
        _state_time_left = charge_duration

func _on_TargetTriggerZone_body_exited(body: Node) -> void:
    _targets_in_range.erase(body)

func _prune_targets() -> void:
    for target in _targets_in_range.duplicate():
        if not is_instance_valid(target) or target.dead:
            _targets_in_range.erase(target)

func _blow_away_enemies() -> void:
    _set_state(State.BLOWING)
    _state_time_left = max(0.1, _animation_player.get_animation("angry_trigger").length)
    for enemy in _targets_in_range:
        if not is_instance_valid(enemy) or enemy.dead:
            continue
        var direction: Vector2 = enemy.global_position - global_position
        if direction.length_squared() == 0:
            direction = Vector2.RIGHT
        enemy.knockback_vector = direction.normalized() * blow_strength * BLOW_STRENGTH_MULTIPLIER

func _prioritize_enemies() -> void:
    for enemy in _entity_spawner_ref.get_all_enemies(false):
        if enemy.dead or enemy.current_target == self:
            continue

        if enemy.current_target != null and enemy.current_target.is_connected("died", enemy, "_on_target_died"):
            enemy.current_target.disconnect("died", enemy, "_on_target_died")

        enemy.current_target = self
        if not is_connected("died", enemy, "_on_target_died"):
            var _error_died = connect("died", enemy, "_on_target_died")

func _enter_cooldown() -> void:
    _set_state(State.COOLDOWN)
    _state_time_left = cooldown_duration

func _set_state(next_state: int) -> void:
    if _state == next_state:
        return

    _state = next_state
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

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
    if anim_name != "angry_trigger":
        return

    if _state == State.BLOWING:
        _enter_cooldown()
