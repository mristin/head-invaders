class_name Tram

extends GroundEnemy

## A blue-and-white Zurich tram with a cheerful face, riding on its rails
## across the city. The rails slide down with the ground, and the tram rides
## along them from one side of the screen to the other and back.
##
## Now and then it stops at a tram stop and opens its doors. It rings its bell
## twice, "ding, ding", and then its pantograph sends a row of sparks down,
## which dance from side to side together as they fall, like a wave. So the
## players hear it coming and see the wave before it reaches them.

## How fast the tram rides along its rails.
@export var ride_speed: float = 170.0

## How long it rides between the stops, in seconds.
@export var min_ride_duration: float = 2.5
@export var max_ride_duration: float = 4.0

## How long it waits at a stop, and when it rings and lets the sparks go.
@export var stop_duration: float = 2.6
@export var ring_at: float = 0.3
@export var sparks_at: float = 1.5

## The row of sparks: how many, how fast they fall, and how far and how fast
## they dance from side to side.
@export var spark_count: int = 3
@export var spark_fall_speed: float = 230.0
@export var dance_width: float = 230.0
@export var dance_frequency: float = 4.0

var _time: float = 0.0
var _direction: float = 1.0
var _ride_left: float = 0.0
var _stop_left: float = 0.0
var _stops: int = 0
var _danced: int = 0

## The sparks dancing down, with their ages.
var _sparks: Array[Rocket] = []
var _spark_ages: Array[float] = []


func _ready() -> void:
    super()
    _direction = -1.0 if randf() < 0.5 else 1.0
    _ride_left = randf_range(min_ride_duration, max_ride_duration)


## Return how many times the tram has stopped so far.
func stops() -> int:
    return _stops


## Return how many of its sparks have danced from side to side so far.
func danced_sparks() -> int:
    return _danced


func is_stopped() -> bool:
    return _stop_left > 0.0


func _may_fire() -> bool:
    # NOTE (mristin):
    # The tram fires only at its stops; see _walk.
    return false


func _walk(delta: float) -> void:
    _time += delta
    _update_sparks(delta)

    if is_stopped():
        var before := stop_duration - _stop_left
        _stop_left = maxf(0.0, _stop_left - delta)
        var after := stop_duration - _stop_left
        if before < sparks_at and after >= sparks_at and super._may_fire():
            _release_sparks()
        return

    var bounds := get_viewport_rect()
    position.x += _direction * ride_speed * delta
    var end := radius * 1.1 + margin
    if position.x < bounds.position.x + end:
        _direction = 1.0
    elif position.x > bounds.end.x - end:
        _direction = -1.0

    _ride_left -= delta
    if _ride_left <= 0.0:
        _ride_left = randf_range(min_ride_duration, max_ride_duration)
        if bounds.has_point(global_position):
            _stop_left = stop_duration
            _stops += 1


func _release_sparks() -> void:
    for i in range(spark_count):
        var x := (i - (spark_count - 1) / 2.0) * radius * 0.7
        var rocket := _launch_rocket_from(
            global_position + Vector2(x, radius * 0.3), Vector2.DOWN, spark_fall_speed
        )
        if rocket != null:
            _sparks.append(rocket)
            _spark_ages.append(0.0)


func _update_sparks(delta: float) -> void:
    for i in range(_sparks.size() - 1, -1, -1):
        var spark := _sparks[i]
        if not is_instance_valid(spark):
            _sparks.remove_at(i)
            _spark_ages.remove_at(i)
            continue
        var age := _spark_ages[i] + delta
        _spark_ages[i] = age
        # NOTE (mristin):
        # All the sparks of a row dance together: x follows a sine wave.
        spark.velocity.x = cos(age * dance_frequency) * dance_width * dance_frequency * 0.5
        if age > 0.5 and _spark_ages[i] - delta <= 0.5:
            _danced += 1


