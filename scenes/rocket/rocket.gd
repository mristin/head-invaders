class_name Rocket

extends Area2D

## A rocket fired by an enemy. It flies in a straight line and damages the first
## spaceship it hits.
##
## The rocket only scans the spaceships' collision layer, so it never hits
## the enemies, nor the other rockets.
##
## The rockets of the forest, the sea and the lava look like the spores,
## the acorns, the bubbles, the fireballs and so on, but fly and hit just
## the same.
##
## Some rockets fall in an arc, like the lava blobs of a volcano, and some burst
## into smaller ones, like the boulders of a golem.

enum Look {
    ROCKET,
    SPORE,
    ACORN,
    BUBBLE,
    INK,
    ZAP,
    PEARL,
    FIREBALL,
    COAL,
    BOULDER,
    NEEDLE,
    SAND,
    TWISTER,
    COFFEE_BEAN,
    BANKNOTE,
    COIN,
    SNOWBALL,
    ICICLE,
    SNOWFLAKE,
    NOTE,
    PINE_CONE,
    SANDBAG,
    RAINDROP,
    PAPER_DART,
}

## How many times bigger we draw the rockets and their collision shape, so
## that they are easy to see on a small screen from a distance.
const SIZE: float = 2.0

const _SCENE_PATH: String = "res://scenes/rocket/rocket.tscn"

## How many rockets burst so far, e.g., for the tests.
static var bursts: int = 0

@export var damage: int = 1
@export var lifetime: float = 8.0

var velocity: Vector2 = Vector2.ZERO

var look: Look = Look.ROCKET

## Draw and collide this many times bigger still than SIZE, e.g., for
## the banker's money.
var size_factor: float = 1.0

## Pull the rocket down, in pixels per second squared; zero flies straight.
var fall_acceleration: float = 0.0

## Burst into smaller rockets after this many seconds; negative never bursts.
var burst_after: float = -1.0
var burst_count: int = 5
var burst_spread: float = 1.2
var burst_look: Look = Look.COAL

var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
    area_entered.connect(_on_area_entered)
    rotation = velocity.angle()
    scale = Vector2.ONE * SIZE * size_factor


func _physics_process(delta: float) -> void:
    if fall_acceleration != 0.0:
        velocity.y += fall_acceleration * delta
        rotation = velocity.angle()

    position += velocity * delta
    _age += delta

    if burst_after >= 0.0 and _age >= burst_after:
        _burst()
        return

    # NOTE (mristin):
    # A falling rocket may fly above the screen for a while before it comes
    # back down.
    var bounds := get_viewport_rect().grow(40.0 * SIZE)
    if fall_acceleration > 0.0:
        bounds = bounds.grow_side(SIDE_TOP, bounds.size.y)
    if _age > lifetime or not bounds.has_point(global_position):
        queue_free()
        return

    queue_redraw()


func _burst() -> void:
    bursts += 1
    var projectiles := Projectiles.of(self)
    if projectiles != null:
        var scene: PackedScene = load(_SCENE_PATH)
        var speed := velocity.length()
        var heading := velocity.normalized() if speed > 0.0 else Vector2.DOWN
        for i in range(burst_count):
            var t := (i / float(maxi(1, burst_count - 1))) - 0.5
            var pebble: Rocket = scene.instantiate()
            pebble.velocity = heading.rotated(t * burst_spread) * maxf(speed * 1.3, 250.0)
            pebble.look = burst_look
            pebble.lifetime = lifetime
            projectiles.launch(pebble, global_position)
    Poof.spawn(self, global_position, 30.0, Color(1.0, 0.6, 0.3))
    queue_free()


func _on_area_entered(area: Area2D) -> void:
    if _spent:
        return

    var spaceship := area as Spaceship
    if spaceship == null or not spaceship.is_alive():
        return

    _spent = true
    spaceship.take_damage(damage)
    Poof.spawn(self, global_position, 24.0, Color(1.0, 0.5, 0.2))
    queue_free()


