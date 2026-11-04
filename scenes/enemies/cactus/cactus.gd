class_name Cactus

extends GroundEnemy

## A round, cheerful cactus with a flower on its head, standing in the sand and
## sliding down with the dunes. It puffs out a ring of needles, which stop and
## hang in the air around it for a moment, then all turn to the nearest
## spaceship and fly off. The hanging ring warns the players where the needles
## will come from, so that they have time to dodge.

## How many needles there are in the ring.
@export var needle_count: int = 4

## How far the needles fly out before they stop and hang, in radii of
## the cactus.
@export var ring_reach: float = 1.5

## How long the needles take to fly out and how long they hang, in seconds.
@export var spread_duration: float = 0.45
@export var hang_duration: float = 0.9

## How the cactus sways while it stands, in radians.
@export var sway_amplitude: float = 0.08

## How many rings the cactus has puffed out so far, e.g., for the tests.
var rings_puffed: int = 0

## How many needles have been aimed after hanging, e.g., for the tests.
var needles_aimed: int = 0

var _time: float = 0.0
var _puff: float = 0.0

## The needles of the current ring, and how long they have flown.
var _needles: Array[Rocket] = []
var _needle_age: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.NEEDLE


func _fire_rocket() -> void:
    if not _needles.is_empty():
        return

    rings_puffed += 1
    _puff = 1.0
    _needle_age = 0.0
    var start := randf() * TAU
    var speed := radius * ring_reach / spread_duration * 2.0
    for i in range(needle_count):
        var direction := Vector2.RIGHT.rotated(start + TAU * i / needle_count)
        var needle := _launch_rocket(direction, speed)
        if needle != null:
            needle.lifetime = spread_duration + hang_duration + rocket_lifetime
            _needles.append(needle)


func _walk(delta: float) -> void:
    _time += delta
    _puff = maxf(0.0, _puff - delta * 2.5)
    _steer_needles(delta)


## Slow the needles down until they hang, then aim them at the nearest
## spaceship.
func _steer_needles(delta: float) -> void:
    if _needles.is_empty():
        return

    _needle_age += delta
    var alive: Array[Rocket] = []
    for needle in _needles:
        if (
            is_instance_valid(needle)
            and needle.is_inside_tree()
            and not needle.is_queued_for_deletion()
        ):
            alive.append(needle)
    _needles = alive

    if _needle_age < spread_duration:
        # NOTE (mristin):
        # The needles fly out fast, then glide to a stop, like a puff.
        var t := _needle_age / spread_duration
        var speed := radius * ring_reach / spread_duration * 2.0 * (1.0 - t)
        for needle in _needles:
            needle.velocity = needle.velocity.normalized() * maxf(speed, 1.0)
        return

    if _needle_age < spread_duration + hang_duration:
        # NOTE (mristin):
        # While hanging, the needles slowly turn to point at their target.
        var target := _nearest_spaceship()
        for needle in _needles:
            needle.velocity = needle.velocity.normalized() * 1.0
            if target != null:
                var wanted := needle.global_position.angle_to_point(target.global_position)
                needle.rotation = rotate_toward(needle.rotation, wanted, 6.0 * delta)
                needle.velocity = Vector2.from_angle(needle.rotation)
        return

    _release_needles()


func _release_needles() -> void:
    var target := _nearest_spaceship()
    for needle in _needles:
        if not is_instance_valid(needle):
            continue
        var direction := Vector2.from_angle(needle.rotation)
        if target != null:
            direction = needle.global_position.direction_to(target.global_position)
        needle.velocity = direction * rocket_speed
        needle.rotation = direction.angle()
        needles_aimed += 1
    _needles.clear()


func _start_fleeing(beaten: bool = true) -> void:
    # NOTE (mristin):
    # The hanging needles fall away harmlessly with a poof.
    for needle in _needles:
        if is_instance_valid(needle):
            Poof.spawn(self, needle.global_position, 18.0, Color(0.6, 1.0, 0.5))
            needle.queue_free()
    _needles.clear()
    super(beaten)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var green := Color(0.3, 0.68, 0.36).lerp(white, flash)
    var light_green := Color(0.45, 0.8, 0.45).lerp(white, flash)
    var dark_green := Color(0.2, 0.5, 0.28).lerp(white, flash)

    draw_set_transform(Vector2(0, r * 0.4), sin(_time * 1.6) * sway_amplitude)
    var lift := Vector2(0, -r * 0.4)
    var swell := 1.0 + 0.12 * _puff

    # NOTE (mristin):
    # The pot of sand at the bottom.
    draw_circle(lift + Vector2(0, r * 0.42), r * 0.42, Color(0.55, 0.38, 0.22, 0.6))

    # The arms wave a little.
    for side: float in [-1.0, 1.0]:
        var wave := sin(_time * 2.2 + side) * r * 0.05
        var shoulder := lift + Vector2(side * r * 0.4, r * 0.05)
        var elbow := lift + Vector2(side * r * 0.72, r * 0.05 + wave)
        var hand := lift + Vector2(side * r * 0.72, -r * 0.32 + wave)
        draw_line(shoulder, elbow, green, r * 0.2, true)
        draw_line(elbow, hand, green, r * 0.2, true)
        draw_circle(elbow, r * 0.1, green)
        draw_circle(hand, r * 0.1, light_green)

    var body := PackedVector2Array()
    for i in range(32):
        var a := TAU * i / 32.0
        var ribbed := 1.0 + 0.03 * sin(a * 10.0)
        body.append(lift + Vector2(cos(a) * r * 0.46 * swell * ribbed, sin(a) * r * 0.58 * swell))
    draw_colored_polygon(body, green)
    for i in range(3):
        var x := (i - 1) * r * 0.2 * swell
        draw_line(
            lift + Vector2(x, -r * 0.48), lift + Vector2(x, r * 0.48), dark_green, r * 0.03, true
        )
    draw_circle(lift + Vector2(-r * 0.16, -r * 0.22), r * 0.12, Color(1, 1, 1, 0.15))

    # The face: the big eyes, the rosy cheeks and the smile.
    for side: float in [-1.0, 1.0]:
        var eye := lift + Vector2(side * r * 0.17, -r * 0.08)
        draw_circle(eye, r * 0.11, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.06, Color(0.08, 0.15, 0.08))
        draw_circle(eye + Vector2(-r * 0.03, -r * 0.02), r * 0.025, white)
        draw_circle(lift + Vector2(side * r * 0.28, r * 0.1), r * 0.06, Color(1.0, 0.55, 0.6, 0.8))
    draw_arc(
        lift + Vector2(0, r * 0.1),
        r * 0.1 * (1.0 + _puff * 0.4),
        0.2,
        PI - 0.2,
        10,
        Color(0.12, 0.22, 0.1),
        r * 0.035
    )

    # NOTE (mristin):
    # The flower on its head opens wide when it puffs out the needles.
    var flower := lift + Vector2(0, -r * 0.6 * swell)
    var petal := Color(1.0, 0.5, 0.7).lerp(white, flash)
    for i in range(5):
        var a := TAU * i / 5.0 + _time * 0.5
        draw_circle(flower + Vector2.from_angle(a) * r * (0.12 + 0.05 * _puff), r * 0.09, petal)
    draw_circle(flower, r * 0.08, Color(1.0, 0.85, 0.35))
    draw_set_transform(Vector2.ZERO, 0.0)
