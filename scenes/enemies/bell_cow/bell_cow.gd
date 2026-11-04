class_name BellCow

extends GroundEnemy

## A happy alpine cow with a big bell, grazing on the meadow. It ambles slowly
## from side to side with the ground. Before it moos, it shakes its head so
## that the bell swings and rings, and soft rings of sound spread from it;
## then it moos out a ring of musical notes all around. Every other time, it
## rings a short tune of three notes at the nearest spaceship instead.
##
## The cow stays on the ground, so the spaceships fly over it.

## How fast the cow ambles to the sides, in pixels per second.
@export var amble_speed: float = 45.0

## How long the bell rings before the moo, in seconds.
@export var ring_duration: float = 1.0

## The ring of notes: how many and how fast.
@export var ring_size: int = 6
@export var ring_speed: float = 230.0

## The tune: how many notes, aimed at the nearest spaceship, and the seconds
## between them.
@export var tune_size: int = 3
@export var tune_interval: float = 0.18

## How many rings of notes the cow mooed so far, e.g., for the tests.
var rings_mooed: int = 0

## How many tunes the cow rang so far, e.g., for the tests.
var tunes_rung: int = 0

var _time: float = 0.0
var _heading: float = 1.0
var _turn_left: float = 0.0
var _ringing_left: float = 0.0
var _attack: int = 0
var _tune_left: int = 0
var _tune_cooldown: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.NOTE
    _heading = -1.0 if randf() < 0.5 else 1.0
    _turn_left = randf_range(2.0, 4.0)


## Return true while the bell rings, before the moo.
func is_ringing() -> bool:
    return _ringing_left > 0.0


func _walk(delta: float) -> void:
    _time += delta

    if is_ringing():
        _ringing_left -= delta
        if _ringing_left <= 0.0:
            _moo()
        return

    if _tune_left > 0:
        _tune_cooldown -= delta
        if _tune_cooldown <= 0.0:
            _tune_cooldown = tune_interval
            _tune_left -= 1
            var aim := _rocket_direction()
            if aim != Vector2.ZERO:
                _launch_rocket(aim, rocket_speed)

    _turn_left -= delta
    var bounds := get_viewport_rect()
    if (
        _turn_left <= 0.0
        or position.x < bounds.position.x + margin + 10.0 and _heading < 0.0
        or position.x > bounds.end.x - margin - 10.0 and _heading > 0.0
    ):
        _heading = -_heading
        _turn_left = randf_range(2.5, 4.5)
    position.x += _heading * amble_speed * delta


func _fire_rocket() -> void:
    if is_ringing() or _tune_left > 0:
        return

    _attack += 1
    if _attack % 2 == 1:
        _ringing_left = ring_duration
    else:
        tunes_rung += 1
        _tune_left = tune_size
        _tune_cooldown = 0.0


func _moo() -> void:
    _ringing_left = 0.0
    rings_mooed += 1
    var bell := global_position + Vector2(0, radius * 0.45)
    Poof.spawn(self, bell, radius * 0.4, Color(1.0, 0.9, 0.5))
    var start := randf() * TAU
    for i in range(ring_size):
        _launch_rocket_from(bell, Vector2.RIGHT.rotated(start + TAU * i / ring_size), ring_speed)


