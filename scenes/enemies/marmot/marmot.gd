class_name Marmot

extends GroundEnemy

## A chubby, curious marmot with a colony of three burrows in the meadow,
## which slide down with the ground. It plays peek-a-boo: first it peeks out
## of a burrow and whistles a warning, with the little sound waves around its
## head; then it stands up tall and throws a fan of snowballs at the nearest
## spaceship. When it gets hit a few times, it says "peek-a-boo!" and ducks
## into its burrow, and a moment later peeks out of another one. It also ducks
## when it stood up for long enough.
##
## The bullets can not reach the marmot down in its burrows. The marmot stays
## on the ground, so the spaceships fly over it.

enum Phase { HIDDEN, WHISTLING, UP, DUCKING }

## How long the marmot stays hidden, whistles, stands up and ducks, in
## seconds.
@export var hidden_duration: float = 1.1
@export var whistle_duration: float = 1.1
@export var up_duration: float = 3.4
@export var duck_duration: float = 0.35

## It ducks early after this many hits while it stands.
@export var duck_after_hits: int = 3

## The fan of snowballs: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.3

## How far apart the burrows are, in radii of the marmot.
@export var burrow_spread: float = 2.4

## How many times the marmot stood up so far, e.g., for the tests.
var pops: int = 0

## How many times it ducked because of the hits, e.g., for the tests.
var peekaboos: int = 0

## How many times it moved to another burrow, e.g., for the tests.
var hops: int = 0

var _phase: Phase = Phase.HIDDEN
var _phase_left: float = 0.0
var _time: float = 0.0
var _hits: int = 0
var _thrown: bool = false

## The burrows of the colony, relative to the marmot, which is always at its
## current burrow.
var _burrows: Array[Vector2] = []


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SNOWBALL
    var s := radius * burrow_spread
    _burrows = [Vector2.ZERO, Vector2(-s, s * 0.35), Vector2(s, -s * 0.25)]


func is_hidden() -> bool:
    return _phase == Phase.HIDDEN or _phase == Phase.DUCKING


func is_whistling() -> bool:
    return _phase == Phase.WHISTLING


func is_targetable() -> bool:
    return not is_hidden()


func take_damage(amount: int) -> void:
    if not is_targetable():
        return
    super(amount)
    if is_alive() and _phase == Phase.UP:
        _hits += 1
        if _hits >= duck_after_hits:
            peekaboos += 1
            _duck()


func _may_fire() -> bool:
    # NOTE (mristin):
    # The marmot throws only when it stands up; see _walk.
    return false


func _enter() -> void:
    super()
    _hide()


func _hide() -> void:
    _phase = Phase.HIDDEN
    _phase_left = hidden_duration
    set_deferred("monitorable", false)


func _duck() -> void:
    _phase = Phase.DUCKING
    _phase_left = duck_duration
    set_deferred("monitorable", false)
    Poof.spawn(self, global_position, radius * 0.5, Color(0.75, 0.6, 0.4))


func _walk(delta: float) -> void:
    _time += delta
    _phase_left -= delta

    match _phase:
        Phase.HIDDEN:
            # NOTE (mristin):
            # The marmot peeks out only once its burrow is on the screen.
            if _phase_left <= 0.0 and position.y > get_viewport_rect().position.y + radius:
                _hop()
                _phase = Phase.WHISTLING
                _phase_left = whistle_duration
                set_deferred("monitorable", true)
        Phase.WHISTLING:
            if _phase_left <= 0.0:
                pops += 1
                _phase = Phase.UP
                _phase_left = up_duration
                _hits = 0
                _thrown = false
        Phase.UP:
            if not _thrown and _phase_left < up_duration - 0.6:
                _thrown = true
                _throw()
            if _phase_left <= 0.0:
                _duck()
        Phase.DUCKING:
            if _phase_left <= 0.0:
                _hide()


## Move over to another burrow which is on the screen, if there is one.
func _hop() -> void:
    var bounds := get_viewport_rect()
    var choices: Array[int] = []
    for i in range(1, _burrows.size()):
        var at := position + _burrows[i]
        if (
            at.x > bounds.position.x + margin
            and at.x < bounds.end.x - margin
            and at.y > bounds.position.y + radius
            and at.y < bounds.position.y + bounds.size.y * fire_above
        ):
            choices.append(i)
    if choices.is_empty():
        return

    var shift := _burrows[choices.pick_random()]
    position += shift
    for i in range(_burrows.size()):
        _burrows[i] -= shift
    # NOTE (mristin):
    # We keep the current burrow first.
    _burrows.sort_custom(func(a: Vector2, b: Vector2): return a.length() < b.length())
    hops += 1


func _throw() -> void:
    if not super._may_fire():
        return
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    var from := global_position + Vector2(0, -radius * 0.2)
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(from, aim.rotated(angle), rocket_speed)


## Return how far the marmot is out of its burrow, from 0 to 1.
func _out() -> float:
    match _phase:
        Phase.WHISTLING:
            return 0.45
        Phase.UP:
            return minf(1.0, 0.45 + (up_duration - _phase_left) * 3.0)
        Phase.DUCKING:
            return 0.8 * _phase_left / duck_duration
        _:
            return 0.0


