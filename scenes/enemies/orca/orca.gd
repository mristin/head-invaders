class_name Orca

extends GroundEnemy

## A playful orca swimming in the dark water between the floes, seen from
## above. Now and then it gets ready for a big leap: it wiggles, and a ring of
## ripples marks the spot where it will land. Then it leaps out of the water
## in a high arc, towards the players looking down, so it grows bigger while
## its shadow glides over the ice below it, and lands on the marked spot with
## a big splash, which sprays a fan of water drops at the nearest spaceship.
##
## While high up in the air, the orca is no longer on the water, so it bumps
## into the spaceships under it.

enum State { SWIMMING, WINDING_UP, LEAPING }

@export var windup_duration: float = 1.1
@export var leap_duration: float = 1.4

## How far the orca leaps at most, in pixels.
@export var leap_reach: float = 700.0

## How much bigger the orca looks at the top of its leap.
@export var leap_height: float = 0.7

## It lands only in this band of the screen height.
@export_range(0.0, 1.0) var land_above: float = 0.5
@export_range(0.0, 1.0) var land_below: float = 0.2

## The splash: the number of drops, the angle between them and their speed.
@export var splash_count: int = 3
@export var splash_angle: float = 0.3
@export var splash_speed: float = 330.0

@export var swim_speed: float = 80.0

## How many times the orca leaped so far, e.g., for the tests.
var leaps: int = 0

## How many times the orca was high in the air so far, e.g., for the tests.
var airborne_seen: int = 0

var _state: State = State.SWIMMING
var _state_time: float = 0.0
var _time: float = 0.0
var _swim: float = 1.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _height: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.BUBBLE
    _swim = -1.0 if randf() < 0.5 else 1.0


func state() -> State:
    return _state


## Return where the orca will land relative to its parent, while it gets
## ready or leaps.
func landing_spot() -> Vector2:
    return _to


func is_airborne() -> bool:
    return _state == State.LEAPING and _height > 0.35


func _may_fire() -> bool:
    return _state == State.SWIMMING and super()


func _walk(delta: float) -> void:
    _time += delta
    _state_time += delta

    match _state:
        State.SWIMMING:
            var bounds := get_viewport_rect()
            position.x += _swim * swim_speed * delta
            if position.x < bounds.position.x + margin * 1.5:
                _swim = 1.0
            elif position.x > bounds.end.x - margin * 1.5:
                _swim = -1.0
        State.WINDING_UP:
            # NOTE (mristin):
            # The landing spot slides down with the sea, like the orca.
            _to.y += ground_speed * delta
            if _state_time >= windup_duration:
                _start(State.LEAPING)
                _from = position
                leaps += 1
        State.LEAPING:
            _from.y += ground_speed * delta
            _to.y += ground_speed * delta
            var t := clampf(_state_time / leap_duration, 0.0, 1.0)
            position = _from.lerp(_to, smoothstep(0.0, 1.0, t))
            _height = sin(PI * t)
            var airborne := _height > 0.35
            if airborne and grounded:
                airborne_seen += 1
            grounded = not airborne
            if t >= 1.0:
                _height = 0.0
                grounded = true
                _start(State.SWIMMING)
                _splash()


func _start(new_state: State) -> void:
    _state = new_state
    _state_time = 0.0


func _fire_rocket() -> void:
    var bounds := get_viewport_rect()
    var target := _nearest_spaceship()
    var x := position.x + randf_range(-leap_reach, leap_reach) * 0.6
    if target != null:
        x = target.global_position.x - global_position.x + position.x
    x = clampf(x, position.x - leap_reach, position.x + leap_reach)
    x = clampf(x, bounds.position.x + margin * 1.5, bounds.end.x - margin * 1.5)
    var y := clampf(
        position.y + randf_range(-120.0, 120.0),
        bounds.position.y + bounds.size.y * land_below,
        bounds.position.y + bounds.size.y * land_above
    )
    _to = Vector2(x, y)
    _start(State.WINDING_UP)


func _splash() -> void:
    Poof.spawn(self, global_position, radius * 0.8, Color(0.6, 0.85, 1.0))
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    for i in range(splash_count):
        var angle := (i - (splash_count - 1) / 2.0) * splash_angle
        _launch_rocket(aim.rotated(angle), splash_speed)


func _energy_bar_y() -> float:
    return radius * (0.55 + 0.3 * _height)


func _draw() -> void:
    if not is_fleeing() and _state != State.SWIMMING:
        _draw_marker()
    super()


