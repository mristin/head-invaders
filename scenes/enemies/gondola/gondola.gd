class_name Gondola

extends Enemy

## A cheerful red cable car with big window eyes and a white cross on its
## side. It hangs from its cable, which is strung across the whole screen at
## a slant, so the players always see the line where the gondola will go. It
## slides along the cable from one station to the other and stops at each.
## At a stop, it rocks on its hanger, opens its door, and the passengers throw
## a fan of snowballs at the nearest spaceship.

enum Phase { ARRIVING, TRAVELLING, STOPPED }

## How high the cable is at the left and at the right end, relative to where
## the gondola is placed in the level, in pixels.
@export var cable_tilt: float = 120.0

## How far the stations are from the screen edges, in pixels.
@export var station_margin: float = 260.0

## How long a trip from one station to the other takes, and how long
## the gondola stops at each, in seconds.
@export var trip_duration: float = 4.0
@export var stop_duration: float = 2.2

## How fast the gondola slides in from the end of the cable.
@export var arrive_speed: float = 380.0

## The fan of snowballs: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.3

## How many trips the gondola made so far, e.g., for the tests.
var trips: int = 0

## How many times the passengers threw snowballs so far, e.g., for the tests.
var throws: int = 0

var _phase: Phase = Phase.ARRIVING
var _phase_time: float = 0.0
var _time: float = 0.0
var _station: int = 0
var _thrown: bool = false
var _swing: float = 0.0

## The ends of the cable, in the coordinates of the level.
var _cable_left: Vector2 = Vector2.ZERO
var _cable_right: Vector2 = Vector2.ZERO


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SNOWBALL


func is_stopped() -> bool:
    return _phase == Phase.STOPPED


func _may_fire() -> bool:
    # NOTE (mristin):
    # The passengers throw only at a stop; see _move.
    return false


## Return how far the cabin hangs below the cable.
func _hang() -> float:
    return radius * 0.95


## Return where the cabin hangs at the given x on the cable.
func _on_cable(x: float) -> Vector2:
    var t := inverse_lerp(_cable_left.x, _cable_right.x, x)
    return _cable_left.lerp(_cable_right, t) + Vector2(0, _hang())


func _station_x(index: int) -> float:
    var bounds := get_viewport_rect()
    if index == 0:
        return bounds.position.x + station_margin
    return bounds.end.x - station_margin


func _enter() -> void:
    var bounds := get_viewport_rect()
    var tilt := cable_tilt if randf() < 0.5 else -cable_tilt
    var y := home.y - _hang()
    _cable_left = Vector2(bounds.position.x - 200.0, y - tilt)
    _cable_right = Vector2(bounds.end.x + 200.0, y + tilt)

    # NOTE (mristin):
    # The gondola comes in from the end of the cable nearer to its place, and
    # heads for the station on that side.
    _station = 0 if home.x < bounds.get_center().x else 1
    var from_x := bounds.position.x - radius * 1.5 if _station == 0 else bounds.end.x + radius * 1.5
    if spawned_in_place:
        from_x = position.x
    position = _on_cable(from_x)
    _phase = Phase.ARRIVING


func _move(delta: float) -> void:
    _time += delta
    _phase_time += delta
    _swing = move_toward(_swing, 0.0, delta * 0.25)

    match _phase:
        Phase.ARRIVING:
            var target := _on_cable(_station_x(_station))
            position = position.move_toward(target, arrive_speed * delta)
            if position.is_equal_approx(target):
                _stop()
        Phase.TRAVELLING:
            var t := clampf(_phase_time / trip_duration, 0.0, 1.0)
            var x := lerpf(_station_x(1 - _station), _station_x(_station), smoothstep(0.0, 1.0, t))
            position = _on_cable(x)
            if t >= 1.0:
                trips += 1
                _stop()
        Phase.STOPPED:
            if not _thrown and _phase_time > stop_duration * 0.45:
                _thrown = true
                _throw()
            if _phase_time >= stop_duration:
                _station = 1 - _station
                _phase = Phase.TRAVELLING
                _phase_time = 0.0


func _stop() -> void:
    _phase = Phase.STOPPED
    _phase_time = 0.0
    _thrown = false
    # NOTE (mristin):
    # The cabin rocks on its hanger when it stops.
    _swing = 0.35


