class_name MirageFox

extends Enemy

## A fennec fox with big ears, gliding on a flying carpet in the upper part of
## the screen and throwing sand balls at the nearest spaceship. Every now and
## then it shimmers like a mirage in the hot air and splits into three foxes.
## Only one of them is real: the solid one with the energy bar, which throws
## the sand balls. The two mirages are see-through and wavy, and the bullets
## fly right through them. Hitting the real fox pops the mirages.

## How long the fox rests between the glides, in seconds.
@export var rest_duration: float = 2.4

## How long a glide takes, in seconds.
@export var glide_duration: float = 1.1

## How often the fox casts its mirage, and how long the mirage lasts.
@export var mirage_interval: float = 6.0
@export var mirage_duration: float = 6.0

## How far apart the three foxes of the mirage are, in radii of the fox.
@export var mirage_spacing: float = 3.6

## The fox throws this many sand balls at a time, this many seconds apart.
@export var burst_size: int = 1
@export var burst_interval: float = 0.25

## The fox stays above this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.42

@export var margin: float = 160.0

## How many times the fox cast its mirage so far, e.g., for the tests.
var mirages_cast: int = 0

var _time: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _glide_elapsed: float = 0.0
var _gliding: bool = false
var _rest_left: float = 0.0
var _burst_left: int = 0
var _burst_cooldown: float = 0.0

var _mirage_cooldown: float = 0.0
var _mirage_left: float = 0.0

## Where the mirages glide from and to, in the coordinates of the level.
var _copies_from: Array[Vector2] = []
var _copies_to: Array[Vector2] = []


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SAND
    _mirage_cooldown = mirage_interval * 0.5


## Return true while the mirages show.
func has_mirage() -> bool:
    return _mirage_left > 0.0


## Return the positions of the mirages in the coordinates of the level.
func mirage_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var t := _glide_t()
    for i in range(_copies_to.size()):
        result.append(_copies_from[i].lerp(_copies_to[i], t) + _bob())
    return result


func take_damage(amount: int) -> void:
    super(amount)
    if has_arrived() and has_mirage():
        _end_mirage()


func _enter() -> void:
    super()
    _glide_to(home)


func _random_spot() -> Vector2:
    var bounds := get_viewport_rect()
    return Vector2(
        randf_range(bounds.position.x + margin, bounds.end.x - margin),
        randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y * lowest)
    )


func _glide_to(to: Vector2) -> void:
    _from = position
    _to = to
    _glide_elapsed = 0.0
    _gliding = true


func _glide_t() -> float:
    if not _gliding:
        return 1.0
    return smoothstep(0.0, 1.0, clampf(_glide_elapsed / glide_duration, 0.0, 1.0))


func _bob() -> Vector2:
    return Vector2(0, sin(_time * 2.2) * 8.0)


func _cast_mirage() -> void:
    mirages_cast += 1
    _mirage_left = mirage_duration
    Poof.spawn(self, global_position, radius * 0.8, Color(1.0, 0.85, 0.6))

    # NOTE (mristin):
    # The three foxes line up side by side, and the real one takes a random
    # place among them.
    var bounds := get_viewport_rect()
    var spacing := radius * mirage_spacing
    var low := bounds.position.x + margin + spacing
    var high := bounds.end.x - margin - spacing
    var center := Vector2(clampf(position.x, low, high), clampf(position.y, 200.0, 400.0))
    var spots: Array[Vector2] = [
        center + Vector2(-spacing, 0), center, center + Vector2(spacing, 0)
    ]
    spots.shuffle()

    var start := position
    _glide_to(spots[0])
    _copies_from = [start, start]
    _copies_to = [spots[1], spots[2]]


func _end_mirage() -> void:
    for at in mirage_positions():
        Poof.spawn(self, to_global(at - position), radius * 0.6, Color(1.0, 0.85, 0.6))
    _mirage_left = 0.0
    _mirage_cooldown = mirage_interval
    _copies_from.clear()
    _copies_to.clear()


func _move(delta: float) -> void:
    _time += delta

    if _burst_left > 0:
        _burst_cooldown -= delta
        if _burst_cooldown <= 0.0:
            _burst_cooldown = burst_interval
            _burst_left -= 1
            var aim := _rocket_direction()
            if aim != Vector2.ZERO:
                _launch_rocket(aim, rocket_speed)

    if has_mirage():
        _mirage_left -= delta
        if _mirage_left <= 0.0:
            _end_mirage()
    else:
        _mirage_cooldown -= delta
        if _mirage_cooldown <= 0.0 and not _gliding:
            _cast_mirage()

    if _gliding:
        _glide_elapsed += delta
        position = _from.lerp(_to, _glide_t()) + _bob()
        if _glide_elapsed >= glide_duration:
            _gliding = false
            _copies_from = _copies_to.duplicate()
            _rest_left = rest_duration * randf_range(0.8, 1.2)
        return

    position = _to + _bob()
    if has_mirage():
        # NOTE (mristin):
        # The foxes of the mirage keep still, so that the players can find
        # the real one.
        return

    _rest_left -= delta
    if _rest_left <= 0.0:
        _glide_to(_random_spot())