## Draw the ripples where the orca takes off and where it will land, and its
## shadow below it while it leaps.
func _draw_marker() -> void:
    var r := radius
    var to := _to - position
    var pulse := 0.5 + 0.5 * sin(_time * 9.0)
    for k in range(2):
        var grow := fmod(_time * 0.8 + k * 0.5, 1.0)
        draw_arc(
            to,
            r * (0.4 + 0.5 * grow),
            0.0,
            TAU,
            32,
            Color(0.8, 0.95, 1.0, 0.8 * (1.0 - grow)),
            r * 0.06,
            true
        )
    draw_circle(to, r * 0.35, Color(0.6, 0.85, 1.0, 0.18 + 0.12 * pulse))

    if _state == State.LEAPING:
        draw_circle(Vector2(r * 0.2, r * 0.35) * _height, r * 0.42, Color(0, 0, 0.05, 0.35))
    else:
        for k in range(2):
            var grow := fmod(_time * 1.6 + k * 0.5, 1.0)
            draw_arc(
                Vector2.ZERO,
                r * (0.4 + 0.4 * grow),
                0.0,
                TAU,
                24,
                Color(0.7, 0.9, 1.0, 0.4 * (1.0 - grow)),
                r * 0.04,
                true
            )


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius * (1.0 + leap_height * _height)
    var black := Color(0.14, 0.17, 0.28).lerp(white, flash)
    var rim := Color(0.6, 0.8, 1.0, 0.7)
    var patch := Color(0.95, 0.97, 1.0).lerp(white, flash)

    # NOTE (mristin):
    # We see the orca from above, head down: it swims with a wavy tail, and
    # wiggles while it gets ready to leap.
    var wiggle := 0.0
    if _state == State.WINDING_UP:
        wiggle = sin(_time * 25.0) * 0.12
    var angle := wiggle
    if _state == State.SWIMMING:
        angle = -_swim * 0.25 + sin(_time * 3.0) * 0.05
    elif _state == State.LEAPING:
        angle = (_to - _from).angle() - PI / 2.0
        angle = clampf(angle, -1.0, 1.0)
    draw_set_transform(Vector2.ZERO, angle)

    if _state != State.LEAPING:
        draw_circle(Vector2.ZERO, r * 0.55, Color(0.4, 0.6, 0.8, 0.18))

    var swish := sin(_time * 6.0) * r * 0.08
    var tail := Vector2(swish, -r * 0.62)
    draw_line(Vector2(0, -r * 0.3), tail, rim, r * 0.2, true)
    draw_line(Vector2(0, -r * 0.3), tail, black, r * 0.14, true)
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    tail,
                    tail + Vector2(side * r * 0.24, -r * 0.08),
                    tail + Vector2(side * r * 0.08, r * 0.06)
                ]
            ),
            black
        )

    var body := PackedVector2Array()
    for i in range(28):
        var a := TAU * i / 28.0
        var taper := 1.0 - 0.25 * maxf(0.0, -sin(a))
        body.append(Vector2(cos(a) * r * 0.3 * taper, sin(a) * r * 0.45))
    # NOTE (mristin):
    # The pale rim makes the dark orca stand out on the dark water.
    var outline := PackedVector2Array()
    for point in body:
        outline.append(point * 1.1)
    draw_colored_polygon(outline, rim)
    draw_colored_polygon(body, black)
    draw_colored_polygon(
        PackedVector2Array(
            [Vector2(-r * 0.12, r * 0.3), Vector2(r * 0.12, r * 0.3), Vector2(0, r * 0.44)]
        ),
        patch
    )
    for side: float in [-1.0, 1.0]:
        var fin := PackedVector2Array(
            [
                Vector2(side * r * 0.22, r * 0.05),
                Vector2(side * r * 0.5, r * (0.2 + 0.05 * sin(_time * 5.0))),
                Vector2(side * r * 0.24, r * 0.2),
            ]
        )
        draw_colored_polygon(fin, black)
    draw_colored_polygon(
        PackedVector2Array(
            [Vector2(-r * 0.04, -r * 0.05), Vector2(0, -r * 0.3), Vector2(r * 0.04, -r * 0.05)]
        ),
        Color(0.2, 0.22, 0.32).lerp(white, flash)
    )

    # The face: the white patches with the eyes, the cheeks and the smile.
    var head := Vector2(0, r * 0.2)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.13, -r * 0.02)
        draw_circle(eye, r * 0.09, patch)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.045, Color(0.05, 0.05, 0.12))
        draw_circle(eye + Vector2(-r * 0.015, -r * 0.01), r * 0.018, white)
        draw_circle(
            head + Vector2(side * r * 0.17, r * 0.12), r * 0.04, Color(1.0, 0.55, 0.65, 0.8)
        )
    draw_arc(head + Vector2(0, r * 0.08), r * 0.12, 0.25, PI - 0.25, 10, patch, r * 0.035)
    draw_set_transform(Vector2.ZERO, 0.0)