func _draw() -> void:
    if is_alive():
        for burrow in _burrows:
            _draw_burrow(burrow)
    if is_alive() and _phase == Phase.HIDDEN:
        return
    super()


func _draw_burrow(at: Vector2) -> void:
    var r := radius
    draw_set_transform(at + Vector2(0, r * 0.35), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, r * 0.62, Color(0.3, 0.24, 0.16))
    draw_circle(Vector2.ZERO, r * 0.45, Color(0.07, 0.05, 0.04))
    draw_set_transform(Vector2.ZERO, 0.0)


func _energy_bar_y() -> float:
    return radius * 0.75


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var out := _out() if is_alive() else 1.0
    var fur := Color(0.62, 0.45, 0.3).lerp(white, flash)
    var belly := Color(0.88, 0.75, 0.58).lerp(white, flash)
    var dark := Color(0.25, 0.15, 0.1)

    # NOTE (mristin):
    # The marmot rises out of its burrow; we draw it from the bottom of
    # the hole upwards, then the front rim of the hole over it.
    var rise := r * 1.0 * out
    var base := Vector2(0, r * 0.4)
    var body := base + Vector2(0, -rise * 0.5)
    var head := base + Vector2(0, -rise)
    var sway := sin(_time * 3.0) * r * 0.04

    if out > 0.6:
        draw_set_transform(body, 0.0, Vector2(1.0, 1.25))
        draw_circle(Vector2.ZERO, r * 0.36, fur)
        draw_circle(Vector2(0, r * 0.05), r * 0.24, belly)
        draw_set_transform(Vector2.ZERO, 0.0)
        for side: float in [-1.0, 1.0]:
            var paw := body + Vector2(side * r * 0.12, -r * 0.14)
            if _phase == Phase.UP and _phase_left > up_duration - 0.8:
                # It raises its paws to throw.
                paw = body + Vector2(side * r * 0.3, -r * 0.4)
            draw_circle(paw, r * 0.08, fur)

    head.x += sway
    for side: float in [-1.0, 1.0]:
        draw_circle(head + Vector2(side * r * 0.24, -r * 0.2), r * 0.09, fur)
        draw_circle(head + Vector2(side * r * 0.24, -r * 0.2), r * 0.05, Color(0.85, 0.6, 0.55))
    draw_circle(head, r * 0.32, fur)
    draw_circle(head + Vector2(0, r * 0.12), r * 0.17, belly)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.13, -r * 0.06)
        draw_circle(eye, r * 0.08, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.05, dark)
        draw_circle(eye + Vector2(-r * 0.02, -r * 0.015), r * 0.02, white)
        draw_circle(head + Vector2(side * r * 0.22, r * 0.08), r * 0.045, Color(1.0, 0.5, 0.5, 0.7))
    draw_circle(head + Vector2(0, r * 0.05), r * 0.045, dark)
    draw_rect(Rect2(head + Vector2(-r * 0.045, r * 0.13), Vector2(r * 0.09, r * 0.08)), white)
    draw_line(head + Vector2(0, r * 0.13), head + Vector2(0, r * 0.21), Color(0.7, 0.7, 0.7), 1.5)

    # The front rim of the burrow.
    var rim := PackedVector2Array()
    for i in range(17):
        var a := PI * i / 16.0
        rim.append(base + Vector2(cos(a) * r * 0.62, sin(a) * r * 0.28))
    for i in range(17):
        var a := PI - PI * i / 16.0
        rim.append(base + Vector2(cos(a) * r * 0.62, r * 0.6 * 0.45 + sin(a) * r * 0.05))
    draw_colored_polygon(rim, Color(0.3, 0.24, 0.16))

    if is_alive() and _phase == Phase.WHISTLING:
        _draw_whistle(head)


## Draw the sound waves of the whistle around the head, and the "!" above it.
func _draw_whistle(head: Vector2) -> void:
    var r := radius
    var progress := 1.0 - _phase_left / whistle_duration
    for i in range(3):
        var t := fmod(progress * 3.0 + i / 3.0, 1.0)
        var color := Color(1.0, 0.95, 0.7, 0.8 * (1.0 - t))
        for side: float in [-1.0, 1.0]:
            var center := head + Vector2(side * r * 0.2, -r * 0.05)
            var from := -0.6 if side > 0.0 else PI - 0.6
            draw_arc(center, r * (0.3 + 0.35 * t), from, from + 1.2, 10, color, r * 0.05, true)

    var bubble := head + Vector2(0, -r * 0.75)
    draw_circle(bubble, r * 0.2, Color(1, 1, 1, 0.9))
    draw_rect(
        Rect2(bubble + Vector2(-r * 0.03, -r * 0.13), Vector2(r * 0.06, r * 0.15)),
        Color(0.85, 0.3, 0.2)
    )
    draw_circle(bubble + Vector2(0, r * 0.1), r * 0.035, Color(0.85, 0.3, 0.2))
