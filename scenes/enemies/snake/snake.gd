class_name Snake

extends GroundEnemy

## A lava snake on the rocks, seen from above: it slithers from side to side
## and now and then rears up its head, hisses, and spits a fan of fireballs at
## the nearest spaceship.

@export var slither_speed: float = 110.0

@export var fan_size: int = 3
@export var fan_angle: float = 0.28

## How long the snake rears up before spitting, in seconds.
@export var rear_duration: float = 0.7

@export var segment_count: int = 10

var _time: float = 0.0
var _direction: float = 1.0
var _rear_left: float = 0.0


func _ready() -> void:
    super()
    _direction = 1.0 if randf() < 0.5 else -1.0


func _walk(delta: float) -> void:
    _time += delta

    if _rear_left > 0.0:
        _rear_left -= delta
        if _rear_left <= 0.0:
            _spit()
        return

    var bounds := get_viewport_rect()
    position.x += _direction * slither_speed * delta
    if position.x > bounds.end.x - margin - radius * 0.4 and _direction > 0.0:
        _direction = -1.0
    elif position.x < bounds.position.x + margin + radius * 0.4 and _direction < 0.0:
        _direction = 1.0


func _fire_rocket() -> void:
    _rear_left = rear_duration


func _spit() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(aim.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var purple := Color(0.55, 0.3, 0.7).lerp(white, flash)
    var band := Color(1.0, 0.8, 0.25).lerp(white, flash)

    # NOTE (mristin):
    # The body waves behind the head; it waves less while rearing up.
    var rear := 0.0
    if _rear_left > 0.0:
        rear = sin(PI * (1.0 - _rear_left / rear_duration))
    var points: Array[Vector2] = []
    for i in range(segment_count):
        var t := i / float(segment_count - 1)
        var x := -_direction * (t * r * 1.1 - r * 0.35)
        var y := sin(_time * 6.0 - t * 5.0) * r * 0.16 * t * (1.0 - 0.6 * rear)
        points.append(Vector2(x, y))

    for i in range(segment_count - 1, 0, -1):
        var size := r * lerpf(0.13, 0.07, i / float(segment_count - 1))
        draw_circle(points[i], size, purple if i % 3 != 0 else band)

    var head := points[0] - Vector2(0, r * 0.15 * rear)
    var head_size := r * (0.17 + 0.05 * rear)
    var tongue := 1.0 if fmod(_time * 2.5, 1.0) < 0.3 or rear > 0.0 else 0.0
    if tongue > 0.0:
        var tip := head + Vector2(_direction * head_size * 1.6, 0)
        draw_line(head, tip, Color(1.0, 0.3, 0.4), r * 0.025)
        draw_line(
            tip, tip + Vector2(_direction * r * 0.05, -r * 0.04), Color(1.0, 0.3, 0.4), r * 0.02
        )
        draw_line(
            tip, tip + Vector2(_direction * r * 0.05, r * 0.04), Color(1.0, 0.3, 0.4), r * 0.02
        )
    draw_circle(head, head_size, purple)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(_direction * head_size * 0.35, side * head_size * 0.5)
        draw_circle(eye, head_size * 0.3, band)
        draw_circle(eye, head_size * 0.14, Color(0.1, 0.05, 0.1))
