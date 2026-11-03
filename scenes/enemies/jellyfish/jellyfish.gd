class_name Jellyfish

extends Enemy

## A glowing sea jellyfish: it drifts down through the whole screen in soft
## pulses, swaying from side to side, and comes around from the top again.
## Now and then it lights up and zaps a ring of short sparks all around, so
## the spaceships had better keep their distance.

## How fast the jellyfish sinks between the pulses.
##
## NOTE (mristin):
## On average, the pulses lift it by 2 * pulse_frequency * pulse_strength, so
## keep the sinking well above that, or the jellyfish never comes down.
@export var sink_speed: float = 80.0

@export var sway_amplitude: float = 90.0
@export var sway_frequency: float = 0.15

## The pulses: how many per second, and how far up each pulse pushes.
@export var pulse_frequency: float = 0.8
@export var pulse_strength: float = 22.0

## The number of sparks in a ring.
@export var ring_size: int = 6

## How long it glows before it zaps, in seconds.
@export var charge_duration: float = 0.6

@export var margin: float = 100.0

var _time: float = 0.0
var _lane_x: float = 0.0
var _charge_left: float = 0.0


func _ready() -> void:
    super()
    _lane_x = home.x
    _time = randf() * 10.0


func _move(delta: float) -> void:
    _time += delta

    # NOTE (mristin):
    # The jellyfish sinks, but each pulse pushes it up a little.
    var pulse := maxf(0.0, sin(_time * TAU * pulse_frequency))
    position.y += (sink_speed - pulse * pulse_strength * TAU * pulse_frequency) * delta

    var bounds := get_viewport_rect()
    if position.y > bounds.end.y + radius * 2.0:
        position.y = bounds.position.y - radius * 2.0
        _lane_x = randf_range(bounds.position.x + margin * 2.0, bounds.end.x - margin * 2.0)

    position.x = clampf(
        _lane_x + sin(_time * TAU * sway_frequency) * sway_amplitude,
        bounds.position.x + margin,
        bounds.end.x - margin
    )

    if _charge_left > 0.0:
        _charge_left -= delta
        if _charge_left <= 0.0:
            _zap()


func _fire_rocket() -> void:
    _charge_left = charge_duration


func _zap() -> void:
    var start := randf() * TAU
    for i in range(ring_size):
        _launch_rocket(Vector2.RIGHT.rotated(start + TAU * i / ring_size), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var charge := 0.0
    if _charge_left > 0.0:
        charge = 1.0 - _charge_left / charge_duration
    var glow := Color(0.45, 0.95, 1.0).lerp(Color(1.0, 0.95, 0.5), charge)

    draw_circle(Vector2(0, -r * 0.1), r * (0.8 + 0.25 * charge), Color(glow, 0.12 + 0.2 * charge))

    for i in range(4):
        var x := (i - 1.5) * r * 0.22
        var points := PackedVector2Array()
        for j in range(10):
            var t := j / 9.0
            var wave := sin(_time * 3.0 + i * 1.7 + t * 6.0) * r * 0.1 * t
            points.append(Vector2(x + wave, r * 0.05 + t * r * 0.95))
        draw_polyline(points, Color(glow, 0.7).lerp(white, flash), r * 0.05, true)

    # NOTE (mristin):
    # The bell squeezes with each pulse.
    var pulse := maxf(0.0, sin(_time * TAU * pulse_frequency))
    var squeeze := 1.0 - 0.12 * pulse
    var bell := PackedVector2Array()
    for i in range(21):
        var angle := PI + PI * i / 20.0
        bell.append(Vector2(cos(angle) * r * 0.6 * squeeze, sin(angle) * r * 0.55 / squeeze))
    for i in range(9):
        var x := r * 0.6 * squeeze - r * 1.2 * squeeze * i / 8.0
        bell.append(Vector2(x, r * 0.08 * (1.0 if i % 2 == 0 else 0.3)))
    draw_colored_polygon(bell, Color(glow, 0.65).lerp(white, flash))
    draw_circle(Vector2(-r * 0.2, -r * 0.3), r * 0.08, Color(1, 1, 1, 0.5))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.17, -r * 0.18)
        draw_circle(eye, r * 0.08, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.04, Color(0.05, 0.15, 0.25))
