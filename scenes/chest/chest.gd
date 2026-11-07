class_name Chest

extends Area2D

## A treasure chest floating down the screen. The players shoot it open, and it
## gives out a booster. The boosters come only from the chests, so that the
## players have to earn them.
##
## The chests come in several looks, from a wooden treasure chest to a painted
## egg, so that each one is a little surprise.
##
## The chest is on its own collision layer, which the bullets and the missiles
## scan, but not the spaceships. It is not an enemy: it does not fire, does
## not hurt anybody, and the level does not wait for it.

enum Style { WOODEN, ROYAL, GIFT, CRYSTAL, CAPSULE, EGG }

const GROUP: String = "chests"

const _SCENE_PATH: String = "res://scenes/chest/chest.tscn"

## How many gold coins show how sturdy the chest still is.
const _COINS: int = 8

## How sturdy the chest is. Like the energy of the enemies, it counts in tenths
## of a hit, so a bullet takes 13.
@export var max_strength: int = 80

@export var fall_speed: float = 70.0
@export var sway_amplitude: float = 40.0
@export var radius: float = 84.0

## Give a booster of one of these kinds; of any kind if empty.
@export var kinds: Array[Pickup.Kind] = []

## How long the open chest stays before it fades away, in seconds.
@export var open_duration: float = 0.8

var strength_left: int = 0

var style: Style = Style.WOODEN

var _time: float = 0.0
var _base_x: float = 0.0
var _shake: float = 0.0
var _opened_for: float = -1.0


## Drop a chest at the given global position in the current level, in one of
## the given styles, or in any style if none are given. The chest gives
## a booster of one of the given kinds, or of any kind if none are given.
static func drop(
    near: Node,
    global_pos: Vector2,
    styles: Array[Style] = [],
    booster_kinds: Array[Pickup.Kind] = []
) -> void:
    var projectiles := Projectiles.of(near)
    if projectiles == null:
        return

    var chest: Chest = load(_SCENE_PATH).instantiate()
    chest.style = Style.values().pick_random() if styles.is_empty() else styles.pick_random()
    chest.kinds = booster_kinds
    projectiles.launch(chest, global_pos)


func _ready() -> void:
    add_to_group(GROUP)
    strength_left = max_strength
    _base_x = position.x
    _time = randf() * TAU


func is_open() -> bool:
    return _opened_for >= 0.0


func take_damage(amount: int) -> void:
    if is_open():
        return

    strength_left = maxi(0, strength_left - amount)
    _shake = 0.15
    if strength_left == 0:
        _open()
    queue_redraw()


func _open() -> void:
    _opened_for = 0.0
    set_deferred("monitorable", false)
    Poof.spawn(self, global_position, radius * 1.2, Color(1.0, 0.85, 0.3))

    var kind: Pickup.Kind = (
        Pickup.Kind.values().pick_random() if kinds.is_empty() else kinds.pick_random()
    )
    Pickup.drop(self, global_position, kind)


func _physics_process(delta: float) -> void:
    _time += delta
    _shake = maxf(0.0, _shake - delta)

    if is_open():
        _opened_for += delta
        if _opened_for >= open_duration:
            queue_free()
        queue_redraw()
        return

    position.y += fall_speed * delta
    position.x = _base_x + sin(_time * 1.2) * sway_amplitude

    if global_position.y > get_viewport_rect().end.y + radius * 2.0:
        queue_free()
        return

    queue_redraw()


