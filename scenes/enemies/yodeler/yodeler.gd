class_name Yodeler

extends Enemy

## A jolly yodeler on a paraglider with a red wing and a white cross. He glides
## from side to side across the upper part of the screen, banking at the turns
## and bobbing on the wind. He yodels a short tune of notes at the nearest
## spaceship, and the mountains echo it back: soft rings show at the far side
## of the screen, and a moment later the echo of the tune comes from there,
## aimed at the nearest spaceship again. So the players have to watch both
## sides.

## How fast he glides to the sides, in pixels per second, and how far from
## the screen edges he turns.
@export var glide_speed: float = 170.0
@export var turn_margin: float = 220.0

## How much he bobs up and down on the wind, in pixels, and how often.
@export var bob_height: float = 50.0
@export var bob_frequency: float = 0.3

## The tune: how many notes, and the seconds between them.
@export var tune_size: int = 3
@export var tune_interval: float = 0.18

## How long the echo takes to come back, in seconds, and how fast its notes
## fly.
@export var echo_delay: float = 1.4
@export var echo_speed: float = 260.0

## How far from the screen edge the echo comes from, in pixels.
@export var echo_margin: float = 90.0

## How many times he yodeled so far, and how many echoes came back, e.g.,
## for the tests.
var yodels: int = 0
var echoes: int = 0

var _time: float = 0.0
var _heading: float = 1.0
var _bank: float = 0.0
var _descending: bool = true

var _tune_left: int = 0
var _tune_cooldown: float = 0.0
var _singing: float = 0.0

## The echo: where it comes from, how long until it comes, and how many of its
## notes are still to come.
var _echo_at: Vector2 = Vector2.ZERO
var _echo_left: float = -1.0
var _echo_notes: int = 0
var _echo_cooldown: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.NOTE


## Return true while the echo is on its way back, i.e., its rings show.
func is_echo_coming() -> bool:
    return is_alive() and (_echo_left > 0.0 or _echo_notes > 0)


## Return where the echo comes from, in the coordinates of the level.
func echo_position() -> Vector2:
    return _echo_at


func _enter() -> void:
    super()
    _heading = 1.0 if home.x < get_viewport_rect().get_center().x else -1.0


func _may_fire() -> bool:
    return not _descending and _tune_left == 0 and not is_echo_coming()


func _move(delta: float) -> void:
    _time += delta
    _singing = maxf(0.0, _singing - delta)

    if _descending:
        position.y = minf(position.y + 200.0 * delta, home.y)
        _descending = position.y < home.y
        _time = 0.0
        return

    var bounds := get_viewport_rect()
    if position.x > bounds.end.x - turn_margin:
        _heading = -1.0
    elif position.x < bounds.position.x + turn_margin:
        _heading = 1.0
    _bank = move_toward(_bank, _heading, delta * 1.2)
    position.x += _bank * glide_speed * delta
    position.y = home.y + sin(_time * TAU * bob_frequency) * bob_height

    _sing(delta)
    _echo(delta)


func _fire_rocket() -> void:
    yodels += 1
    _tune_left = tune_size
    _tune_cooldown = 0.0

    # NOTE (mristin):
    # The echo comes from the mountains at the far side of the screen.
    var bounds := get_viewport_rect()
    var far_left := global_position.x > bounds.get_center().x
    _echo_at = Vector2(
        bounds.position.x + echo_margin if far_left else bounds.end.x - echo_margin,
        clampf(global_position.y + 120.0, bounds.position.y + 150.0, bounds.end.y * 0.45)
    )
    _echo_left = echo_delay + tune_size * tune_interval


func _sing(delta: float) -> void:
    if _tune_left <= 0:
        return
    _tune_cooldown -= delta
    if _tune_cooldown > 0.0:
        return
    _tune_cooldown = tune_interval
    _tune_left -= 1
    _singing = 0.3
    var aim := _rocket_direction()
    if aim != Vector2.ZERO:
        _launch_rocket(aim, rocket_speed)


