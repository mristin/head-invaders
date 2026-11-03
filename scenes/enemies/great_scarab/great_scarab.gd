class_name GreatScarab

extends Enemy

## The great scarab, the shiny guardian of the desert, who comes at the end of
## the sixth level once all the others have fled. It crawls slowly to and fro
## at the top of the screen and hides behind its big, smiling sun ball, which
## slides over to shield it from the nearest spaceship. The bullets bounce off
## the sun ball, so the players have to fly around it, or team up and come
## from both sides.
##
## The scarab takes turns: it throws a fan of sand balls from its front legs,
## and every few turns it rolls its sun ball down the screen along a lane
## which shows a moment before. While the sun ball rolls away, the scarab has
## no shield, until a new one grows. When it is low on energy, it rolls more
## often, and the new sun ball shines sparks all around.

# NOTE (mristin):
# We load the scene lazily; a preload would be cyclic, since the sun ball
# refers back to the scarab.
const _SUN_BALL_SCENE_PATH: String = "res://scenes/enemies/sun_ball/sun_ball.tscn"

@export var descent_speed: float = 160.0

## How far the scarab crawls to and fro, in radii of the scarab.
@export var sway_amplitude: float = 2.0
@export var sway_frequency: float = 0.05

## The fan of sand balls: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.28

## It rolls its sun ball every so many turns, and more often in a hurry.
@export var roll_every: int = 3
@export var hurry_roll_every: int = 2

## Below this fraction of the energy, it attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.5
@export var hurry_factor: float = 1.3

@export var margin: float = 260.0

var _time: float = 0.0
var _descending: bool = true
var _attack: int = 0
var _sun_ball: SunBall = null


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SAND


## Return the sun ball which shields the scarab, or null before it comes.
func sun_ball() -> SunBall:
    if _sun_ball != null and is_instance_valid(_sun_ball):
        return _sun_ball
    return null


## Return true while the sun ball shields the scarab.
func is_shielded() -> bool:
    var ball := sun_ball()
    return ball != null and ball.is_alive() and ball.is_guarding()


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _may_fire() -> bool:
    return not _descending


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
            _call_sun_ball()
        return

    var bounds := get_viewport_rect()
    var x := home.x + sin(_time * TAU * sway_frequency) * sway_amplitude * radius
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)


func _call_sun_ball() -> void:
    var at := global_position + Vector2(0, radius * 1.25)
    _sun_ball = (load(_SUN_BALL_SCENE_PATH) as PackedScene).instantiate()
    _sun_ball.scarab = self
    # NOTE (mristin):
    # The sun ball is no alien to chase away, so it does not hold up the end
    # of the level, nor the clearing in the tests; see Enemy._others_fighting.
    _sun_ball.waits_for_others = true
    _sun_ball.spawned_in_place = true
    var enemies := get_parent() as Node2D
    _sun_ball.position = enemies.to_local(at) if enemies != null else at
    _minions.append(_sun_ball)
    get_parent().add_child.call_deferred(_sun_ball)
    Poof.spawn(self, at, radius * 0.5, Color(1.0, 0.8, 0.35))


func _fire_rocket() -> void:
    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    _attack += 1
    var every := hurry_roll_every if is_in_a_hurry() else roll_every
    var ball := sun_ball()
    if _attack % every == 0 and ball != null and ball.roll():
        return

    _throw_sand()


func _throw_sand() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    # NOTE (mristin):
    # The sand comes from the front leg on the side of the target, so that it
    # does not come out of the sun ball.
    var side := -1.0 if aim.x < 0.0 else 1.0
    var from := global_position + Vector2(side * radius * 0.6, radius * 0.35)
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(from, aim.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var hurry := is_in_a_hurry()
    var shell := Color(0.15, 0.55, 0.55).lerp(white, flash)
    var shell_light := Color(0.25, 0.72, 0.65).lerp(white, flash)
    var dark := Color(0.08, 0.3, 0.32).lerp(white, flash)
    var gold := Color(1.0, 0.78, 0.3).lerp(white, flash)

    # NOTE (mristin):
    # We see the scarab from above, facing down to the players: the legs,
    # the two wing covers, the head with the face and the little horn.
    for i in range(3):
        var y := lerpf(-r * 0.35, r * 0.25, i / 2.0)
        var step := sin(_time * 5.0 + i * 2.1) * r * 0.06
        for side: float in [-1.0, 1.0]:
            var hip := Vector2(side * r * 0.4, y)
            var knee := Vector2(side * r * 0.72, y - r * 0.1 + step)
            var foot := Vector2(side * r * 0.82, y + r * 0.12 + step)
            draw_line(hip, knee, dark, r * 0.07, true)
            draw_line(knee, foot, dark, r * 0.06, true)

    var body := PackedVector2Array()
    for i in range(40):
        var a := TAU * i / 40.0
        body.append(Vector2(cos(a) * r * 0.55, sin(a) * r * 0.5 - r * 0.1))
    draw_colored_polygon(body, shell)
    draw_line(Vector2(0, -r * 0.6), Vector2(0, r * 0.25), dark, r * 0.04, true)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.25, -r * 0.3), r * 0.16, shell_light)
        draw_circle(Vector2(side * r * 0.3, -r * 0.36), r * 0.06, Color(1, 1, 1, 0.35))
        # The golden spots on the wing covers.
        draw_circle(Vector2(side * r * 0.3, -r * 0.02), r * 0.05, gold)
        draw_circle(Vector2(side * r * 0.18, r * 0.12), r * 0.04, gold)

    var head := Vector2(0, r * 0.38)
    draw_circle(head, r * 0.27, shell_light)
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.08, r * 0.18),
                head + Vector2(0, r * 0.38),
                head + Vector2(r * 0.08, r * 0.18),
            ]
        ),
        gold
    )
    var brow := 0.05 if hurry else 0.0
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.12, -r * 0.02)
        draw_circle(eye, r * 0.085, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.045, Color(0.05, 0.12, 0.12))
        draw_circle(eye + Vector2(-r * 0.02, -r * 0.01), r * 0.018, white)
        draw_line(
            eye + Vector2(-side * r * 0.08, -r * (0.1 + brow)),
            eye + Vector2(side * r * 0.08, -r * 0.1),
            dark,
            r * 0.025
        )
        draw_circle(head + Vector2(side * r * 0.19, r * 0.1), r * 0.04, Color(1.0, 0.5, 0.5, 0.7))
    draw_arc(head + Vector2(0, r * 0.08), r * 0.07, 0.3, PI - 0.3, 10, dark, r * 0.025)
