class_name Mushroom

extends GroundEnemy

## A grumpy mushroom on the forest floor: it slides down with the ground, and
## now and then squishes its cap and puffs a fan of spores at the nearest
## spaceship.

@export var fan_size: int = 3
@export var fan_angle: float = 0.3

## How long the cap squishes when puffing, in seconds.
@export var puff_duration: float = 0.5

var _time: float = 0.0
var _puff_left: float = 0.0


func _walk(delta: float) -> void:
    _time += delta
    _puff_left = maxf(0.0, _puff_left - delta)


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return

    _puff_left = puff_duration
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(aim.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var squish := sin(PI * _puff_left / puff_duration) * 0.2 if _puff_left > 0.0 else 0.0

    var stem := Rect2(Vector2(-r * 0.32, -r * 0.1), Vector2(r * 0.64, r * 0.62))
    draw_rect(stem, Color(0.95, 0.9, 0.75).lerp(white, flash))
    draw_circle(Vector2(0, r * 0.52), r * 0.32, Color(0.95, 0.9, 0.75).lerp(white, flash))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.13, r * 0.15)
        draw_circle(eye, r * 0.08, Color(0.15, 0.1, 0.05))
        draw_line(
            eye + Vector2(-side * r * 0.1, -r * 0.14),
            eye + Vector2(side * r * 0.08, -r * 0.09),
            Color(0.3, 0.2, 0.1),
            r * 0.04
        )
    draw_arc(
        Vector2(0, r * 0.42), r * 0.08, PI + 0.4, TAU - 0.4, 8, Color(0.3, 0.15, 0.1), r * 0.03
    )

    var cap := PackedVector2Array()
    for i in range(25):
        var angle := PI + PI * i / 24.0
        cap.append(
            Vector2(cos(angle) * r * (0.85 + squish * 0.5), sin(angle) * r * 0.65 * (1.0 - squish))
        )
    var cap_y := Vector2(0, -r * 0.02)
    for i in range(cap.size()):
        cap[i] += cap_y
    draw_colored_polygon(cap, Color(0.9, 0.25, 0.25).lerp(white, flash))
    for spot: Vector2 in [Vector2(-0.45, -0.25), Vector2(0.05, -0.48), Vector2(0.5, -0.2)]:
        draw_circle(spot * r * Vector2(1.0, 1.0 - squish), r * 0.11, Color(1, 1, 1, 0.9))
