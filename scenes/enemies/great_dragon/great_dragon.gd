class_name GreatDragon

extends Enemy

## The great red dragon, who comes at the end of the lava world once all
## the others have fled. Its attacks are big but always announced:
##
## * The fire breath: the dragon rears its head and its mouth glows while it
##   takes a deep breath, then it breathes a long stream of fireballs, sweeping
##   across the nearest spaceship. The stream comes in puffs, with gaps.
## * The fireball rain: it lobs big fireballs high up, which fall back down in
##   arcs.
## * The swoop: it swoops down across the screen in a big arc and settles on
##   the other side.
##
## When it is low on energy, the breath sweeps there and back again.

enum Action { ENTERING, HOVER, INHALE, BREATHE, SWOOP }

@export var descent_speed: float = 140.0

@export var hover_sway: float = 120.0
@export var hover_frequency: float = 0.12

## The fire breath: how long the dragon inhales first, how long it breathes,
## how wide it sweeps, in radians, and the seconds between the fireballs. Every
## puff_length-th fireball is left out, so that the stream has gaps.
@export var inhale_duration: float = 0.9
@export var breath_duration: float = 1.4
@export var breath_sweep: float = 1.0
@export var breath_interval: float = 0.12
@export var puff_length: int = 3
@export var breath_speed: float = 430.0

## The fireball rain: the number of fireballs, how fast they are thrown up,
## and how strongly they fall back.
@export var rain_count: int = 3
@export var rain_speed: float = 620.0
@export var rain_fall_acceleration: float = 560.0

## The swoop: how long it takes, and how deep it dips.
@export var swoop_duration: float = 2.4
@export var swoop_depth: float = 260.0

## Below this fraction of the energy, the breath sweeps there and back.
@export_range(0.0, 1.0) var hurry_below: float = 0.5

@export var margin: float = 320.0

var _action: Action = Action.ENTERING
var _time: float = 0.0
var _action_time: float = 0.0
var _attack: int = 0
var _breaths: int = 0
var _swoops: int = 0

var _hover_x: float = 0.0
var _breath_center: Vector2 = Vector2.DOWN
var _breath_from: float = 0.0
var _breath_cooldown: float = 0.0
var _breath_shots: int = 0
var _breath_aim: Vector2 = Vector2.DOWN
var _swoop_from_x: float = 0.0
var _swoop_to_x: float = 0.0


## Return how many times the dragon breathed fire so far, e.g., for the tests.
func breaths() -> int:
    return _breaths


## Return how many times the dragon swooped so far, e.g., for the tests.
func swoops() -> int:
    return _swoops


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _enter() -> void:
    super()
    _hover_x = home.x


func _move(delta: float) -> void:
    _time += delta
    _action_time += delta

    match _action:
        Action.ENTERING:
            position.y = minf(position.y + descent_speed * delta, home.y)
            if position.y >= home.y:
                _start(Action.HOVER)
        Action.HOVER:
            _hover()
        Action.INHALE:
            _hover()
            if _action_time >= inhale_duration:
                _start_breath()
        Action.BREATHE:
            _hover()
            _breathe(delta)
        Action.SWOOP:
            var t := clampf(_action_time / swoop_duration, 0.0, 1.0)
            position.x = lerpf(_swoop_from_x, _swoop_to_x, smoothstep(0.0, 1.0, t))
            position.y = home.y + sin(PI * t) * swoop_depth
            if t >= 1.0:
                _hover_x = _swoop_to_x
                _time = 0.0
                _start(Action.HOVER)


func _start(action: Action) -> void:
    _action = action
    _action_time = 0.0


func _hover() -> void:
    var bounds := get_viewport_rect()
    var x := _hover_x + sin(_time * TAU * hover_frequency) * hover_sway
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * TAU * 0.3) * 15.0


func _fire_rocket() -> void:
    if _action != Action.HOVER:
        return

    match _attack % 4:
        0, 2:
            _start(Action.INHALE)
        1:
            _rain()
        _:
            _start_swoop()
    _attack += 1


func _start_breath() -> void:
    var aim := _rocket_direction()
    _breath_center = aim if aim != Vector2.ZERO else Vector2.DOWN
    _breath_from = -1.0 if randf() < 0.5 else 1.0
    _breath_cooldown = 0.0
    _breath_shots = 0
    _breaths += 1
    _start(Action.BREATHE)


func _breath_duration() -> float:
    return breath_duration * (1.5 if is_in_a_hurry() else 1.0)


func _breathe(delta: float) -> void:
    var duration := _breath_duration()
    var t := clampf(_action_time / duration, 0.0, 1.0)

    # NOTE (mristin):
    # The breath sweeps across the target once, or there and back again when
    # the dragon is in a hurry.
    var sweep := lerpf(_breath_from, -_breath_from, t)
    if is_in_a_hurry():
        sweep = _breath_from * cos(TAU * 0.75 * t)
    _breath_aim = _breath_center.rotated(sweep * breath_sweep * 0.5)

    _breath_cooldown -= delta
    if _breath_cooldown <= 0.0:
        _breath_cooldown = breath_interval
        _breath_shots += 1
        if _breath_shots % puff_length != 0:
            _launch_rocket_from(_mouth(), _breath_aim, breath_speed)

    if t >= 1.0:
        _start(Action.HOVER)


func _rain() -> void:
    for i in range(rain_count):
        var t := (i / float(maxi(1, rain_count - 1))) - 0.5
        var direction := Vector2.UP.rotated(t * 1.1 + randf_range(-0.12, 0.12))
        var fireball := _launch_rocket_from(_mouth(), direction, rain_speed)
        if fireball != null:
            fireball.fall_acceleration = rain_fall_acceleration


