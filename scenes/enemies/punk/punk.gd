class_name Punk

extends Enemy

## A friendly punk with a rainbow mohawk and a studded leather jacket, flying
## a shopping cart with a little jet at the back. He cruises along his lane
## and, every now and then, shows off with a loop-the-loop. Between the stunts,
## he shakes his spray can and sprays a sweeping stream of paint blobs across
## the nearest spaceship.

enum Phase { ARRIVING, CRUISING, LOOPING }

@export var arrive_speed: float = 260.0
@export var cruise_speed: float = 220.0

## The loop-the-loop: how big, how long it takes, and how long he cruises
## between the loops, in seconds.
@export var loop_radius: float = 120.0
@export var loop_duration: float = 1.8
@export var min_cruise_duration: float = 3.0
@export var max_cruise_duration: float = 4.5

## He turns around this far from the screen edges.
@export var margin: float = 170.0

## The spray: the number of blobs, the seconds between them, and how far
## the stream sweeps, in radians.
@export var spray_count: int = 3
@export var spray_interval: float = 0.15
@export var spray_sweep: float = 0.5

var _phase: Phase = Phase.ARRIVING
var _time: float = 0.0
var _phase_left: float = 0.0
var _direction: float = 1.0
var _loop_center: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _loops: int = 0

var _spray_left: int = 0
var _spray_cooldown: float = 0.0
var _spray_aim: Vector2 = Vector2.DOWN


## Return how many loop-the-loops the punk has flown so far.
func loops() -> int:
    return _loops


func is_looping() -> bool:
    return _phase == Phase.LOOPING


func _move(delta: float) -> void:
    _time += delta
    var bounds := get_viewport_rect()

    match _phase:
        Phase.ARRIVING:
            position = position.move_toward(home, arrive_speed * delta)
            if position.is_equal_approx(home):
                _phase = Phase.CRUISING
                _phase_left = randf_range(min_cruise_duration, max_cruise_duration)
        Phase.CRUISING:
            position.x += _direction * cruise_speed * delta
            position.y = home.y + sin(_time * 1.5) * radius * 0.15
            if position.x < bounds.position.x + margin:
                _direction = 1.0
            elif position.x > bounds.end.x - margin:
                _direction = -1.0
            _phase_left -= delta
            if _phase_left <= 0.0 and _spray_left == 0:
                _start_loop()
        Phase.LOOPING:
            _phase_left -= delta
            var t := clampf(1.0 - _phase_left / loop_duration, 0.0, 1.0)
            _loop_center.x += _direction * cruise_speed * 0.4 * delta
            _loop_center.x = clampf(
                _loop_center.x, bounds.position.x + margin, bounds.end.x - margin
            )
            # NOTE (mristin):
            # We start at the bottom of the circle and go up the front.
            _spin = -_direction * TAU * smoothstep(0.0, 1.0, t)
            position = _loop_center + Vector2(0, loop_radius).rotated(_spin)
            if _phase_left <= 0.0:
                _spin = 0.0
                _phase = Phase.CRUISING
                _phase_left = randf_range(min_cruise_duration, max_cruise_duration)

    _update_spray(delta)


func _start_loop() -> void:
    _phase = Phase.LOOPING
    _phase_left = loop_duration
    _loop_center = position - Vector2(0, loop_radius)
    _loops += 1


func _may_fire() -> bool:
    return _phase == Phase.CRUISING and _spray_left == 0


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    _spray_aim = aim
    _spray_left = spray_count
    _spray_cooldown = 0.0