func _start_fleeing(may_drop: bool = true) -> void:
    _stop_left = 0.0
    super(may_drop)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The rails reach across the whole screen, dim like the city below.
    var left := -global_position.x - 40.0
    var right := get_viewport_rect().size.x - global_position.x + 40.0
    for y: float in [r * 0.2, r * 0.36]:
        draw_line(Vector2(left, y), Vector2(right, y), Color(0.3, 0.31, 0.34, 0.6), 4.0)
    var offset := fposmod(global_position.x, r * 0.3)
    var x := left - offset
    while x < right:
        draw_line(Vector2(x, r * 0.15), Vector2(x, r * 0.41), Color(0.25, 0.22, 0.2, 0.5), 5.0)
        x += r * 0.3

    var blue := Color(0.15, 0.45, 0.9).lerp(white, flash)
    var cream := Color(0.95, 0.96, 1.0).lerp(white, flash)
    var length := r * 1.1

    draw_set_transform(Vector2.ZERO, 0.0, Vector2(_direction, 1.0))

    # The pantograph on the roof, touching the wire.
    var sway := sin(_time * 3.0) * r * 0.02
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.2, -r * 0.42),
                Vector2(sway, -r * 0.62),
                Vector2(r * 0.2, -r * 0.42),
                Vector2(sway, -r * 0.5),
            ]
        ),
        Color(0.3, 0.3, 0.35)
    )
    draw_line(
        Vector2(-r * 0.3 + sway, -r * 0.62),
        Vector2(r * 0.3 + sway, -r * 0.62),
        Color(0.3, 0.3, 0.35),
        r * 0.04
    )

    var body := Rect2(Vector2(-length, -r * 0.42), Vector2(length * 2.0, r * 0.66))
    draw_rect(
        Rect2(
            body.position + Vector2(-r * 0.03, -r * 0.03), body.size + Vector2(r * 0.06, r * 0.06)
        ),
        white
    )
    draw_rect(body, blue)
    draw_circle(Vector2(length - r * 0.04, -r * 0.09), r * 0.33, blue)
    draw_rect(Rect2(Vector2(-length, -r * 0.3), Vector2(length * 2.0 - r * 0.2, r * 0.2)), cream)
    for k in range(4):
        var window := Rect2(
            Vector2(-length + r * 0.12 + k * r * 0.42, -r * 0.28), Vector2(r * 0.3, r * 0.16)
        )
        draw_rect(window, Color(0.35, 0.55, 0.75).lerp(white, flash))
    if is_stopped():
        # The doors open at the stop.
        for k in range(2):
            draw_rect(
                Rect2(
                    Vector2(-length * 0.55 + k * length * 0.8, -r * 0.08),
                    Vector2(r * 0.22, r * 0.3)
                ),
                Color(1.0, 0.95, 0.7)
            )

    # The face at the front: the headlight eyes and the smile.
    var face := Vector2(length + r * 0.1, -r * 0.1)
    draw_circle(face, r * 0.23, cream)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(-r * 0.02, side * r * 0.09 - r * 0.04)
        draw_circle(eye, r * 0.065, white)
        draw_circle(eye + Vector2(r * 0.02, 0), r * 0.035, Color(0.05, 0.1, 0.2))
    draw_arc(
        face + Vector2(0, r * 0.07), r * 0.08, 0.2, PI - 0.2, 8, Color(0.2, 0.1, 0.1), r * 0.025
    )
    draw_circle(face + Vector2(r * 0.08, r * 0.06), r * 0.035, Color(1.0, 0.6, 0.6))
    for wheel: float in [-0.7, -0.3, 0.3, 0.7]:
        draw_circle(Vector2(wheel * length, r * 0.26), r * 0.09, Color(0.2, 0.2, 0.25))

    draw_set_transform(Vector2.ZERO, 0.0)

    if is_stopped():
        var since := stop_duration - _stop_left - ring_at
        for k in range(2):
            var ring := since - k * 0.45
            if ring > 0.0 and ring < 0.6:
                var t := ring / 0.6
                draw_arc(
                    Vector2(0, -r * 0.7),
                    r * (0.15 + 0.35 * t),
                    PI * 1.1,
                    PI * 1.9,
                    12,
                    Color(1.0, 0.95, 0.5, 1.0 - t),
                    r * 0.05,
                    true
                )
        draw_circle(Vector2(0, -r * 0.7), r * 0.09, Color(1.0, 0.85, 0.3))
