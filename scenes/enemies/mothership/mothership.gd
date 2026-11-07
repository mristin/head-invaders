class_name Mothership

extends Enemy

## The mothership of the aliens, who comes at the end of the second level once
## all the others have fled. A friendly pilot steers it from under the big
## glass dome. It glides across the top of the screen and takes turns: a
## pinwheel of rockets, the rockets from both side pods at the nearest
## spaceship, and calling in the zippers.
##
## Each time it loses a third of its energy, it drops one of its treasure
## chests. When it is low on energy, it attacks more often. When it flees, its
## zippers follow it home.

const _ZIPPER_SCENE: PackedScene = preload("res://scenes/enemies/zipper/zipper.tscn")

@export var descent_speed: float = 100.0

@export var sway_amplitude: float = 520.0
@export var sway_frequency: float = 0.06

@export var bob_amplitude: float = 24.0
@export var bob_frequency: float = 0.25

## The pinwheel: the number of arms, the number of volleys, the seconds between
## the volleys, and how far the arms turn between the volleys, in radians.
@export var pinwheel_arms: int = 2
@export var pinwheel_volleys: int = 7
@export var pinwheel_interval: float = 0.2
@export var pinwheel_turn: float = 0.45
@export var pinwheel_rocket_speed: float = 300.0

## The rockets from the side pods: how many from each pod, and the angle
## between them.
@export var pod_fan_size: int = 2
@export var pod_fan_angle: float = 0.3

@export var zippers_per_call: int = 2
@export var max_zippers: int = 2

## How many chests the mothership drops, evenly spread over its energy.
@export var chest_count: int = 2

## Below this fraction of the energy, it attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.34
@export var hurry_factor: float = 1.5

@export var margin: float = 220.0

var _time: float = 0.0
var _descending: bool = true
var _attack: int = 0
var _chests_dropped: int = 0

var _volleys_left: int = 0
var _volley_cooldown: float = 0.0
var _pinwheel_angle: float = 0.0


func chests_dropped() -> int:
    return _chests_dropped


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func take_damage(amount: int) -> void:
    super(amount)

    # NOTE (mristin):
    # The mothership drops a chest each time it loses another share of its
    # energy, but not the last one; it flees then anyway.
    var lost := 1.0 - float(energy) / float(max_energy)
    while (
        is_alive()
        and _chests_dropped < chest_count
        and lost >= (_chests_dropped + 1.0) / (chest_count + 1.0)
    ):
        _chests_dropped += 1
        Chest.drop(self, global_position + Vector2(0, radius * 0.5))


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
        return

    var bounds := get_viewport_rect()
    var x := home.x + sin(_time * TAU * sway_frequency) * sway_amplitude
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * TAU * bob_frequency) * bob_amplitude

    if _volleys_left > 0:
        _volley_cooldown -= delta
        if _volley_cooldown <= 0.0:
            _volley_cooldown = pinwheel_interval
            _volleys_left -= 1
            _fire_volley()


func _fire_rocket() -> void:
    if _descending or _volleys_left > 0:
        return

    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    match _attack % 3:
        0:
            _volleys_left = pinwheel_volleys
            _volley_cooldown = 0.0
        1:
            _fire_pods()
        _:
            if minions().size() + zippers_per_call <= max_zippers:
                _call_zippers()
            else:
                _fire_pods()
    _attack += 1


func _fire_volley() -> void:
    _pinwheel_angle += pinwheel_turn
    for i in range(pinwheel_arms):
        var direction := Vector2.DOWN.rotated(_pinwheel_angle + TAU * i / pinwheel_arms)
        # NOTE (mristin):
        # We skip the arms pointing up, which nobody could dodge anyway, so
        # that the screen does not fill with rockets.
        if direction.y > -0.2:
            _launch_rocket(direction, pinwheel_rocket_speed)


func _fire_pods() -> void:
    var target := _nearest_spaceship()
    for side: float in [-1.0, 1.0]:
        var pod := global_position + Vector2(side * radius * 0.75, radius * 0.1)
        var aim := Vector2.DOWN
        if target != null:
            aim = pod.direction_to(target.global_position)
        for i in range(pod_fan_size):
            var angle := (i - (pod_fan_size - 1) / 2.0) * pod_fan_angle
            _launch_rocket_from(pod, aim.rotated(angle), rocket_speed)


