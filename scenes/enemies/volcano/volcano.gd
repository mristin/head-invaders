class_name Volcano

extends GroundEnemy

## A little grumpy volcano on the rocks. Now and then it rumbles and shakes,
## then erupts the lava blobs high up into the air, which fall down in arcs on
## the spaceships.

## How long the volcano rumbles before erupting, in seconds.
@export var rumble_duration: float = 0.8

@export var blob_count: int = 3

## How fast the blobs shoot up, and how strongly they fall back.
@export var min_blob_speed: float = 480.0
@export var max_blob_speed: float = 640.0
@export var blob_gravity: float = 520.0

## How far the blobs spread sideways, in radians from straight up.
@export var blob_spread: float = 0.55

var _time: float = 0.0
var _rumble_left: float = 0.0
var _erupted_for: float = 10.0


func _walk(delta: float) -> void:
    _time += delta
    _erupted_for += delta

    if _rumble_left > 0.0:
        _rumble_left -= delta
        if _rumble_left <= 0.0:
            _erupt()


func _fire_rocket() -> void:
    _rumble_left = rumble_duration


func _erupt() -> void:
    _erupted_for = 0.0
    var crater := global_position + Vector2(0, -radius * 0.45)
    for i in range(blob_count):
        var t := (i / float(maxi(1, blob_count - 1))) - 0.5
        var angle := t * 2.0 * blob_spread + randf_range(-0.1, 0.1)
        var blob := _launch_rocket_from(
            crater, Vector2.UP.rotated(angle), randf_range(min_blob_speed, max_blob_speed)
        )
        if blob != null:
            blob.fall_acceleration = blob_gravity
    Poof.spawn(self, crater, radius * 0.4, Color(1.0, 0.5, 0.15))


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var rock := Color(0.4, 0.28, 0.24).lerp(white, flash)

    var shake := 0.0
    if _rumble_left > 0.0:
        shake = sin(_time * 60.0) * r * 0.03
    var lava := Color(1.0, 0.45, 0.1).lerp(white, flash)
    var glow := clampf(1.0 - _erupted_for, 0.0, 1.0)
    if _rumble_left > 0.0:
        glow = 1.0 - _rumble_left / rumble_duration

    var cone := PackedVector2Array(
        [
            Vector2(-r * 0.7 + shake, r * 0.4),
            Vector2(-r * 0.2 + shake, -r * 0.45),
            Vector2(r * 0.2 + shake, -r * 0.45),
            Vector2(r * 0.7 + shake, r * 0.4),
        ]
    )
    draw_colored_polygon(cone, rock)

    # The lava running down the sides, and the glowing crater.
    for x: float in [-0.12, 0.1]:
        draw_line(
            Vector2(x * r + shake, -r * 0.42),
            Vector2(x * r * 2.2 + shake, -r * 0.05),
            Color(lava, 0.8),
            r * 0.06
        )
    draw_circle(
        Vector2(shake, -r * 0.45), r * (0.2 + 0.1 * glow), Color(1.0, 0.6, 0.2, 0.3 + 0.5 * glow)
    )
    draw_rect(Rect2(Vector2(-r * 0.2 + shake, -r * 0.5), Vector2(r * 0.4, r * 0.08)), lava)

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.15 + shake, r * 0.08)
        draw_circle(eye, r * 0.07, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.035, Color(0.15, 0.05, 0.05))
        draw_line(
            eye + Vector2(-side * r * 0.1, -r * 0.12),
            eye + Vector2(side * r * 0.07, -r * 0.08),
            Color(0.2, 0.1, 0.08),
            r * 0.035
        )
    var mouth := r * (0.03 + 0.05 * glow)
    draw_circle(Vector2(shake, r * 0.24), mouth, Color(0.25, 0.08, 0.05))