func _draw() -> void:
    var r := radius
    var flash := clampf(_shake / 0.15, 0.0, 1.0)
    var t := clampf(_opened_for / open_duration, 0.0, 1.0) if is_open() else 0.0
    modulate.a = 1.0 - t

    # NOTE (mristin):
    # The chest wiggles when hit, and glows a little so that it stands out.
    var wiggle := sin(_time * 60.0) * 0.12 * flash
    draw_set_transform(Vector2.ZERO, wiggle)

    var glow := 0.5 + 0.5 * sin(_time * 3.0)
    draw_circle(Vector2.ZERO, r * (1.2 + 0.08 * glow), Color(1.0, 0.85, 0.3, 0.12))

    # The open chest lets out the light of the treasure.
    if is_open():
        draw_circle(Vector2(0, -r * 0.2), r * (0.5 + 0.4 * t), Color(1.0, 0.9, 0.4, 0.6))

    match style:
        Style.ROYAL:
            _draw_royal(r, flash)
        Style.GIFT:
            _draw_gift(r, flash)
        Style.CRYSTAL:
            _draw_crystal(r, flash)
        Style.CAPSULE:
            _draw_capsule(r, flash)
        Style.EGG:
            _draw_egg(r, flash)
        _:
            _draw_wooden(r, flash)

    draw_set_transform(Vector2.ZERO, 0.0)

    if is_open():
        return

    # NOTE (mristin):
    # The gold coins below show how much more it takes to open the chest.
    var spacing := minf(r * 0.28, r * 2.0 / _COINS)
    var coins_left := ceili(float(_COINS * strength_left) / float(max_strength))
    for i in range(_COINS):
        var center := Vector2((i - (_COINS - 1) / 2.0) * spacing, r * 0.98)
        var coin := Color(1.0, 0.8, 0.25) if i < coins_left else Color(0.2, 0.15, 0.1, 0.8)
        draw_circle(center, spacing * 0.38, coin)


func _lit(color: Color, flash: float) -> Color:
    return color.lerp(Color(1, 1, 1), flash * 0.6)


## Return the points of a half ellipse arching up from the given center.
func _dome(center: Vector2, width: float, height: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(17):
        var angle := PI + PI * i / 16.0
        points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
    return points


func _draw_wooden(r: float, flash: float) -> void:
    var wood := _lit(Color(0.6, 0.35, 0.15), flash)
    var dark_wood := _lit(Color(0.42, 0.22, 0.08), flash)
    var gold := _lit(Color(1.0, 0.8, 0.25), flash)

    draw_rect(Rect2(Vector2(-r, -r * 0.2), Vector2(r * 2.0, r * 0.95)), wood)
    draw_rect(Rect2(Vector2(-r, r * 0.3), Vector2(r * 2.0, r * 0.08)), dark_wood)
    if is_open():
        draw_rect(Rect2(Vector2(-r, -r * 0.95), Vector2(r * 2.0, r * 0.35)), dark_wood)
    else:
        draw_colored_polygon(_dome(Vector2(0, -r * 0.2), r, r * 0.55), dark_wood)
        draw_rect(Rect2(Vector2(-r * 0.15, -r * 0.35), Vector2(r * 0.3, r * 0.4)), gold)
        draw_circle(Vector2(0, -r * 0.12), r * 0.06, dark_wood)
    for x: float in [-0.7, 0.7]:
        draw_rect(Rect2(Vector2(x * r - r * 0.08, -r * 0.6), Vector2(r * 0.16, r * 1.35)), gold)


func _draw_royal(r: float, flash: float) -> void:
    var purple := _lit(Color(0.5, 0.2, 0.65), flash)
    var dark_purple := _lit(Color(0.35, 0.12, 0.48), flash)
    var gold := _lit(Color(1.0, 0.8, 0.25), flash)

    draw_rect(Rect2(Vector2(-r * 0.95, -r * 0.2), Vector2(r * 1.9, r * 0.95)), purple)
    draw_rect(Rect2(Vector2(-r * 0.95, -r * 0.2), Vector2(r * 1.9, r * 0.12)), gold)
    draw_rect(Rect2(Vector2(-r * 0.95, r * 0.63), Vector2(r * 1.9, r * 0.12)), gold)

    # NOTE (mristin):
    # The gems sparkle in turns.
    var gems: Array[Color] = [Color(1.0, 0.3, 0.35), Color(0.3, 0.6, 1.0), Color(0.3, 0.9, 0.5)]
    for i in range(3):
        var center := Vector2((i - 1) * r * 0.55, r * 0.3)
        var on := fmod(_time * 2.0 + i, 3.0) < 1.0
        draw_circle(center, r * 0.13, gold)
        draw_circle(center, r * 0.09, _lit(gems[i].lightened(0.3 if on else 0.0), flash))

    if is_open():
        draw_rect(Rect2(Vector2(-r * 0.95, -r * 0.95), Vector2(r * 1.9, r * 0.35)), dark_purple)
        return

    draw_colored_polygon(_dome(Vector2(0, -r * 0.2), r * 0.95, r * 0.5), dark_purple)
    var crown := PackedVector2Array(
        [
            Vector2(-r * 0.3, -r * 0.25),
            Vector2(-r * 0.35, -r * 0.6),
            Vector2(-r * 0.15, -r * 0.42),
            Vector2(0, -r * 0.68),
            Vector2(r * 0.15, -r * 0.42),
            Vector2(r * 0.35, -r * 0.6),
            Vector2(r * 0.3, -r * 0.25),
        ]
    )
    draw_colored_polygon(crown, gold)


func _draw_gift(r: float, flash: float) -> void:
    var pink := _lit(Color(1.0, 0.45, 0.6), flash)
    var ribbon := _lit(Color(1.0, 0.85, 0.3), flash)

    draw_rect(Rect2(Vector2(-r * 0.85, -r * 0.3), Vector2(r * 1.7, r * 1.05)), pink)
    for dot: Vector2 in [
        Vector2(-0.55, 0.0), Vector2(0.5, 0.45), Vector2(-0.45, 0.5), Vector2(0.55, -0.1)
    ]:
        draw_circle(dot * r, r * 0.08, Color(1, 1, 1, 0.6))
    draw_rect(Rect2(Vector2(-r * 0.12, -r * 0.3), Vector2(r * 0.24, r * 1.05)), ribbon)

    # NOTE (mristin):
    # The lid with the bow flies off when the gift opens.
    var lift := (
        Vector2(r * 0.3, -r * 0.9) * clampf(_opened_for * 3.0, 0.0, 1.0)
        if is_open()
        else Vector2.ZERO
    )
    var lid_tilt := 0.6 * clampf(_opened_for * 3.0, 0.0, 1.0) if is_open() else 0.0
    draw_set_transform(lift, lid_tilt + sin(_time * 60.0) * 0.12 * flash)
    draw_rect(
        Rect2(Vector2(-r * 0.95, -r * 0.5), Vector2(r * 1.9, r * 0.25)),
        _lit(Color(0.9, 0.35, 0.5), flash)
    )
    draw_rect(Rect2(Vector2(-r * 0.12, -r * 0.5), Vector2(r * 0.24, r * 0.25)), ribbon)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.25, -r * 0.65), r * 0.2, ribbon)
        draw_circle(Vector2(side * r * 0.25, -r * 0.65), r * 0.1, pink)
    draw_circle(Vector2(0, -r * 0.58), r * 0.11, ribbon)
    draw_set_transform(Vector2.ZERO, sin(_time * 60.0) * 0.12 * flash)


