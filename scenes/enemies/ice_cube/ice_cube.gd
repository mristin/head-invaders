class_name IceCube

extends GroundEnemy

## A little ice cube which broke off an iceberg. It skids around the ice in
## short, quick hops, and throws an icicle at the nearest spaceship now and
## then. It is small and fragile.
##
## It slides on the ice, so the spaceships fly over it.

@export var skid_speed: float = 260.0
@export var skid_duration: float = 0.5
@export var rest_duration: float = 0.9

var _time: float = 0.0
var _state_left: float = 0.0
var _skid: Vector2 = Vector2.ZERO
var _spin: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.ICICLE
    _state_left = rest_duration


func _walk(delta: float) -> void:
    _time += delta
    _state_left -= delta
    if _skid != Vector2.ZERO:
        position += _skid * skid_speed * delta * (_state_left / skid_duration + 0.3)
        _spin += _skid.x * delta * 4.0
        if _state_left <= 0.0:
            _skid = Vector2.ZERO
            _state_left = rest_duration
        return

    if _state_left <= 0.0:
        var bounds := get_viewport_rect()
        var side := -1.0 if randf() < 0.5 else 1.0
        if position.x < bounds.position.x + margin * 2.0:
            side = 1.0
        elif position.x > bounds.end.x - margin * 2.0:
            side = -1.0
        var up := -0.6 if global_position.y > bounds.size.y * 0.45 else randf_range(-0.3, 0.3)
        _skid = Vector2(side, up).normalized()
        _state_left = skid_duration


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    draw_set_transform(Vector2.ZERO, sin(_spin) * 0.3)
    var half := r * 0.4
    draw_rect(
        Rect2(-half * 1.1, -half * 1.1, half * 2.2, half * 2.2),
        Color(0.35, 0.6, 0.78).lerp(white, flash)
    )
    draw_rect(Rect2(-half, -half, half * 1.9, half * 1.9), Color(0.72, 0.9, 1.0).lerp(white, flash))
    draw_rect(Rect2(-half * 0.8, -half * 0.8, half * 0.6, half * 0.25), Color(1, 1, 1, 0.6))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.14, -r * 0.02)
        draw_circle(eye, r * 0.08, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.045, Color(0.1, 0.2, 0.35))
        draw_circle(eye + Vector2(-r * 0.015, -r * 0.015), r * 0.018, white)
        draw_circle(Vector2(side * r * 0.24, r * 0.12), r * 0.05, Color(1.0, 0.6, 0.75, 0.7))
    draw_arc(Vector2(0, r * 0.1), r * 0.08, 0.3, PI - 0.3, 8, Color(0.15, 0.3, 0.45), r * 0.03)
    draw_set_transform(Vector2.ZERO, 0.0)
