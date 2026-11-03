class_name Swan

extends GroundEnemy

## A proud swan of Lake Zurich: it swims on the water, drifting down with
## the lake and paddling from side to side, and splashes a pair of water drops
## at the nearest spaceship.
##
## Unlike the other enemies on the ground, it does not stay there: once it has
## lost half of its energy, or once the lake has carried it far down, it
## takes off with a big splash, flies up to the top of the screen and cruises
## there, throwing fans of water drops. In the air, the spaceships can bump
## into it.

## How fast the swan paddles from side to side on the water.
@export var paddle_speed: float = 70.0

## It takes off below this fraction of its energy...
@export_range(0.0, 1.0) var take_off_below: float = 0.5

## ... or once it drifts below this fraction of the screen height.
@export_range(0.0, 1.0) var take_off_at: float = 0.78

## Where it cruises in the air, as a fraction of the screen height.
@export_range(0.0, 1.0) var cruise_height: float = 0.24

@export var climb_speed: float = 280.0
@export var cruise_speed: float = 200.0

## The drops: two on the water, a fan of three in the air.
@export var drop_angle: float = 0.3

var _time: float = 0.0
var _flying: bool = false
var _cruise_direction: float = 1.0


## Return true once the swan has taken off.
func is_flying() -> bool:
    return _flying


func take_damage(amount: int) -> void:
    super(amount)
    if is_alive() and not _flying and energy <= max_energy * take_off_below:
        _take_off()


func _take_off() -> void:
    _flying = true
    grounded = false
    _cruise_direction = 1.0 if global_position.x < get_viewport_rect().get_center().x else -1.0
    Poof.spawn(self, global_position + Vector2(0, radius * 0.3), radius, Color(0.7, 0.9, 1.0))


func _move(delta: float) -> void:
    _time += delta
    if not _flying:
        super(delta)
        if position.y > get_viewport_rect().size.y * take_off_at:
            _take_off()
        return

    var bounds := get_viewport_rect()
    position.y = move_toward(position.y, bounds.size.y * cruise_height, climb_speed * delta)
    position.x += _cruise_direction * cruise_speed * delta
    if position.x < bounds.position.x + margin:
        _cruise_direction = 1.0
    elif position.x > bounds.end.x - margin:
        _cruise_direction = -1.0


func _walk(delta: float) -> void:
    position.x += sin(_time * 0.7) * paddle_speed * delta


func _may_fire() -> bool:
    return true if _flying else super()


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return

    if _flying:
        for i in range(3):
            _launch_rocket(aim.rotated((i - 1) * drop_angle), rocket_speed)
    else:
        for side: float in [-0.5, 0.5]:
            _launch_rocket(aim.rotated(side * drop_angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var feathers := Color(0.96, 0.96, 0.98).lerp(white, flash)
    var shade := Color(0.8, 0.84, 0.9).lerp(white, flash)

    if not _flying:
        # NOTE (mristin):
        # The ripples around the swan on the water.
        for k in range(2):
            var ripple := fmod(_time * 0.6 + k * 0.5, 1.0)
            draw_arc(
                Vector2(0, r * 0.3),
                r * (0.55 + 0.3 * ripple),
                0.0,
                PI,
                24,
                Color(0.7, 0.85, 1.0, 0.5 * (1.0 - ripple)),
                3.0,
                true
            )
    else:
        # The wings beat up and down.
        var beat := sin(_time * 10.0) * 0.5
        for side: float in [-1.0, 1.0]:
            var wing := PackedVector2Array(
                [
                    Vector2(side * r * 0.2, 0),
                    Vector2(side * r * 0.95, -r * (0.15 + beat * 0.6)),
                    Vector2(side * r * 1.05, -r * (0.05 + beat * 0.5)),
                    Vector2(side * r * 0.8, r * 0.15),
                    Vector2(side * r * 0.2, r * 0.25),
                ]
            )
            draw_colored_polygon(wing, shade)
            draw_polyline(wing, white, 2.0, true)

    # The body, the folded wing and the tail.
    var body := Vector2(0, r * 0.15)
    draw_set_transform(body, 0.0, Vector2(1.0, 0.62))
    draw_circle(Vector2.ZERO, r * 0.55, feathers)
    draw_circle(Vector2(r * 0.12, -r * 0.05), r * 0.36, shade)
    draw_set_transform(Vector2.ZERO, 0.0)
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.45, r * 0.05),
                Vector2(-r * 0.7, -r * 0.12),
                Vector2(-r * 0.5, r * 0.25)
            ]
        ),
        feathers
    )

    # The neck curves up to the head.
    var neck := PackedVector2Array()
    for k in range(9):
        var t := k / 8.0
        neck.append(Vector2(r * (0.28 - 0.2 * sin(t * PI)), r * (0.05 - 0.55 * t)))
    draw_polyline(neck, feathers, r * 0.16, true)

    var head := neck[-1] + Vector2(0, -r * 0.05)
    draw_circle(head, r * 0.17, feathers)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.07, -r * 0.02)
        draw_circle(eye, r * 0.05, white)
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.03, Color(0.05, 0.05, 0.1))
        draw_circle(head + Vector2(side * r * 0.12, r * 0.06), r * 0.03, Color(1.0, 0.6, 0.65))
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.06, r * 0.06),
                head + Vector2(r * 0.06, r * 0.06),
                head + Vector2(0, r * 0.2)
            ]
        ),
        Color(1.0, 0.55, 0.15).lerp(white, flash)
    )
    draw_circle(head + Vector2(0, r * 0.06), r * 0.035, Color(0.1, 0.1, 0.1))