func _energy_bar_y() -> float:
    return radius * 0.78


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var hide := Color(0.95, 0.93, 0.88).lerp(white, flash)
    var patch := Color(0.55, 0.33, 0.2).lerp(white, flash)
    var snout := Color(1.0, 0.72, 0.7).lerp(white, flash)
    var horn := Color(0.95, 0.88, 0.7).lerp(white, flash)
    var dark := Color(0.2, 0.12, 0.1)

    var ringing := is_ringing()
    var shake := sin(_time * 30.0) * 0.12 if ringing else sin(_time * 1.5) * 0.04

    # NOTE (mristin):
    # The soft rings of sound spread from the bell while it rings, so that
    # the players see the moo coming.
    if ringing:
        var progress := 1.0 - _ringing_left / ring_duration
        for i in range(2):
            var t := fmod(progress * 2.0 + i * 0.5, 1.0)
            draw_arc(
                Vector2(0, r * 0.45),
                r * (0.4 + 0.8 * t),
                0.0,
                TAU,
                40,
                Color(1.0, 0.9, 0.5, 0.55 * (1.0 - t)),
                r * 0.05,
                true
            )

    # The shadow, the body and the legs, seen from the front.
    draw_circle(Vector2(r * 0.06, r * 0.5), r * 0.55, Color(0, 0, 0, 0.25))
    for side: float in [-1.0, 1.0]:
        var step := sin(_time * 4.0 + side) * r * 0.03
        draw_rect(
            Rect2(Vector2(side * r * 0.32 - r * 0.08, r * 0.2 + step), Vector2(r * 0.16, r * 0.42)),
            hide
        )
        draw_rect(
            Rect2(Vector2(side * r * 0.32 - r * 0.08, r * 0.54 + step), Vector2(r * 0.16, r * 0.1)),
            dark
        )
    draw_circle(Vector2(0, r * 0.1), r * 0.5, hide)
    draw_circle(Vector2(-r * 0.28, r * 0.05), r * 0.17, patch)
    draw_circle(Vector2(r * 0.3, r * 0.28), r * 0.13, patch)

    # The head with the horns, the ears and the big snout.
    draw_set_transform(Vector2(0, -r * 0.2), shake)
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(side * r * 0.2, -r * 0.28),
                    Vector2(side * r * 0.45, -r * 0.5),
                    Vector2(side * r * 0.3, -r * 0.22),
                ]
            ),
            horn
        )
        draw_set_transform(
            Vector2(0, -r * 0.2) + Vector2(side * r * 0.4, -r * 0.1).rotated(shake),
            shake + side * 0.5
        )
        draw_circle(Vector2.ZERO, r * 0.12, hide)
        draw_circle(Vector2.ZERO, r * 0.07, snout)
        draw_set_transform(Vector2(0, -r * 0.2), shake)
    draw_circle(Vector2.ZERO, r * 0.33, hide)
    draw_circle(Vector2(r * 0.15, -r * 0.18), r * 0.12, patch)
    draw_circle(Vector2(0, r * 0.18), r * 0.21, snout)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.08, r * 0.17), r * 0.03, Color(0.6, 0.3, 0.3))
        var eye := Vector2(side * r * 0.13, -r * 0.04)
        draw_circle(eye, r * 0.085, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.05, dark)
        draw_circle(eye + Vector2(-r * 0.02, -r * 0.01), r * 0.02, white)
        draw_circle(Vector2(side * r * 0.24, r * 0.08), r * 0.04, Color(1.0, 0.5, 0.55, 0.7))
    if ringing:
        draw_circle(Vector2(0, r * 0.27), r * 0.06, Color(0.5, 0.2, 0.2))
    else:
        draw_arc(Vector2(0, r * 0.22), r * 0.08, 0.3, PI - 0.3, 10, Color(0.5, 0.2, 0.2), r * 0.025)

    # The red collar with the little white crosses, and the big bell.
    var collar := Color(0.85, 0.2, 0.2).lerp(white, flash)
    draw_arc(Vector2(0, r * 0.05), r * 0.36, 0.5, PI - 0.5, 16, collar, r * 0.08)
    var swing := sin(_time * 22.0) * 0.5 if ringing else sin(_time * 2.0) * 0.1
    draw_set_transform(Vector2(0, r * 0.38).rotated(shake), shake + swing)
    var gold := Color(1.0, 0.78, 0.3).lerp(white, flash)
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.09, 0),
                Vector2(r * 0.09, 0),
                Vector2(r * 0.16, r * 0.22),
                Vector2(-r * 0.16, r * 0.22),
            ]
        ),
        gold
    )
    draw_rect(
        Rect2(Vector2(-r * 0.18, r * 0.2), Vector2(r * 0.36, r * 0.05)), Color(0.85, 0.6, 0.2)
    )
    draw_circle(Vector2(0, r * 0.27), r * 0.04, Color(0.6, 0.4, 0.15))
    draw_set_transform(Vector2.ZERO, 0.0)
