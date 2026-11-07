class_name SnowyOwl

extends Enemy

## A fluffy snowy owl gliding in lazy circles in the upper part of the screen.
## It throws two big, spinning snowflakes like boomerangs: they fly out
## towards the nearest spaceship, one curving to the left and one to
## the right, slow down, turn around and fly back to the owl, which catches
## them again. So the players have to watch the snowflakes on their way back
## too.

@export var descent_speed: float = 200.0

## The circle the owl glides in, in pixels, and how long a round takes.
@export var glide_radius: Vector2 = Vector2(170.0, 60.0)
@export var glide_period: float = 7.0

## The snowflakes: how many, how much they curve, in radians, and how
## strongly they are pulled back to the owl, in pixels per second squared.
@export var flake_count: int = 2
@export var flake_curve: float = 0.45
@export var pull_back: float = 210.0

## How many snowflakes the owl threw and caught again, e.g., for the tests.
var flakes_thrown: int = 0
var flakes_caught: int = 0

var _time: float = 0.0
var _descending: bool = true
var _flakes: Array[Rocket] = []
var _throw: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SNOWFLAKE


func _may_fire() -> bool:
    return not _descending and _flakes.is_empty()


func _move(delta: float) -> void:
    _time += delta
    _throw = maxf(0.0, _throw - delta * 2.0)
    _steer_flakes(delta)

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
        return

    var a := _time * TAU / glide_period
    var bounds := get_viewport_rect()
    position = home + Vector2(sin(a) * glide_radius.x, (1.0 - cos(a)) * glide_radius.y)
    position.x = clampf(position.x, bounds.position.x + radius, bounds.end.x - radius)


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    _throw = 1.0
    for i in range(flake_count):
        var t := (i / float(maxi(1, flake_count - 1))) - 0.5 if flake_count > 1 else 0.0
        var flake := _launch_rocket(aim.rotated(t * 2.0 * flake_curve), rocket_speed)
        if flake != null:
            flake.lifetime = 2.0 * rocket_speed / pull_back + 3.0
            _flakes.append(flake)
            flakes_thrown += 1


## Pull the snowflakes back to the owl, and catch them when they are back.
func _steer_flakes(delta: float) -> void:
    var alive: Array[Rocket] = []
    for flake in _flakes:
        if not is_instance_valid(flake) or flake.is_queued_for_deletion():
            continue
        if not flake.is_inside_tree():
            alive.append(flake)
            continue
        var to_owl := flake.global_position.direction_to(global_position)
        var coming_back := flake.velocity.dot(to_owl) > 0.0
        if coming_back and flake.global_position.distance_to(global_position) < radius * 0.6:
            flakes_caught += 1
            Poof.spawn(self, flake.global_position, 20.0, Color(0.8, 0.95, 1.0))
            flake.queue_free()
            continue
        flake.velocity += to_owl * pull_back * delta
        # NOTE (mristin):
        # On the way back, the snowflake does not fly faster than it was
        # thrown, and homes in on the owl gently, so that it is easy to follow.
        if coming_back:
            flake.velocity = flake.velocity.lerp(to_owl * flake.velocity.length(), 2.0 * delta)
        flake.velocity = flake.velocity.limit_length(rocket_speed)
        alive.append(flake)
    _flakes = alive


func _start_fleeing(beaten: bool = true) -> void:
    # NOTE (mristin):
    # The snowflakes in flight melt away with a poof.
    for flake in _flakes:
        if is_instance_valid(flake):
            Poof.spawn(self, flake.global_position, 18.0, Color(0.8, 0.95, 1.0))
            flake.queue_free()
    _flakes.clear()
    super(beaten)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var feathers := Color(0.94, 0.95, 0.98).lerp(white, flash)
    var shade := Color(0.75, 0.8, 0.88).lerp(white, flash)
    var dots := Color(0.45, 0.5, 0.6).lerp(white, flash)
    var gold := Color(1.0, 0.82, 0.25)

    # NOTE (mristin):
    # The broad wings flap slowly; one swings forward when it throws.
    var flap := sin(_time * 4.0) * 0.25
    for side: float in [-1.0, 1.0]:
        var throw := _throw * 0.6 * side
        var wing := PackedVector2Array()
        wing.append(Vector2(side * r * 0.25, -r * 0.2))
        wing.append(Vector2(side * r * 0.95, -r * (0.25 + flap) + throw * r * 0.3))
        wing.append(Vector2(side * r * 1.0, r * (0.0 - flap * 0.5) + throw * r * 0.4))
        wing.append(Vector2(side * r * 0.7, r * 0.15 + throw * r * 0.3))
        wing.append(Vector2(side * r * 0.25, r * 0.2))
        draw_colored_polygon(wing, shade)
        for k in range(3):
            draw_circle(
                Vector2(side * r * (0.45 + k * 0.15), -r * 0.05 + throw * r * 0.2), r * 0.04, dots
            )

    draw_circle(Vector2(0, r * 0.05), r * 0.42, feathers)
    for k in range(4):
        draw_arc(
            Vector2((k % 2 - 0.5) * r * 0.2, r * (0.15 + k * 0.08)),
            r * 0.06,
            0.2,
            PI - 0.2,
            6,
            dots,
            r * 0.025
        )

    # The round face with the big golden eyes, the little beak and the tufts.
    var head := Vector2(0, -r * 0.2)
    draw_circle(head, r * 0.36, feathers)
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    head + Vector2(side * r * 0.18, -r * 0.28),
                    head + Vector2(side * r * 0.33, -r * 0.42),
                    head + Vector2(side * r * 0.32, -r * 0.18),
                ]
            ),
            feathers
        )
        var eye := head + Vector2(side * r * 0.14, -r * 0.02)
        draw_circle(eye, r * 0.13, gold)
        draw_circle(eye, r * 0.07, Color(0.08, 0.08, 0.12))
        draw_circle(eye + Vector2(-r * 0.03, -r * 0.03), r * 0.03, white)
        draw_circle(head + Vector2(side * r * 0.22, r * 0.15), r * 0.05, Color(1.0, 0.6, 0.7, 0.7))
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.05, r * 0.08),
                head + Vector2(r * 0.05, r * 0.08),
                head + Vector2(0, r * 0.19),
            ]
        ),
        Color(0.35, 0.3, 0.3)
    )