func _throw() -> void:
    if not get_viewport_rect().has_point(global_position):
        return
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    throws += 1
    var from := global_position + Vector2(0, radius * 0.35)
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(from, aim.rotated(angle), rocket_speed)


func _energy_bar_y() -> float:
    return radius * 0.72


func _draw() -> void:
    if is_alive() and has_arrived():
        # NOTE (mristin):
        # The cable goes across the whole screen, with a soft shadow, so that
        # the players see where the gondola will slide.
        var left := to_local(_cable_left)
        var right := to_local(_cable_right)
        draw_line(left + Vector2(10, 16), right + Vector2(10, 16), Color(0, 0, 0, 0.25), 6.0, true)
        draw_line(left, right, Color(0.12, 0.12, 0.14), 6.0, true)
        draw_line(left, right, Color(0.55, 0.55, 0.6), 2.0, true)
    super()


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var red := Color(0.85, 0.18, 0.15).lerp(white, flash)
    var dark_red := Color(0.6, 0.1, 0.1).lerp(white, flash)
    var metal := Color(0.5, 0.5, 0.55).lerp(white, flash)
    var glass := Color(0.75, 0.88, 0.95).lerp(white, flash)
    var dark := Color(0.12, 0.1, 0.12)

    # NOTE (mristin):
    # The cabin rocks a bit after each stop, around the wheels on the cable.
    var pivot := Vector2(0, -_hang())
    var angle := _swing * sin(_time * 5.0)
    if _phase == Phase.TRAVELLING:
        angle += sin(_time * 1.5) * 0.03
    draw_set_transform(pivot, angle)

    # The wheels on the cable and the hanger.
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.14, 0), r * 0.09, metal)
        draw_circle(Vector2(side * r * 0.14, 0), r * 0.04, dark)
    draw_rect(Rect2(Vector2(-r * 0.22, -r * 0.03), Vector2(r * 0.44, r * 0.1)), metal)
    draw_line(Vector2(0, r * 0.05), Vector2(0, r * 0.45), metal, r * 0.07)

    # The cabin: the roof, the red body, the windows as eyes and a smile.
    var top := r * 0.45
    draw_rect(Rect2(Vector2(-r * 0.55, top), Vector2(r * 1.1, r * 0.12)), dark_red)
    draw_rect(Rect2(Vector2(-r * 0.62, top + r * 0.1), Vector2(r * 1.24, r * 1.0)), red)
    draw_rect(Rect2(Vector2(-r * 0.62, top + r * 1.0), Vector2(r * 1.24, r * 0.12)), dark_red)

    var open := _phase == Phase.STOPPED and _phase_time > stop_duration * 0.25
    for side: float in [-1.0, 1.0]:
        var window := Rect2(
            Vector2(side * r * 0.29 - r * 0.22, top + r * 0.2), Vector2(r * 0.44, r * 0.36)
        )
        draw_rect(window, glass)
        draw_rect(window, white, false, r * 0.03)
        # The pupils look at the nearest spaceship, more or less.
        var look := Vector2(0, r * 0.04)
        var target := _nearest_spaceship()
        if target != null:
            look = global_position.direction_to(target.global_position) * r * 0.06
        var eye := window.get_center() + look
        draw_circle(eye, r * 0.1, dark)
        draw_circle(eye + Vector2(-r * 0.03, -r * 0.03), r * 0.035, white)
        draw_circle(Vector2(side * r * 0.42, top + r * 0.68), r * 0.06, Color(1.0, 0.55, 0.55, 0.8))

    if open:
        draw_circle(Vector2(0, top + r * 0.78), r * 0.1, dark)
    else:
        draw_arc(Vector2(0, top + r * 0.68), r * 0.14, 0.3, PI - 0.3, 12, dark, r * 0.04)

    # The white cross on the red, like a little flag on the side.
    var cross := Vector2(r * 0.4, top + r * 0.86)
    draw_rect(Rect2(cross + Vector2(-r * 0.09, -r * 0.03), Vector2(r * 0.18, r * 0.06)), white)
    draw_rect(Rect2(cross + Vector2(-r * 0.03, -r * 0.09), Vector2(r * 0.06, r * 0.18)), white)
    draw_set_transform(Vector2.ZERO, 0.0)