func _echo(delta: float) -> void:
    if _echo_left > 0.0:
        _echo_left -= delta
        if _echo_left <= 0.0:
            echoes += 1
            _echo_notes = tune_size
            _echo_cooldown = 0.0
        return

    if _echo_notes <= 0:
        return
    _echo_cooldown -= delta
    if _echo_cooldown > 0.0:
        return
    _echo_cooldown = tune_interval
    _echo_notes -= 1
    var target := _nearest_spaceship()
    if target != null:
        _launch_rocket_from(_echo_at, _echo_at.direction_to(target.global_position), echo_speed)


func _energy_bar_y() -> float:
    return radius * 1.08


func _draw() -> void:
    if is_echo_coming():
        _draw_echo()
    super()


## Draw the rings of the echo at the far side of the screen.
func _draw_echo() -> void:
    var at := to_local(_echo_at)
    var r := radius
    var progress := 1.0 - clampf(_echo_left / echo_delay, 0.0, 1.0)
    # NOTE (mristin):
    # The rings close in on the spot where the echo comes from.
    for i in range(3):
        var t := fmod(_time * 1.2 + i / 3.0, 1.0)
        draw_arc(
            at,
            r * (0.25 + 0.8 * (1.0 - t)),
            0.0,
            TAU,
            32,
            Color(1.0, 0.9, 0.55, 0.3 + 0.5 * progress * t),
            r * 0.05,
            true
        )
    draw_circle(at, r * 0.25 * (0.5 + progress), Color(1.0, 0.9, 0.55, 0.3))


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var red := Color(0.85, 0.18, 0.15).lerp(white, flash)
    var skin := Color(1.0, 0.82, 0.68).lerp(white, flash)
    var shirt := Color(0.95, 0.95, 0.9).lerp(white, flash)
    var vest := Color(0.2, 0.35, 0.25).lerp(white, flash)
    var hat := Color(0.25, 0.4, 0.3).lerp(white, flash)
    var dark := Color(0.15, 0.1, 0.08)
    var lines := Color(0.35, 0.3, 0.3)

    var tilt := _bank * 0.15

    # NOTE (mristin):
    # The wing of the paraglider arches above him, red with a white cross,
    # and the lines lead down to his harness.
    draw_set_transform(Vector2.ZERO, tilt)
    var wing := PackedVector2Array()
    for i in range(21):
        var a := PI + PI * i / 20.0
        wing.append(Vector2(cos(a) * r * 1.0, -r * 0.5 + sin(a) * r * 0.5))
    for i in range(21):
        var a := TAU - PI * i / 20.0
        wing.append(Vector2(cos(a) * r * 0.95, -r * 0.5 + sin(a) * r * 0.2))
    draw_colored_polygon(wing, red)
    for i in range(1, 6):
        var u := lerpf(-0.8, 0.8, i / 6.0)
        draw_line(
            Vector2(u * r, -r * (0.5 + 0.5 * sqrt(1.0 - u * u))),
            Vector2(u * r, -r * (0.5 + 0.2 * sqrt(maxf(0.0, 1.0 - u * u / 0.9)))),
            Color(0.6, 0.1, 0.1),
            r * 0.02
        )
    var cross := Vector2(0, -r * 0.84)
    draw_rect(Rect2(cross + Vector2(-r * 0.12, -r * 0.04), Vector2(r * 0.24, r * 0.08)), white)
    draw_rect(Rect2(cross + Vector2(-r * 0.04, -r * 0.12), Vector2(r * 0.08, r * 0.24)), white)
    for side: float in [-1.0, 1.0]:
        draw_line(Vector2(side * r * 0.93, -r * 0.5), Vector2(side * r * 0.2, r * 0.3), lines, 2.0)
        draw_line(
            Vector2(side * r * 0.45, -r * 0.68), Vector2(side * r * 0.15, r * 0.3), lines, 2.0
        )
    draw_set_transform(Vector2.ZERO, 0.0)

    # The yodeler in his seat: the legs dangling, the white shirt with the
    # green vest, the face and the green hat with a feather.
    draw_set_transform(Vector2(0, r * 0.05), 0.0, Vector2(1.45, 1.45))
    var swing := sin(_time * 2.0) * r * 0.03
    for side: float in [-1.0, 1.0]:
        draw_line(
            Vector2(side * r * 0.1, r * 0.4),
            Vector2(side * r * 0.14 + swing, r * 0.62),
            vest,
            r * 0.09
        )
        draw_circle(Vector2(side * r * 0.14 + swing, r * 0.64), r * 0.06, dark)
    draw_circle(Vector2(0, r * 0.3), r * 0.2, shirt)
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.18, r * 0.2),
                Vector2(-r * 0.05, r * 0.2),
                Vector2(-r * 0.08, r * 0.46),
                Vector2(-r * 0.16, r * 0.42),
            ]
        ),
        vest
    )
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(r * 0.18, r * 0.2),
                Vector2(r * 0.05, r * 0.2),
                Vector2(r * 0.08, r * 0.46),
                Vector2(r * 0.16, r * 0.42),
            ]
        ),
        vest
    )
    for side: float in [-1.0, 1.0]:
        # The arms wave while he yodels.
        var up := r * 0.12 if _singing > 0.0 else 0.0
        draw_line(
            Vector2(side * r * 0.17, r * 0.22),
            Vector2(side * r * 0.3, r * 0.1 - up),
            shirt,
            r * 0.07
        )
        draw_circle(Vector2(side * r * 0.3, r * 0.1 - up), r * 0.05, skin)

    var face := Vector2(0, r * 0.02)
    draw_circle(face, r * 0.19, skin)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.07, -r * 0.02)
        if _singing > 0.0:
            # He closes his eyes, happily, while he yodels.
            draw_arc(eye, r * 0.035, PI + 0.3, TAU - 0.3, 8, dark, r * 0.02)
        else:
            draw_circle(eye, r * 0.035, dark)
            draw_circle(eye + Vector2(-r * 0.01, -r * 0.012), r * 0.012, white)
        draw_circle(face + Vector2(side * r * 0.12, r * 0.06), r * 0.035, Color(1.0, 0.5, 0.5, 0.7))
    if _singing > 0.0 or _tune_left > 0:
        draw_circle(face + Vector2(0, r * 0.09), r * 0.05, Color(0.5, 0.15, 0.15))
    else:
        draw_arc(face + Vector2(0, r * 0.05), r * 0.06, 0.3, PI - 0.3, 8, dark, r * 0.02)
    # The mustache.
    for side: float in [-1.0, 1.0]:
        draw_circle(face + Vector2(side * r * 0.04, r * 0.045), r * 0.035, Color(0.45, 0.3, 0.2))

    var brim := face + Vector2(0, -r * 0.13)
    draw_rect(Rect2(brim + Vector2(-r * 0.24, -r * 0.03), Vector2(r * 0.48, r * 0.06)), hat)
    draw_colored_polygon(
        PackedVector2Array(
            [
                brim + Vector2(-r * 0.14, 0),
                brim + Vector2(-r * 0.1, -r * 0.16),
                brim + Vector2(r * 0.1, -r * 0.16),
                brim + Vector2(r * 0.14, 0),
            ]
        ),
        hat
    )
    draw_rect(Rect2(brim + Vector2(-r * 0.14, -r * 0.05), Vector2(r * 0.28, r * 0.04)), red)
    draw_line(
        brim + Vector2(r * 0.1, -r * 0.08), brim + Vector2(r * 0.24, -r * 0.3), white, r * 0.03
    )
    draw_set_transform(Vector2.ZERO, 0.0)
