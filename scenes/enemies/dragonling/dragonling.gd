class_name Dragonling

extends Enemy

## A little green dragon: it flies in loops around its place in the level.
## Before it breathes, it takes a deep breath, and its mouth glows; then it
## breathes a short stream of fireballs at the nearest spaceship.

## How far and how fast the dragonling loops around its place.
@export var loop_width: float = 260.0
@export var loop_height: float = 90.0
@export var loop_speed: float = 0.9

@export var descent_speed: float = 220.0

## How long it takes a deep breath before breathing, in seconds.
@export var inhale_duration: float = 0.6

## The stream: the number of fireballs and the seconds between them.
@export var stream_size: int = 3
@export var stream_interval: float = 0.18

var _time: float = 0.0
var _descending: bool = true
var _loop_t: float = 0.0
var _inhale_left: float = 0.0
var _stream_left: int = 0
var _stream_cooldown: float = 0.0
var _aim: Vector2 = Vector2.DOWN


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
        return

    _loop_t += loop_speed * delta
    var bounds := get_viewport_rect()
    position.x = clampf(
        home.x + sin(_loop_t) * loop_width, bounds.position.x + radius, bounds.end.x - radius
    )
    position.y = home.y + sin(_loop_t * 2.0) * loop_height

    if _inhale_left > 0.0:
        _inhale_left -= delta
        if _inhale_left <= 0.0:
            _stream_left = stream_size
            _stream_cooldown = 0.0
            var aim := _rocket_direction()
            _aim = aim if aim != Vector2.ZERO else Vector2.DOWN

    if _stream_left > 0:
        _stream_cooldown -= delta
        if _stream_cooldown <= 0.0:
            _stream_cooldown = stream_interval
            _stream_left -= 1
            _launch_rocket(_aim, rocket_speed)


func _fire_rocket() -> void:
    if _descending or _inhale_left > 0.0 or _stream_left > 0:
        return
    _inhale_left = inhale_duration


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var green := Color(0.35, 0.75, 0.35).lerp(white, flash)
    var belly := Color(0.95, 0.9, 0.55).lerp(white, flash)
    var wing := Color(0.25, 0.55, 0.3, 0.9).lerp(white, flash)

    var flap := sin(_time * 10.0)
    for side: float in [-1.0, 1.0]:
        var wing_shape := PackedVector2Array(
            [
                Vector2(side * r * 0.2, -r * 0.15),
                Vector2(side * r * 0.95, -r * (0.55 + 0.25 * flap)),
                Vector2(side * r * 0.8, -r * 0.05),
                Vector2(side * r * 0.65, r * 0.05 - r * 0.1 * flap),
                Vector2(side * r * 0.25, r * 0.15),
            ]
        )
        draw_colored_polygon(wing_shape, wing)

    var tail_wag := sin(_time * 5.0) * r * 0.15
    draw_line(Vector2(0, -r * 0.2), Vector2(tail_wag, -r * 0.75), green, r * 0.12, true)
    draw_circle(Vector2(tail_wag, -r * 0.75), r * 0.07, Color(1.0, 0.5, 0.3).lerp(white, flash))

    draw_circle(Vector2(0, -r * 0.05), r * 0.32, green)
    draw_circle(Vector2(0, r * 0.02), r * 0.2, belly)

    # NOTE (mristin):
    # The head looks down at the spaceships; the mouth glows while inhaling
    # and breathing.
    var head := Vector2(0, r * 0.35)
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    head + Vector2(side * r * 0.12, -r * 0.15),
                    head + Vector2(side * r * 0.25, -r * 0.35),
                    head + Vector2(side * r * 0.2, -r * 0.1),
                ]
            ),
            belly
        )
    draw_circle(head, r * 0.24, green)
    var glow := 0.0
    if _inhale_left > 0.0:
        glow = 1.0 - _inhale_left / inhale_duration
    elif _stream_left > 0:
        glow = 1.0
    if glow > 0.0:
        draw_circle(
            head + Vector2(0, r * 0.15), r * (0.08 + 0.1 * glow), Color(1.0, 0.7, 0.2, glow)
        )
    draw_circle(head + Vector2(0, r * 0.12), r * 0.11, belly)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.11, -r * 0.04)
        draw_circle(eye, r * 0.07, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.035, Color(0.1, 0.15, 0.05))