func _draw() -> void:
    match look:
        Look.SPORE:
            _draw_spore()
        Look.ACORN:
            _draw_acorn()
        Look.BUBBLE:
            _draw_bubble()
        Look.INK:
            _draw_ink()
        Look.ZAP:
            _draw_zap()
        Look.PEARL:
            _draw_pearl()
        Look.FIREBALL:
            _draw_fireball()
        Look.COAL:
            _draw_coal()
        Look.BOULDER:
            _draw_boulder()
        Look.NEEDLE:
            _draw_needle()
        Look.SAND:
            _draw_sand()
        Look.TWISTER:
            _draw_twister()
        Look.COFFEE_BEAN:
            _draw_coffee_bean()
        Look.BANKNOTE:
            _draw_banknote()
        Look.COIN:
            _draw_coin()
        Look.SNOWBALL:
            _draw_snowball()
        Look.ICICLE:
            _draw_icicle()
        Look.SNOWFLAKE:
            _draw_snowflake()
        Look.NOTE:
            _draw_note()
        Look.PINE_CONE:
            _draw_pine_cone()
        Look.SANDBAG:
            _draw_sandbag()
        Look.RAINDROP:
            _draw_raindrop()
        Look.PAPER_DART:
            _draw_paper_dart()
        _:
            _draw_rocket()


func _draw_spore() -> void:
    # NOTE (mristin):
    # The spore glows and wobbles, bright enough to see on the dark forest.
    var wobble := 1.0 + 0.12 * sin(_age * 18.0)
    draw_circle(Vector2.ZERO, 17.0 * wobble, Color(0.9, 1.0, 0.4, 0.25))
    draw_circle(Vector2.ZERO, 11.0 * wobble, Color(0.85, 1.0, 0.35))
    draw_arc(Vector2.ZERO, 11.0 * wobble, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 2.5, true)
    draw_circle(Vector2(-3.5, -3.5), 3.0, Color(1, 1, 1, 0.8))


func _draw_acorn() -> void:
    # NOTE (mristin):
    # The acorn tumbles as it flies, with a bright outline for the dark forest.
    draw_set_transform(Vector2.ZERO, _age * 8.0, Vector2(1.4, 1.4))
    draw_circle(Vector2(0, 3), 13.0, Color(1, 1, 1, 0.85))
    draw_circle(Vector2(0, 3), 10.5, Color(0.95, 0.7, 0.35))
    draw_rect(Rect2(-12, -9, 24, 9), Color(1, 1, 1, 0.85))
    draw_rect(Rect2(-10.5, -7.5, 21, 7), Color(0.55, 0.35, 0.15))
    draw_line(Vector2(0, -8), Vector2(2, -14), Color(0.55, 0.35, 0.15), 3.0)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_bubble() -> void:
    var wobble := Vector2(1.0 + 0.08 * sin(_age * 12.0), 1.0 - 0.08 * sin(_age * 12.0))
    draw_set_transform(Vector2.ZERO, 0.0, wobble)
    draw_circle(Vector2.ZERO, 13.0, Color(0.6, 0.9, 1.0, 0.35))
    draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(0.9, 0.98, 1.0), 3.0, true)
    draw_circle(Vector2(-4.5, -4.5), 3.5, Color(1, 1, 1, 0.9))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_ink() -> void:
    # NOTE (mristin):
    # The dark ink gets a bright outline, so that it shows on the dark water.
    var points := PackedVector2Array()
    for i in range(16):
        var angle := TAU * i / 16.0
        var r := 12.0 * (1.0 + 0.15 * sin(angle * 3.0 + _age * 10.0))
        points.append(Vector2(cos(angle), sin(angle)) * r)
    draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.6, 0.9, 0.9))
    draw_colored_polygon(points, Color(0.3, 0.08, 0.4))


func _draw_zap() -> void:
    draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.95, 0.4, 0.3))
    Poof.draw_twinkle(self, Vector2.ZERO, 14.0, _age * 12.0, Color(1.0, 0.95, 0.45))
    Poof.draw_twinkle(self, Vector2.ZERO, 7.0, -_age * 12.0, Color(1, 1, 1))


func _draw_pearl() -> void:
    draw_circle(Vector2.ZERO, 17.0, Color(1, 1, 1, 0.3))
    draw_circle(Vector2.ZERO, 13.0, Color(0.97, 0.94, 1.0))
    draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(1.0, 0.75, 0.9), 2.5, true)
    draw_circle(Vector2(-4.0, -4.0), 4.0, Color(1, 1, 1))