func _draw_crystal(r: float, flash: float) -> void:
    var ice := _lit(Color(0.5, 0.85, 1.0, 0.85), flash)
    var edge := Color(1, 1, 1, 0.8)

    # NOTE (mristin):
    # The crystal splits in two when it opens.
    var apart := r * 0.5 * clampf(_opened_for * 3.0, 0.0, 1.0) if is_open() else 0.0
    for side: float in [-1.0, 1.0]:
        var shift := Vector2(side * apart, 0)
        var half := PackedVector2Array(
            [
                shift + Vector2(0, -r * 0.8),
                shift + Vector2(side * r * 0.6, -r * 0.45),
                shift + Vector2(side * r * 0.75, r * 0.15),
                shift + Vector2(side * r * 0.4, r * 0.7),
                shift + Vector2(0, r * 0.75),
            ]
        )
        draw_colored_polygon(half, ice)
        draw_polyline(half, edge, r * 0.04, true)
        draw_line(
            shift + Vector2(0, -r * 0.8),
            shift + Vector2(side * r * 0.4, r * 0.7),
            Color(1, 1, 1, 0.35),
            r * 0.03
        )

    if not is_open():
        Poof.draw_twinkle(
            self,
            Vector2(-r * 0.3, -r * 0.35),
            r * 0.16,
            _time * 2.0,
            Color(1, 1, 1, 0.5 + 0.5 * sin(_time * 4.0))
        )
        draw_circle(Vector2(r * 0.05, 0), r * 0.18, _lit(Color(1.0, 0.85, 0.3), flash))