func _call_zippers() -> void:
    for i in range(zippers_per_call):
        var side := -1.0 if i % 2 == 0 else 1.0
        var zipper := _summon(
            _ZIPPER_SCENE, global_position + Vector2(side * radius * 0.5, radius * 0.3)
        )
        zipper.max_energy = 30

    Poof.spawn(self, global_position + Vector2(0, radius * 0.3), radius * 0.4, Color(0.6, 1, 0.8))


func _start_fleeing(beaten: bool = true) -> void:
    # NOTE (mristin):
    # Its zippers follow it home; see Enemy.minions.
    super(beaten)
    _volleys_left = 0
    Poof.spawn(self, global_position, radius * 1.5, Color(0.6, 1.0, 0.8))


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var hurry := is_in_a_hurry()

    # NOTE (mristin):
    # A soft beam shines below while the pinwheel spins.
    if _volleys_left > 0:
        var beam := PackedVector2Array(
            [
                Vector2(-r * 0.25, r * 0.2),
                Vector2(r * 0.25, r * 0.2),
                Vector2(r * 0.5, r * 0.9),
                Vector2(-r * 0.5, r * 0.9),
            ]
        )
        draw_colored_polygon(beam, Color(0.6, 1.0, 0.8, 0.2))

    # The glass dome with the pilot.
    var dome_center := Vector2(0, -r * 0.18)
    draw_circle(dome_center, r * 0.42, Color(0.55, 0.85, 1.0, 0.35).lerp(white, flash * 0.5))
    var face := dome_center + Vector2(0, r * 0.05)
    var face_color := Color(0.55, 0.9, 0.45).lerp(white, flash)
    for side: float in [-1.0, 1.0]:
        var tip := face + Vector2(side * r * 0.16, -r * 0.36)
        draw_line(face + Vector2(side * r * 0.08, -r * 0.18), tip, face_color, r * 0.03)
        draw_circle(tip, r * 0.045, Color(1.0, 0.6, 0.8).lerp(white, flash))
    draw_circle(face, r * 0.22, face_color)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.08, -r * 0.03)
        draw_circle(eye, r * 0.06, white)
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.03, Color(0.1, 0.2, 0.1))
    draw_arc(
        face + Vector2(0, r * 0.06), r * 0.07, 0.3, PI - 0.3, 10, Color(0.1, 0.3, 0.1), r * 0.02
    )
    draw_circle(dome_center + Vector2(-r * 0.2, -r * 0.2), r * 0.07, Color(1, 1, 1, 0.4))

    # The hull.
    var hull := PackedVector2Array()
    for i in range(48):
        var angle := TAU * i / 48.0
        var y := sin(angle) * r * 0.28
        if y < 0.0:
            y *= 0.5
        hull.append(Vector2(cos(angle) * r, y + r * 0.08))
    var hull_color := Color(0.4, 0.42, 0.6) if not hurry else Color(0.55, 0.4, 0.55)
    draw_colored_polygon(hull, hull_color.lerp(white, flash))
    draw_line(
        Vector2(-r * 0.95, r * 0.08), Vector2(r * 0.95, r * 0.08), Color(0.3, 0.3, 0.45), r * 0.03
    )

    # NOTE (mristin):
    # The lights run around the hull, faster when it is in a hurry.
    for i in range(9):
        var x := -r * 0.8 + r * 1.6 * i / 8.0
        var on := fmod(_time * (8.0 if hurry else 4.0) + i, 3.0) < 1.0
        var light := Color(0.6, 1.0, 0.8) if on else Color(0.25, 0.45, 0.4)
        draw_circle(Vector2(x, r * 0.2), r * 0.04, light.lerp(white, flash))

    # The side pods.
    for side: float in [-1.0, 1.0]:
        var pod := Vector2(side * r * 0.75, r * 0.28)
        draw_circle(pod, r * 0.12, Color(0.3, 0.32, 0.48).lerp(white, flash))
        var glow := 0.5 + 0.5 * sin(_time * 5.0 + side)
        draw_circle(pod, r * 0.06, Color(1.0, 0.8, 0.4, 0.5 + 0.5 * glow).lerp(white, flash))