func _draw_fireball() -> void:
    # NOTE (mristin):
    # The fireball points along the positive x-axis, with the flames trailing
    # behind. The bright core and the white outline stand out on the lava.
    var flicker := 1.0 + 0.2 * sin(_age * 40.0)
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, -11), Vector2(-30 * flicker, 0), Vector2(0, 11)]),
        Color(1.0, 0.45, 0.1, 0.8)
    )
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, -7), Vector2(-20 * flicker, 0), Vector2(0, 7)]),
        Color(1.0, 0.8, 0.2, 0.9)
    )
    draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.9))
    draw_circle(Vector2.ZERO, 11.5, Color(1.0, 0.6, 0.15))
    draw_circle(Vector2(2, 0), 6.5, Color(1.0, 0.95, 0.6))


func _draw_coal() -> void:
    draw_set_transform(Vector2.ZERO, _age * 6.0)
    var lump := PackedVector2Array()
    for i in range(7):
        var angle := TAU * i / 7.0
        lump.append(Vector2(cos(angle), sin(angle)) * (11.0 if i % 2 == 0 else 9.0))
    draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.75, 0.4, 0.9))
    draw_colored_polygon(lump, Color(0.22, 0.13, 0.1))
    draw_line(Vector2(-5, -2), Vector2(4, 3), Color(1.0, 0.5, 0.15), 2.5)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_boulder() -> void:
    draw_set_transform(Vector2.ZERO, _age * 4.0)
    var rock := PackedVector2Array()
    for i in range(9):
        var angle := TAU * i / 9.0
        rock.append(Vector2(cos(angle), sin(angle)) * (21.0 if i % 3 == 0 else 18.0))
    draw_circle(Vector2.ZERO, 24.0, Color(1, 1, 1, 0.85))
    draw_colored_polygon(rock, Color(0.45, 0.38, 0.35))
    var glow := 0.6 + 0.4 * sin(_age * 15.0)
    draw_line(Vector2(-12, -6), Vector2(0, 2), Color(1.0, 0.5, 0.1, glow), 3.5)
    draw_line(Vector2(0, 2), Vector2(10, -4), Color(1.0, 0.5, 0.1, glow), 3.5)
    draw_line(Vector2(0, 2), Vector2(4, 13), Color(1.0, 0.5, 0.1, glow), 3.5)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_needle() -> void:
    # NOTE (mristin):
    # The cactus needle points along the positive x-axis, with a bright outline
    # so that it shows on the dim sand.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.8, 0.8))
    var needle := PackedVector2Array(
        [Vector2(24, 0), Vector2(-14, -6), Vector2(-18, 0), Vector2(-14, 6)]
    )
    var outline := PackedVector2Array(
        [Vector2(30, 0), Vector2(-17, -9.5), Vector2(-23, 0), Vector2(-17, 9.5)]
    )
    draw_colored_polygon(outline, Color(1, 1, 1, 0.95))
    draw_colored_polygon(needle, Color(0.55, 1.0, 0.45))
    draw_line(Vector2(-12, 0), Vector2(18, 0), Color(0.95, 1.0, 0.75), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_sand() -> void:
    # NOTE (mristin):
    # A tumbling ball of sand, brighter than the dunes and outlined in white.
    draw_set_transform(Vector2.ZERO, _age * 5.0, Vector2(0.75, 0.75))
    draw_circle(Vector2.ZERO, 16.0, Color(1, 1, 1, 0.95))
    draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.72, 0.3))
    draw_circle(Vector2(3, 2), 7.0, Color(1.0, 0.85, 0.5))
    for i in range(3):
        var at := Vector2.RIGHT.rotated(TAU * i / 3.0) * 7.5
        draw_circle(at, 2.2, Color(0.85, 0.5, 0.2))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_twister() -> void:
    # NOTE (mristin):
    # The little whirlwind stays upright however it flies; it is a funnel of
    # bright, spinning rings.
    draw_set_transform(Vector2.ZERO, -rotation, Vector2(0.55, 0.55))
    draw_circle(Vector2(0, 2), 30.0, Color(1.0, 0.9, 0.6, 0.3))
    draw_colored_polygon(
        PackedVector2Array([Vector2(-27, -24), Vector2(27, -24), Vector2(8, 24), Vector2(-8, 24)]),
        Color(1.0, 0.8, 0.45, 0.55)
    )
    for i in range(5):
        var t := i / 4.0
        var y := lerpf(-22.0, 22.0, t)
        var width := lerpf(26.0, 7.0, t)
        var sway := sin(_age * 9.0 + t * 3.0) * 4.0
        var center := Vector2(sway, y)
        var spin := _age * 14.0 + t * 2.0
        draw_arc(center, width, spin, spin + PI * 1.4, 16, Color(1, 1, 1, 0.95), 10.0, true)
        draw_arc(center, width, spin, spin + PI * 1.4, 16, Color(1.0, 0.7, 0.3), 6.0, true)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_coffee_bean() -> void:
    # NOTE (mristin):
    # The brown bean tumbles, with a cream outline, so that it shows on the dark
    # city.
    draw_set_transform(Vector2.ZERO, _age * 7.0, Vector2(1.0, 0.72))
    draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.92, 0.75, 0.95))
    draw_circle(Vector2.ZERO, 12.0, Color(0.55, 0.32, 0.16))
    draw_arc(Vector2(-14, 0), 14.0, -0.9, 0.9, 10, Color(0.98, 0.85, 0.6), 3.0, true)
    draw_circle(Vector2(-4, -5), 3.0, Color(1, 1, 1, 0.6))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_banknote() -> void:
    # NOTE (mristin):
    # The note flutters upright, whichever way it flies: a bright green paper
    # with a white rim and a friendly smiley in the middle instead of a face of
    # anybody real.
    var flutter := sin(_age * 9.0)
    draw_set_transform(
        Vector2.ZERO, -rotation + flutter * 0.35, Vector2(1.0, 0.75 + 0.25 * flutter)
    )
    draw_rect(Rect2(-21, -12, 42, 24), Color(1, 1, 1, 0.95))
    draw_rect(Rect2(-18, -9, 36, 18), Color(0.45, 0.9, 0.45))
    draw_circle(Vector2.ZERO, 6.5, Color(0.85, 1.0, 0.8))
    draw_arc(Vector2(0, 1), 3.5, 0.3, PI - 0.3, 6, Color(0.15, 0.45, 0.15), 1.5)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * 13, 0), 2.5, Color(0.2, 0.6, 0.2))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_coin() -> void:
    # NOTE (mristin):
    # The golden coin spins upright as it flies.
    var spin := absf(cos(_age * 8.0))
    draw_set_transform(Vector2.ZERO, -rotation, Vector2(0.25 + 0.75 * spin, 1.0))
    draw_circle(Vector2.ZERO, 16.0, Color(1, 1, 1, 0.95))
    draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.8, 0.2))
    draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(0.85, 0.6, 0.1), 2.5, true)
    draw_circle(Vector2(-4, -5), 3.5, Color(1, 1, 0.85))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_note() -> void:
    # NOTE (mristin):
    # A singing musical note, e.g., of a cow bell or a yodel. It stays upright
    # however it flies, and wiggles to the tune, bright on the dim meadows.
    var wiggle := sin(_age * 10.0) * 0.25
    draw_set_transform(Vector2.ZERO, -rotation + wiggle, Vector2(0.9, 0.9))
    draw_circle(Vector2(0, -2), 22.0, Color(1.0, 0.95, 0.5, 0.3))
    var head := PackedVector2Array()
    var rim := PackedVector2Array()
    for i in range(16):
        var at := Vector2(cos(TAU * i / 16.0) * 11.0, sin(TAU * i / 16.0) * 8.0).rotated(-0.4)
        head.append(at + Vector2(-4, 8))
        rim.append(at * 1.3 + Vector2(-4, 8))
    draw_colored_polygon(rim, Color(1, 1, 1, 0.95))
    draw_colored_polygon(head, Color(1.0, 0.82, 0.15))
    draw_line(Vector2(5.5, 7), Vector2(5.5, -19), Color(1, 1, 1, 0.95), 7.0)
    draw_line(Vector2(5.5, 6), Vector2(5.5, -18), Color(1.0, 0.82, 0.15), 3.5)
    draw_colored_polygon(
        PackedVector2Array([Vector2(3, -22), Vector2(18, -11), Vector2(16, -4), Vector2(3, -13)]),
        Color(1, 1, 1, 0.95)
    )
    draw_colored_polygon(
        PackedVector2Array([Vector2(6, -18), Vector2(15, -10), Vector2(14, -7), Vector2(6, -14)]),
        Color(1.0, 0.82, 0.15)
    )
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_snowball() -> void:
    # NOTE (mristin):
    # The snowball rolls as it flies, with a soft blue rim, so that it stands
    # out on the dim ice.
    draw_set_transform(Vector2.ZERO, _age * 5.0, Vector2(0.8, 0.8))
    draw_circle(Vector2.ZERO, 19.0, Color(0.55, 0.85, 1.0, 0.45))
    draw_circle(Vector2.ZERO, 15.0, Color(0.85, 0.95, 1.0))
    draw_circle(Vector2(-3, -3), 10.0, Color(1, 1, 1))
    for i in range(3):
        var at := Vector2.RIGHT.rotated(TAU * i / 3.0) * 9.0
        draw_circle(at, 2.2, Color(0.65, 0.82, 0.95))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_icicle() -> void:
    # NOTE (mristin):
    # The icicle points along the positive x-axis: a bright, pale blue shard
    # with a white outline.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.85, 0.85))
    var outline := PackedVector2Array(
        [Vector2(28, 0), Vector2(-4, -12), Vector2(-20, -7), Vector2(-20, 7), Vector2(-4, 12)]
    )
    var shard := PackedVector2Array(
        [Vector2(23, 0), Vector2(-4, -8.5), Vector2(-17, -4.5), Vector2(-17, 4.5), Vector2(-4, 8.5)]
    )
    draw_colored_polygon(outline, Color(1, 1, 1, 0.95))
    draw_colored_polygon(shard, Color(0.45, 0.85, 1.0))
    draw_line(Vector2(-12, -2), Vector2(16, 0), Color(0.9, 1.0, 1.0), 2.5)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_snowflake() -> void:
    # NOTE (mristin):
    # The snowflake spins however it flies: six bright arms with little
    # branches, around a soft glow.
    draw_set_transform(Vector2.ZERO, _age * 7.0, Vector2(0.9, 0.9))
    draw_circle(Vector2.ZERO, 17.0, Color(0.6, 0.9, 1.0, 0.3))
    for i in range(6):
        var arm := Vector2.RIGHT.rotated(TAU * i / 6.0)
        var side := arm.orthogonal()
        draw_line(Vector2.ZERO, arm * 18.0, Color(1, 1, 1), 4.5, true)
        draw_line(arm * 10.0, arm * 10.0 + (arm + side) * 5.0, Color(0.75, 0.95, 1.0), 3.0, true)
        draw_line(arm * 10.0, arm * 10.0 + (arm - side) * 5.0, Color(0.75, 0.95, 1.0), 3.0, true)
    draw_circle(Vector2.ZERO, 5.0, Color(0.7, 0.92, 1.0))
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_pine_cone() -> void:
    # NOTE (mristin):
    # A pine cone, e.g., a weight of the cuckoo clock, pointing along
    # the positive x-axis, with a bright outline for the dim forests.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.9, 0.9))
    var cone := PackedVector2Array()
    var outline := PackedVector2Array()
    for i in range(16):
        var angle := TAU * i / 16.0
        var stretch := Vector2(cos(angle) * (19.0 if cos(angle) > 0.0 else 13.0), sin(angle) * 11.0)
        cone.append(stretch)
        outline.append(stretch * 1.0 + stretch.normalized() * 3.5)
    draw_colored_polygon(outline, Color(1.0, 0.92, 0.7, 0.95))
    draw_colored_polygon(cone, Color(0.62, 0.38, 0.18))
    for row in range(3):
        var x := -6.0 + row * 8.0
        var h := 8.0 - row * 1.5
        draw_line(Vector2(x - 4, -h), Vector2(x + 2, 0), Color(0.4, 0.22, 0.1), 2.0)
        draw_line(Vector2(x - 4, h), Vector2(x + 2, 0), Color(0.4, 0.22, 0.1), 2.0)
    draw_line(Vector2(-13, 0), Vector2(-20, 0), Color(0.4, 0.22, 0.1), 3.0)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_sandbag() -> void:
    # NOTE (mristin):
    # A little sack of sand, tied at the top, which stays upright and swings
    # as it falls, outlined in white so that it shows on the dusky sky.
    draw_set_transform(Vector2.ZERO, -rotation + sin(_age * 7.0) * 0.25, Vector2(0.8, 0.8))
    var sack := PackedVector2Array()
    for i in range(20):
        var angle := TAU * i / 20.0
        sack.append(Vector2(cos(angle) * 14.0, sin(angle) * 12.0 + 4.0))
    draw_circle(Vector2(0, 4), 17.0, Color(1, 1, 1, 0.95))
    draw_colored_polygon(sack, Color(0.85, 0.65, 0.4))
    draw_colored_polygon(
        PackedVector2Array([Vector2(-6, -7), Vector2(6, -7), Vector2(9, -15), Vector2(-9, -15)]),
        Color(0.85, 0.65, 0.4)
    )
    draw_line(Vector2(-7, -8), Vector2(7, -8), Color(0.75, 0.2, 0.3), 3.5)
    draw_line(Vector2(-5, 2), Vector2(5, 2), Color(0.6, 0.42, 0.25), 2.0)
    draw_line(Vector2(-3, 8), Vector2(6, 8), Color(0.6, 0.42, 0.25), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_raindrop() -> void:
    # NOTE (mristin):
    # A big, round raindrop pointing back along its flight, light blue with
    # a white outline and a shine, so that it shows on the dusky sky.
    var wobble := 1.0 + 0.06 * sin(_age * 16.0)
    var drop := PackedVector2Array()
    var outline := PackedVector2Array()
    for i in range(17):
        var angle := -PI * 0.5 + PI * i / 16.0
        drop.append(Vector2(cos(angle) * 9.0 * wobble + 3.0, sin(angle) * 9.0 * wobble))
        outline.append(Vector2(cos(angle) * 12.0 * wobble + 3.0, sin(angle) * 12.0 * wobble))
    drop.append(Vector2(-14, 0))
    outline.append(Vector2(-19, 0))
    draw_colored_polygon(outline, Color(1, 1, 1, 0.95))
    draw_colored_polygon(drop, Color(0.45, 0.75, 1.0))
    draw_circle(Vector2(5, -3), 2.8, Color(1, 1, 1, 0.9))


func _draw_paper_dart() -> void:
    # NOTE (mristin):
    # A little paper airplane seen from above, pointing along the positive
    # x-axis, white with a bright pink outline.
    var outline := PackedVector2Array(
        [Vector2(20, 0), Vector2(-15, -15), Vector2(-9, 0), Vector2(-15, 15)]
    )
    var wings := PackedVector2Array(
        [Vector2(16, 0), Vector2(-12, -11), Vector2(-7, 0), Vector2(-12, 11)]
    )
    draw_colored_polygon(outline, Color(1.0, 0.45, 0.7))
    draw_colored_polygon(wings, Color(1.0, 0.98, 0.92))
    draw_line(Vector2(-7, 0), Vector2(16, 0), Color(0.75, 0.7, 0.8), 2.0)


func _draw_rocket() -> void:
    # NOTE (mristin):
    # The rocket points along the positive x-axis; we rotate the whole node.
    #
    # We draw it large, so that it is easy to see on a small screen from
    # a distance.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.6, 1.6))
    var flame := 10.0 + 6.0 * sin(_age * 50.0)
    draw_colored_polygon(
        PackedVector2Array([Vector2(-10, -4), Vector2(-10 - flame, 0), Vector2(-10, 4)]),
        Color(1.0, 0.6, 0.1, 0.9)
    )
    draw_rect(Rect2(-12, -4, 18, 8), Color(0.85, 0.85, 0.9))
    draw_colored_polygon(
        PackedVector2Array([Vector2(6, -4), Vector2(14, 0), Vector2(6, 4)]), Color(1.0, 0.25, 0.2)
    )