func _fire_rocket() -> void:
    _burst_left = burst_size
    _burst_cooldown = 0.0


func _draw_body(flash: float) -> void:
    if is_alive():
        # NOTE (mristin):
        # The mirages wobble and shimmer, see-through, so that the solid fox
        # stands out once the players look closely.
        for at in mirage_positions():
            var offset := at - position
            var shimmer := sin(_time * 7.0 + offset.x) * radius * 0.05
            _draw_fox(offset + Vector2(shimmer, 0), 0.0, 0.42, 1.0 + 0.04 * sin(_time * 9.0))

    _draw_fox(Vector2.ZERO, flash, 1.0, 1.0)


func _draw_fox(at: Vector2, flash: float, alpha: float, stretch: float) -> void:
    var white := Color(1, 1, 1, alpha)
    var r := radius
    draw_set_transform(at, 0.0, Vector2(stretch, 2.0 - stretch))

    var fur := Color(0.98, 0.78, 0.5, alpha).lerp(white, flash)
    var cream := Color(1.0, 0.94, 0.82, alpha).lerp(white, flash)
    var ear_inside := Color(1.0, 0.6, 0.65, alpha).lerp(white, flash)
    var carpet := Color(0.75, 0.25, 0.45, alpha).lerp(white, flash)
    var trim := Color(1.0, 0.8, 0.3, alpha).lerp(white, flash)

    # NOTE (mristin):
    # The carpet ripples in the wind, with its tassels at the corners.
    var top := PackedVector2Array()
    var bottom := PackedVector2Array()
    for i in range(13):
        var t := i / 12.0
        var x := lerpf(-r * 0.75, r * 0.75, t)
        var wave := sin(_time * 5.0 + t * 5.0) * r * 0.05
        top.append(Vector2(x, r * 0.22 + wave))
        bottom.append(Vector2(x, r * 0.42 + wave))
    var carpet_shape := top.duplicate()
    bottom.reverse()
    carpet_shape.append_array(bottom)
    draw_colored_polygon(carpet_shape, carpet)
    draw_polyline(top, trim, r * 0.04, true)
    for side: float in [-1.0, 1.0]:
        var corner := Vector2(side * r * 0.75, r * 0.32)
        draw_line(corner, corner + Vector2(side * r * 0.12, r * 0.06), trim, r * 0.035)

    # The tail curls up beside it.
    draw_circle(Vector2(r * 0.42, r * 0.1), r * 0.16, fur)
    draw_circle(Vector2(r * 0.5, r * 0.0), r * 0.09, cream)

    # The body sits on the carpet, and the big ears stand up.
    draw_circle(Vector2(0, r * 0.1), r * 0.3, fur)
    draw_circle(Vector2(0, r * 0.16), r * 0.18, cream)
    for side: float in [-1.0, 1.0]:
        var ear := PackedVector2Array(
            [
                Vector2(side * r * 0.1, -r * 0.35),
                Vector2(side * r * 0.55, -r * 0.85),
                Vector2(side * r * 0.38, -r * 0.22),
            ]
        )
        draw_colored_polygon(ear, fur)
        var inside := PackedVector2Array(
            [
                Vector2(side * r * 0.17, -r * 0.35),
                Vector2(side * r * 0.47, -r * 0.72),
                Vector2(side * r * 0.34, -r * 0.3),
            ]
        )
        draw_colored_polygon(inside, ear_inside)

    var head := Vector2(0, -r * 0.25)
    draw_circle(head, r * 0.3, fur)
    draw_circle(head + Vector2(0, r * 0.12), r * 0.17, cream)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.12, -r * 0.03)
        draw_circle(eye, r * 0.075, Color(0.12, 0.08, 0.05, alpha))
        draw_circle(eye + Vector2(-r * 0.02, -r * 0.025), r * 0.028, white)
    draw_circle(head + Vector2(0, r * 0.08), r * 0.045, Color(0.15, 0.08, 0.06, alpha))
    draw_arc(
        head + Vector2(0, r * 0.12),
        r * 0.06,
        0.3,
        PI - 0.3,
        8,
        Color(0.3, 0.15, 0.1, alpha),
        r * 0.025
    )
    draw_set_transform(Vector2.ZERO, 0.0)
