extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/cross_staff/vfx/holy_light_strike.gd"


func _ready() -> void:
    _ground_seal.modulate = Color(0.88, 0.94, 1.0, 0.75)
    _ground_bloom.modulate = Color(1.0, 0.93, 0.76, 0.3)
    _shockwave.modulate = Color(1.0, 0.95, 0.82, 0.55)
    _impact_flare.modulate = Color(0.93, 0.97, 1.0, 0.65)
    $Pillar/BeamBloom.visible = false
    $Pillar/BeamAura.modulate = Color(0.80, 0.90, 1.0, 0.38)
    $Pillar/BeamCore.modulate = Color(1.0, 0.99, 0.94, 0.85)
    _ray_left.modulate = Color(0.86, 0.94, 1.0, 0.35)
    _ray_right.modulate = _ray_left.modulate
    _holy_dust.lifetime = 0.58
    _holy_dust.initial_velocity = 55.0
    _falling_sparks.lifetime = 0.58
    for particles in [_holy_dust, _falling_sparks]:
        var ramp: Gradient = particles.color_ramp.duplicate()
        ramp.colors = PoolColorArray([Color(1, 1, 0.96, 0.8), Color(0.88, 0.95, 1, 0.65), Color(1, 0.93, 0.76, 0.35), Color(1, 0.93, 0.76, 0)])
        particles.color_ramp = ramp


func start_strike(target_pos: Vector2, target_node: Node = null, scale_mult: float = 1.0, tint_color: Color = Color.white) -> void:
    .start_strike(target_pos, target_node, scale_mult, tint_color)
    _ground_seal.rotation = 0.0
    _impact_flare.rotation = 0.0
    _ray_left.position = Vector2(-24, -250)
    _ray_right.position = Vector2(24, -250)
    _process_summon(0.0)


func _process_summon(progress: float) -> void:
    var eased: float = 1.0 - pow(1.0 - progress, 3.0)
    _ground_seal.scale = Vector2.ONE * _base_seal_scale * (0.3 + eased * 0.7)
    _ground_seal.modulate.a = 0.25 + eased * 0.5
    _ground_bloom.modulate.a = 0.15 + eased * 0.3


func _process_strike(progress: float) -> void:
    ._process_strike(progress)
    var release: float = 1.0 - pow(1.0 - progress, 3.0)
    _pillar.scale = Vector2(1.0 + 0.25 * (1.0 - release), 1.0)
    _pillar.modulate.a = 0.85 - progress * 0.15
    _ground_seal.rotation = progress * 0.12
    _ground_seal.modulate.a = 0.75 - progress * 0.2
    _ground_bloom.modulate.a = 0.45 - progress * 0.25
    _impact_flare.scale = Vector2.ONE * (0.35 + release * 0.80)
    _impact_flare.rotation = 0.0
    _impact_flare.modulate.a = 0.8 * pow(1.0 - progress, 2.0)
    _shockwave.scale = Vector2.ONE * (0.2 + release * 0.85)
    _shockwave.modulate.a = 0.6 * pow(1.0 - progress, 2.0)
    _ray_left.position = Vector2(-24 * (1.0 - release), -250)
    _ray_right.position = Vector2(24 * (1.0 - release), -250)


func _process_fade(progress: float) -> void:
    var eased: float = progress * progress * (3.0 - 2.0 * progress)
    var fade: float = 1.0 - eased
    var drift: float = sin(progress * PI) * fade
    _pillar.scale = Vector2(1.0 - eased * 0.85, 1.0)
    _pillar.modulate.a = 0.70 * pow(fade, 1.5)
    _ray_left.position = Vector2(7.0 * drift, -250 - 14.0 * drift)
    _ray_right.position = Vector2(-7.0 * drift, -250 + 10.0 * drift)
    _ground_seal.scale = Vector2.ONE * _base_seal_scale * (1.0 + eased * 0.08)
    _ground_seal.rotation = 0.12 + eased * 0.16
    _ground_seal.modulate.a = 0.55 * fade
    _ground_bloom.modulate.a = 0.20 * pow(fade, 0.8)
    _shockwave.visible = false
    _impact_flare.visible = false