func _draw_capsule(r: float, flash: float) -> void:
    var metal := _lit(Color(0.62, 0.66, 0.74), flash)
    var dark_metal := _lit(Color(0.42, 0.45, 0.55), flash)

    # NOTE (mristin):
    # The capsule's halves slide apart when it opens.
    var apart := r * 0.45 * clampf(_opened_for * 3.0, 0.0, 1.0) if is_open() else 0.0
    for side: float in [-1.0, 1.0]:
        var inner := side * apart
        var outer := side * (r * 0.42 + apart)
        draw_circle(Vector2(outer, 0), r * 0.55, metal)
        draw_rect(Rect2(Vector2(minf(inner, outer), -r * 0.55), Vector2(r * 0.42, r * 1.1)), metal)
        draw_line(Vector2(inner, 0), Vector2(outer + side * r * 0.5, 0), dark_metal, r * 0.05)

    if is_open():
        return

    draw_line(Vector2(0, -r * 0.55), Vector2(0, r * 0.55), dark_metal, r * 0.05)
    draw_circle(Vector2(0, -r * 0.05), r * 0.24, dark_metal)
    draw_circle(Vector2(0, -r * 0.05), r * 0.18, _lit(Color(0.5, 0.95, 1.0), flash))
    var blink := fmod(_time * 2.0, 1.0) < 0.5
    for side: float in [-1.0, 1.0]:
        var light := Color(0.4, 1.0, 0.5) if blink == (side > 0.0) else Color(0.2, 0.4, 0.25)
        draw_circle(Vector2(side * r * 0.6, -r * 0.2), r * 0.08, light)


## Return the point on the egg's outline at the given angle; the egg is wider
## at the bottom.
func _egg_point(r: float, angle: float) -> Vector2:
    var y := sin(angle)
    var width := r * 0.72 * (1.0 + 0.18 * minf(0.0, y))
    return Vector2(cos(angle) * width, y * r * 0.9)


func _draw_egg(r: float, flash: float) -> void:
    var shell := _lit(Color(1.0, 0.95, 0.8), flash)
    var stripes: Array[Color] = [Color(0.4, 0.75, 1.0), Color(1.0, 0.5, 0.6), Color(0.5, 0.9, 0.5)]

    # NOTE (mristin):
    # The top of the egg cracks off along a zigzag when it opens.
    var crack_y := -r * 0.15
    var crack_angle := asin(crack_y / (r * 0.9))
    var crack_x := _egg_point(r, crack_angle).x
    var lift := r * 0.7 * clampf(_opened_for * 3.0, 0.0, 1.0) if is_open() else 0.0

    var zigzag := PackedVector2Array()
    for i in range(9):
        var x := -crack_x + 2.0 * crack_x * i / 8.0
        zigzag.append(Vector2(x, crack_y + (r * 0.08 if i % 2 == 0 else -r * 0.08)))

    # The bottom goes from the right through the bottom to the left, then back
    # along the zigzag.
    var bottom := PackedVector2Array()
    for i in range(17):
        bottom.append(_egg_point(r, lerpf(crack_angle, PI - crack_angle, i / 16.0)))
    bottom.append_array(zigzag)
    draw_colored_polygon(bottom, shell)

    # The top goes from the left over the top to the right, then back along
    # the zigzag.
    var top := PackedVector2Array()
    for i in range(17):
        top.append(_egg_point(r, lerpf(PI - crack_angle, TAU + crack_angle, i / 16.0)))
    var back := zigzag.duplicate()
    back.reverse()
    top.append_array(back)
    for i in range(top.size()):
        top[i].y -= lift
    draw_colored_polygon(top, shell)

    for i in range(3):
        var y := -r * 0.5 + i * r * 0.45
        var shift := lift if y < crack_y else 0.0
        var points := PackedVector2Array()
        for j in range(9):
            var x := -r * 0.55 + r * 1.1 * j / 8.0
            points.append(Vector2(x, y - shift + (r * 0.07 if j % 2 == 0 else -r * 0.07)))
        draw_polyline(points, _lit(stripes[i], flash), r * 0.08, true)