func _update_spray(delta: float) -> void:
    if _spray_left == 0:
        return
    _spray_cooldown -= delta
    if _spray_cooldown > 0.0:
        return
    _spray_cooldown = spray_interval
    var done := spray_count - _spray_left
    var angle := (done / float(maxi(1, spray_count - 1)) - 0.5) * spray_sweep * _direction
    _launch_rocket(_spray_aim.rotated(angle), rocket_speed)
    _spray_left -= 1


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    draw_set_transform(Vector2.ZERO, _spin, Vector2(_direction, 1.0))

    # NOTE (mristin):
    # The jet at the back of the cart puffs little clouds, not fire.
    for k in range(3):
        var puff := fmod(_time * 2.5 + k / 3.0, 1.0)
        draw_circle(
            Vector2(-r * (0.75 + puff * 0.5), r * 0.1 + sin(k * 2.0) * r * 0.05),
            r * (0.08 + puff * 0.1),
            Color(0.85, 0.9, 1.0, 0.6 * (1.0 - puff))
        )
    draw_rect(
        Rect2(Vector2(-r * 0.78, -r * 0.02), Vector2(r * 0.22, r * 0.22)),
        Color(0.55, 0.6, 0.7).lerp(white, flash)
    )
    draw_circle(Vector2(-r * 0.78, r * 0.09), r * 0.08, Color(0.5, 0.85, 1.0))

    # The punk sits in the cart: the mohawk, the head and the jacket.
    var head := Vector2(r * 0.02, -r * 0.5)
    var jacket := Color(0.18, 0.18, 0.22).lerp(white, flash)
    draw_rect(Rect2(Vector2(-r * 0.22, -r * 0.35), Vector2(r * 0.44, r * 0.35)), jacket)
    for k in range(4):
        draw_circle(Vector2(-r * 0.15 + k * r * 0.1, -r * 0.3), r * 0.025, Color(0.9, 0.9, 0.95))
    var skin := Color(1.0, 0.8, 0.65).lerp(white, flash)
    draw_line(Vector2(r * 0.15, -r * 0.25), Vector2(r * 0.42, -r * 0.42), jacket, r * 0.1)
    var can := Vector2(r * 0.45, -r * 0.5)
    draw_rect(
        Rect2(can - Vector2(r * 0.06, r * 0.1), Vector2(r * 0.12, r * 0.2)),
        Color(0.3, 0.95, 0.6).lerp(white, flash)
    )
    draw_rect(
        Rect2(can - Vector2(r * 0.03, r * 0.15), Vector2(r * 0.06, r * 0.05)), Color(0.9, 0.9, 0.9)
    )

    var spikes: Array[Color] = [
        Color(1.0, 0.3, 0.4),
        Color(1.0, 0.65, 0.2),
        Color(1.0, 0.95, 0.3),
        Color(0.4, 0.9, 0.4),
        Color(0.35, 0.7, 1.0),
        Color(0.75, 0.45, 1.0)
    ]
    for k in range(6):
        var angle := lerpf(-2.6, -0.55, k / 5.0)
        var base := head + Vector2.from_angle(angle) * r * 0.18
        var tip := head + Vector2.from_angle(angle) * r * 0.48 + Vector2(-r * 0.06, 0)
        draw_colored_polygon(
            PackedVector2Array(
                [
                    base + Vector2.from_angle(angle + PI / 2.0) * r * 0.06,
                    tip,
                    base - Vector2.from_angle(angle + PI / 2.0) * r * 0.06
                ]
            ),
            spikes[k].lerp(white, flash)
        )
    draw_circle(head, r * 0.22, skin)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.08 + r * 0.03, -r * 0.02)
        draw_circle(eye, r * 0.06, white)
        draw_circle(eye + Vector2(r * 0.015, 0), r * 0.03, Color(0.1, 0.05, 0.1))
    draw_arc(
        head + Vector2(r * 0.03, r * 0.07),
        r * 0.09,
        0.2,
        PI - 0.2,
        8,
        Color(0.4, 0.1, 0.15),
        r * 0.03
    )
    draw_circle(head + Vector2(r * 0.17, r * 0.0), r * 0.025, Color(0.85, 0.85, 0.9))

    # The shopping cart: the wire basket, the handle and the little wheels.
    var basket := PackedVector2Array(
        [
            Vector2(-r * 0.6, -r * 0.2),
            Vector2(r * 0.65, -r * 0.2),
            Vector2(r * 0.5, r * 0.3),
            Vector2(-r * 0.5, r * 0.3)
        ]
    )
    var wire := Color(0.85, 0.88, 0.95).lerp(white, flash)
    draw_colored_polygon(basket, Color(0.6, 0.65, 0.75, 0.55))
    draw_polyline(basket + PackedVector2Array([basket[0]]), wire, r * 0.04, true)
    for k in range(1, 6):
        var t := k / 6.0
        draw_line(basket[0].lerp(basket[1], t), basket[3].lerp(basket[2], t), wire, r * 0.02)
    draw_line(basket[0].lerp(basket[3], 0.5), basket[1].lerp(basket[2], 0.5), wire, r * 0.02)
    draw_line(Vector2(-r * 0.6, -r * 0.2), Vector2(-r * 0.75, -r * 0.4), wire, r * 0.05)
    draw_line(
        Vector2(-r * 0.85, -r * 0.4),
        Vector2(-r * 0.6, -r * 0.4),
        Color(1.0, 0.35, 0.35).lerp(white, flash),
        r * 0.07
    )
    draw_line(Vector2(-r * 0.45, r * 0.3), Vector2(r * 0.45, r * 0.3), wire, r * 0.04)
    for x: float in [-0.38, 0.38]:
        draw_circle(Vector2(x * r, r * 0.4), r * 0.08, Color(0.25, 0.25, 0.3))

    draw_set_transform(Vector2.ZERO, 0.0)