func _start_swoop() -> void:
    var bounds := get_viewport_rect()
    _swoop_from_x = position.x
    if position.x < bounds.get_center().x:
        _swoop_to_x = bounds.end.x - margin - randf() * 200.0
    else:
        _swoop_to_x = bounds.position.x + margin + randf() * 200.0
    _swoops += 1
    _start(Action.SWOOP)


## Return the head's position relative to the dragon.
func _head() -> Vector2:
    var head := Vector2(0, radius * 0.32)
    if _action == Action.INHALE:
        # NOTE (mristin):
        # The dragon rears its head while taking the deep breath.
        head.y -= radius * 0.12 * clampf(_action_time / inhale_duration, 0.0, 1.0)
    elif _action == Action.BREATHE:
        head += _breath_aim * radius * 0.08
    return head


func _mouth() -> Vector2:
    return global_position + _head() + Vector2(0, radius * 0.14)


func _energy_bar_y() -> float:
    return radius * 0.62


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var red := Color(0.85, 0.22, 0.18).lerp(white, flash)
    var dark_red := Color(0.6, 0.12, 0.12).lerp(white, flash)
    var gold := Color(1.0, 0.78, 0.35).lerp(white, flash)

    # NOTE (mristin):
    # The tail swishes above the body.
    var swish := sin(_time * 2.0) * r * 0.25
    var tail := PackedVector2Array()
    for j in range(10):
        var t := j / 9.0
        tail.append(Vector2(swish * t * t, -r * 0.2 - t * r * 0.7))
    draw_polyline(tail, red, r * 0.1, true)
    draw_colored_polygon(
        PackedVector2Array(
            [
                tail[-1] + Vector2(-r * 0.1, 0),
                tail[-1] + Vector2(0, -r * 0.15),
                tail[-1] + Vector2(r * 0.1, 0),
            ]
        ),
        gold
    )

    # The big wings flap slowly, faster while swooping.
    var flap := sin(_time * (9.0 if _action == Action.SWOOP else 4.0))
    for side: float in [-1.0, 1.0]:
        var wing := PackedVector2Array(
            [
                Vector2(side * r * 0.2, -r * 0.25),
                Vector2(side * r * 0.75, -r * (0.75 + 0.2 * flap)),
                Vector2(side * r * 1.15, -r * (0.55 + 0.25 * flap)),
                Vector2(side * r * 0.95, -r * 0.2),
                Vector2(side * r * 0.75, -r * (0.05 - 0.1 * flap)),
                Vector2(side * r * 0.5, r * 0.0),
                Vector2(side * r * 0.25, r * 0.05),
            ]
        )
        draw_colored_polygon(wing, dark_red)
        draw_line(
            Vector2(side * r * 0.2, -r * 0.25),
            Vector2(side * r * 1.15, -r * (0.55 + 0.25 * flap)),
            red,
            r * 0.04
        )

    var body := PackedVector2Array()
    for i in range(32):
        var angle := TAU * i / 32.0
        body.append(Vector2(cos(angle) * r * 0.4, sin(angle) * r * 0.42 - r * 0.08))
    draw_colored_polygon(body, red)
    for i in range(4):
        var y := -r * 0.25 + i * r * 0.13
        draw_line(Vector2(-r * 0.18, y), Vector2(r * 0.18, y), gold, r * 0.07)

    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.3, r * 0.25), r * 0.09, red)

    var head := _head()

    # NOTE (mristin):
    # The smoke puffs from the nostrils drift up.
    for k in range(3):
        var age := fmod(_time * 0.8 + k / 3.0, 1.0)
        for side: float in [-1.0, 1.0]:
            draw_circle(
                head + Vector2(side * r * (0.06 + 0.05 * age), r * 0.05 - age * r * 0.35),
                r * (0.03 + 0.04 * age),
                Color(0.7, 0.7, 0.7, 0.35 * (1.0 - age))
            )

    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    head + Vector2(side * r * 0.1, -r * 0.1),
                    head + Vector2(side * r * 0.28, -r * 0.3),
                    head + Vector2(side * r * 0.2, -r * 0.05),
                ]
            ),
            gold
        )
    draw_circle(head, r * 0.2, red)
    draw_circle(head + Vector2(0, r * 0.12), r * 0.14, Color(0.95, 0.4, 0.3).lerp(white, flash))

    var glow := 0.0
    if _action == Action.INHALE:
        glow = clampf(_action_time / inhale_duration, 0.0, 1.0)
    elif _action == Action.BREATHE:
        glow = 1.0
    if glow > 0.0:
        var mouth := head + Vector2(0, r * 0.16)
        draw_circle(mouth, r * (0.05 + 0.1 * glow), Color(1.0, 0.75, 0.25, 0.5 + 0.5 * glow))
        draw_circle(mouth, r * 0.04 * glow, Color(1.0, 1.0, 0.8))

    for side: float in [-1.0, 1.0]:
        draw_circle(head + Vector2(side * r * 0.05, r * 0.15), r * 0.018, Color(0.3, 0.05, 0.05))
        var eye := head + Vector2(side * r * 0.1, -r * 0.04)
        draw_circle(eye, r * 0.055, Color(1.0, 0.95, 0.6).lerp(white, flash))
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.025, Color(0.15, 0.05, 0.05))
        draw_line(
            eye + Vector2(-side * r * 0.07, -r * 0.08),
            eye + Vector2(side * r * 0.06, -r * 0.05),
            dark_red,
            r * 0.025
        )
