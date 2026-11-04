class_name Banker

extends Enemy

## A rich pig, the silly tycoon of a board game: round and pink, with a plain
## black top hat, a monocle, a curly moustache, a pinstripe suit with a bow tie
## and a pocket watch. He flies a little propeller plane over Zurich and
## throws his money around, very pleased with himself. He comes
## at the end of the city level once all the others have fled. When he gets
## dizzy, his hat flies off.
##
## Unlike the other bosses, he does not stay on the screen. He flies over it
## from one side to the other and out again, letting the banknotes rain down
## behind him, which flutter down in a zigzag. After every second fly-over, he
## comes back, circles at the top and tosses the coins in high arcs, which
## bounce once off the bottom of the screen. Then he lines up for a dive:
## a dashed line and a ring show where he will dive, so the players have time
## to get out of the way, and down he goes and up again.
##
## When he is low on energy, he flies faster and attacks more often.

enum Phase { FLYING_OVER, CIRCLING, AIMING, DIVING, CLIMBING }

## The two lanes of the fly-overs, as the heights on the screen.
@export var high_lane: float = 260.0
@export var low_lane: float = 360.0

@export var fly_speed: float = 380.0

## How far beyond the screen edge he turns around.
@export var off_screen: float = 360.0

## The money rain: the seconds between the banknotes, how fast they fall,
## and how far and how fast they zigzag.
@export var note_interval: float = 1.2
@export var note_fall_speed: float = 170.0
@export var zigzag_width: float = 150.0
@export var zigzag_frequency: float = 3.0

## The circling at the top: how long, how big, and how fast.
@export var circle_duration: float = 5.0
@export var circle_radius: float = 110.0
@export var circle_speed: float = 1.6

## The coins: how many per toss, the seconds between the tosses, how fast they
## spread, how high they are tossed, how strongly they fall, and how much of
## their speed they keep when bouncing.
@export var coin_count: int = 2
@export var coin_interval: float = 1.6
@export var coin_spread: float = 190.0
@export var coin_toss_speed: float = 320.0
@export var coin_fall_acceleration: float = 650.0
@export_range(0.0, 1.0) var coin_bounce: float = 0.6

## The dive: how long he lines up, how fast he dives and climbs, and how deep
## he dives, as a fraction of the screen height.
@export var aim_duration: float = 1.5
@export var dive_speed: float = 950.0
@export var climb_speed: float = 520.0
@export_range(0.0, 1.0) var dive_depth: float = 0.84

## He keeps the dives this far from the screen edges.
@export var margin: float = 200.0

## How many times bigger the money is than the other projectiles, so that
## the children see it well.
@export var money_size: float = 1.8

## Below this fraction of the energy, he flies and attacks this many times as
## fast.
@export_range(0.0, 1.0) var hurry_below: float = 0.34
@export var hurry_factor: float = 1.3

var _phase: Phase = Phase.FLYING_OVER
var _time: float = 0.0
var _phase_left: float = 0.0
var _direction: float = 1.0
var _low: bool = false
var _angle: float = 0.0
var _circle_angle: float = 0.0
var _dive_x: float = 0.0

var _flyovers: int = 0
var _dives: int = 0
var _coin_bounces: int = 0
var _note_cooldown: float = 0.0
var _coin_cooldown: float = 0.0

var _notes: Array[Rocket] = []
var _note_ages: Array[float] = []
var _coins: Array[Rocket] = []

@onready var _body_shape: CollisionShape2D = $Body


## Return how many times he has flown over the screen so far.
func flyovers() -> int:
    return _flyovers


func dives() -> int:
    return _dives


## Return how many of his coins have bounced off the bottom so far.
func coin_bounces() -> int:
    return _coin_bounces


func is_aiming() -> bool:
    return _phase == Phase.AIMING


## Return where he is going to dive, or has dived last.
func dive_x() -> float:
    return _dive_x


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _may_fire() -> bool:
    # NOTE (mristin):
    # He attacks in his own rhythm; see _move.
    return false


func _enter() -> void:
    var bounds := get_viewport_rect()
    _direction = 1.0
    position = Vector2(bounds.position.x - off_screen * 0.5, high_lane)
    _phase = Phase.FLYING_OVER


func _move(delta: float) -> void:
    _time += delta
    var bounds := get_viewport_rect()
    var hurry := hurry_factor if is_in_a_hurry() else 1.0
    var on_screen := bounds.has_point(global_position)

    match _phase:
        Phase.FLYING_OVER:
            _angle = 0.0
            position.x += _direction * fly_speed * hurry * delta
            position.y = move_toward(position.y, low_lane if _low else high_lane, 150.0 * delta)
            if on_screen:
                _note_cooldown -= delta * hurry
                if _note_cooldown <= 0.0:
                    _note_cooldown = note_interval
                    _drop_banknote()
            var beyond := (
                position.x > bounds.end.x + off_screen
                if _direction > 0.0
                else position.x < bounds.position.x - off_screen
            )
            if beyond:
                _flyovers += 1
                _direction = -_direction
                _low = not _low
                if _flyovers % 2 == 0:
                    _phase = Phase.CIRCLING
                    _phase_left = circle_duration
                    _coin_cooldown = coin_interval * 0.6
        Phase.CIRCLING:
            _phase_left -= delta
            _circle_angle += circle_speed * delta
            var center := Vector2(bounds.get_center().x, high_lane + circle_radius * 0.3)
            var target := (
                center + Vector2(cos(_circle_angle), sin(_circle_angle) * 0.4) * circle_radius
            )
            var step := position.move_toward(target, fly_speed * 1.3 * hurry * delta) - position
            position += step
            if absf(step.x) > 0.5:
                _direction = signf(step.x)
            _angle = clampf(step.y / maxf(delta, 0.001) / 1500.0, -0.3, 0.3)
            if on_screen:
                _coin_cooldown -= delta * hurry
                if _coin_cooldown <= 0.0:
                    _coin_cooldown = coin_interval
                    _toss_coins()
            if _phase_left <= 0.0 and on_screen:
                _start_aiming()
        Phase.AIMING:
            _phase_left -= delta
            _angle = sin(_time * 18.0) * 0.06
            position.x = move_toward(position.x, _dive_x, 700.0 * delta)
            position.y = move_toward(position.y, high_lane, 300.0 * delta)
            if _phase_left <= 0.0:
                _phase = Phase.DIVING
                _dives += 1
        Phase.DIVING:
            _angle = PI / 2.0
            position.x = _dive_x
            position.y += dive_speed * hurry * delta
            if position.y >= bounds.size.y * dive_depth:
                _phase = Phase.CLIMBING
        Phase.CLIMBING:
            _angle = -PI / 2.0
            position.y -= climb_speed * hurry * delta
            if position.y <= high_lane:
                position.y = high_lane
                _phase = Phase.FLYING_OVER
                _low = false
                _direction = 1.0 if position.x > bounds.get_center().x else -1.0

    _body_shape.rotation = PI / 2.0 + _angle * _direction
    _update_money(delta)


func _start_aiming() -> void:
    var bounds := get_viewport_rect()
    _phase = Phase.AIMING
    _phase_left = aim_duration
    var target := _nearest_spaceship()
    _dive_x = target.global_position.x if target != null else bounds.get_center().x
    _dive_x = clampf(_dive_x, bounds.position.x + margin, bounds.end.x - margin)


func _drop_banknote() -> void:
    var from := global_position + Vector2(-_direction * radius * 0.3, radius * 0.25)
    var note := _launch_rocket_from(from, Vector2.DOWN, note_fall_speed)
    if note == null:
        return
    note.look = Rocket.Look.BANKNOTE
    note.size_factor = money_size
    _notes.append(note)
    _note_ages.append(randf() * TAU / zigzag_frequency)


func _toss_coins() -> void:
    var target := _nearest_spaceship()
    var aim_x := 0.0
    if target != null:
        aim_x = clampf((target.global_position.x - global_position.x) * 0.45, -260.0, 260.0)
    for i in range(coin_count):
        var spread := (i - (coin_count - 1) / 2.0) * coin_spread
        var coin := _launch_rocket_from(global_position, Vector2.UP, coin_toss_speed)
        if coin == null:
            return
        coin.look = Rocket.Look.COIN
        coin.size_factor = money_size
        coin.velocity = Vector2(aim_x + spread, -coin_toss_speed)
        coin.fall_acceleration = coin_fall_acceleration
        _coins.append(coin)


func _update_money(delta: float) -> void:
    for i in range(_notes.size() - 1, -1, -1):
        var note := _notes[i]
        if not is_instance_valid(note):
            _notes.remove_at(i)
            _note_ages.remove_at(i)
            continue
        _note_ages[i] += delta
        # NOTE (mristin):
        # The notes flutter down in a zigzag, like paper does.
        note.velocity.x = (
            cos(_note_ages[i] * zigzag_frequency) * zigzag_width * zigzag_frequency * 0.5
        )

    var bottom := get_viewport_rect().end.y - 40.0
    for i in range(_coins.size() - 1, -1, -1):
        var coin := _coins[i]
        if not is_instance_valid(coin):
            _coins.remove_at(i)
            continue
        if coin.global_position.y > bottom and coin.velocity.y > 0.0:
            # NOTE (mristin):
            # The coin bounces once, "cling!", and then falls off the screen.
            coin.velocity.y = -coin.velocity.y * coin_bounce
            _coin_bounces += 1
            Poof.spawn(coin, coin.global_position, 20.0, Color(1.0, 0.9, 0.4))
            _coins.remove_at(i)


func _start_fleeing(may_drop: bool = true) -> void:
    _angle = 0.0
    super(may_drop)


func _draw_body(flash: float) -> void:
    var r := radius

    if _phase == Phase.AIMING:
        # NOTE (mristin):
        # The dashed line and the ring show where he is going to dive.
        var pulse := 0.6 + 0.4 * sin(_time * 12.0)
        var x := _dive_x - global_position.x
        var bottom := get_viewport_rect().size.y * dive_depth - global_position.y
        var y := r * 0.5
        while y < bottom:
            draw_line(
                Vector2(x, y),
                Vector2(x, minf(y + 30.0, bottom)),
                Color(1.0, 0.9, 0.3, 0.7 * pulse),
                6.0
            )
            y += 55.0
        draw_arc(Vector2(x, bottom), r * 0.45, 0.0, TAU, 32, Color(1.0, 0.9, 0.3, pulse), 7.0, true)
        draw_arc(Vector2(x, bottom), r * 0.25, 0.0, TAU, 24, Color(1, 1, 1, pulse), 4.0, true)

    var wobble := sin(_flee_time * 14.0) * 0.3 if is_fleeing() else 0.0
    draw_set_transform(Vector2.ZERO, _angle * _direction + wobble, Vector2(_direction, 1.0))
    _draw_puffs()
    _draw_plane(flash)
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_puffs() -> void:
    # NOTE (mristin):
    # The little plane puffs small, soft clouds behind it.
    var r := radius
    for k in range(3):
        var puff := fmod(_time * 2.0 + k / 3.0, 1.0)
        draw_circle(
            Vector2(-r * (0.95 + puff * 0.6), sin(k * 2.3) * r * 0.06),
            r * (0.05 + puff * 0.08),
            Color(0.9, 0.93, 1.0, 0.55 * (1.0 - puff))
        )


func _draw_plane(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var yellow := Color(1.0, 0.8, 0.25).lerp(white, flash)
    var red := Color(0.95, 0.35, 0.3).lerp(white, flash)

    # The far wing and the tail.
    draw_rect(
        Rect2(Vector2(-r * 0.2, -r * 0.2), Vector2(r * 0.45, r * 0.08)), yellow.darkened(0.25)
    )
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.55, -r * 0.08),
                Vector2(-r * 0.85, -r * 0.45),
                Vector2(-r * 0.72, -r * 0.05)
            ]
        ),
        red
    )
    draw_colored_polygon(
        PackedVector2Array(
            [Vector2(-r * 0.6, r * 0.02), Vector2(-r * 0.92, r * 0.0), Vector2(-r * 0.6, -r * 0.08)]
        ),
        red.darkened(0.15)
    )

    _draw_pig(flash)

    # The fuselage with the cockpit rim, the near wing and the wheels.
    draw_circle(Vector2(-r * 0.25, r * 0.32), r * 0.07, Color(0.2, 0.2, 0.25))
    draw_circle(Vector2(r * 0.3, r * 0.32), r * 0.07, Color(0.2, 0.2, 0.25))
    draw_line(
        Vector2(-r * 0.2, r * 0.12), Vector2(-r * 0.25, r * 0.3), Color(0.4, 0.4, 0.45), r * 0.03
    )
    draw_line(
        Vector2(r * 0.25, r * 0.12), Vector2(r * 0.3, r * 0.3), Color(0.4, 0.4, 0.45), r * 0.03
    )
    var hull := PackedVector2Array()
    for k in range(24):
        var a := TAU * k / 24.0
        hull.append(
            Vector2(cos(a) * r * 0.75, sin(a) * r * 0.2 + (r * 0.03 if sin(a) > 0.0 else 0.0))
        )
    var rim := PackedVector2Array()
    for p in hull:
        rim.append(p * 1.06)
    draw_colored_polygon(rim, white)
    draw_colored_polygon(hull, yellow)
    draw_line(Vector2(-r * 0.6, r * 0.02), Vector2(r * 0.6, r * 0.02), red, r * 0.05)
    draw_rect(Rect2(Vector2(-r * 0.15, r * 0.04), Vector2(r * 0.5, r * 0.1)), yellow.darkened(0.12))
    draw_rect(
        Rect2(Vector2(-r * 0.15, r * 0.04), Vector2(r * 0.5, r * 0.1)), white, false, r * 0.015
    )
    draw_circle(Vector2(r * 0.76, 0), r * 0.1, red)
    var blade := absf(cos(_time * 40.0)) * r * 0.32 + r * 0.05
    draw_line(
        Vector2(r * 0.84, -blade), Vector2(r * 0.84, blade), Color(0.9, 0.9, 0.95, 0.85), r * 0.04
    )
    draw_circle(Vector2(r * 0.86, 0), r * 0.035, Color(0.3, 0.3, 0.35))


## Draw the banker: a round, smug pig in a pinstripe suit, with a bow tie,
## a pocket watch, a monocle, a curly moustache and a plain black top hat.
func _draw_pig(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var pink := Color(1.0, 0.68, 0.75).lerp(white, flash)
    var dark_pink := Color(0.9, 0.48, 0.58).lerp(white, flash)
    var gold := Color(1.0, 0.82, 0.3).lerp(white, flash)
    var head := Vector2(r * 0.08, -r * 0.44)

    # The pinstripe suit with the white shirt and the red bow tie.
    var suit := Rect2(Vector2(-r * 0.16, -r * 0.32), Vector2(r * 0.46, r * 0.24))
    draw_rect(suit, Color(0.2, 0.22, 0.32).lerp(white, flash))
    for k in range(1, 8):
        var x := suit.position.x + k * suit.size.x / 8.0
        draw_line(
            Vector2(x, suit.position.y), Vector2(x, suit.end.y), Color(0.5, 0.52, 0.62), r * 0.008
        )
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(r * 0.0, -r * 0.32),
                Vector2(r * 0.16, -r * 0.32),
                Vector2(r * 0.08, -r * 0.16)
            ]
        ),
        Color(0.98, 0.98, 1.0)
    )
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(r * 0.08, -r * 0.29),
                    Vector2(r * 0.08 + side * r * 0.08, -r * 0.33),
                    Vector2(r * 0.08 + side * r * 0.08, -r * 0.25),
                ]
            ),
            Color(0.95, 0.25, 0.3).lerp(white, flash)
        )
    draw_circle(Vector2(r * 0.08, -r * 0.29), r * 0.025, Color(0.8, 0.15, 0.2))

    # The gold chain of the pocket watch, and the watch peeking out.
    var chain := PackedVector2Array()
    for k in range(9):
        var t := k / 8.0
        chain.append(Vector2(lerpf(r * 0.1, r * 0.26, t), -r * 0.2 + sin(t * PI) * r * 0.05))
    draw_polyline(chain, gold, r * 0.015, true)
    draw_circle(Vector2(r * 0.27, -r * 0.2), r * 0.04, gold)
    draw_circle(Vector2(r * 0.27, -r * 0.2), r * 0.025, Color(1.0, 0.97, 0.88))

    # He waves his trotter, very pleased with himself.
    var shoulder := Vector2(r * 0.25, -r * 0.28)
    var wave := sin(_time * 6.0) * 0.5
    var hoof := shoulder + Vector2.from_angle(-1.2 + wave) * r * 0.3
    draw_line(shoulder, hoof, Color(0.2, 0.22, 0.32).lerp(white, flash), r * 0.08)
    draw_circle(hoof, r * 0.055, pink)
    draw_line(hoof, hoof + Vector2.from_angle(-1.2 + wave) * r * 0.05, dark_pink, r * 0.015)

    # The round pig head with the floppy ears.
    for side: float in [-1.0, 1.0]:
        var ear := head + Vector2(side * r * 0.14, -r * 0.1)
        draw_colored_polygon(
            PackedVector2Array(
                [
                    ear + Vector2(-r * 0.06, r * 0.02),
                    ear + Vector2(side * r * 0.1, -r * 0.08),
                    ear + Vector2(r * 0.06, r * 0.04),
                ]
            ),
            dark_pink
        )
    draw_circle(head, r * 0.2, pink)
    for side: float in [-1.0, 1.0]:
        draw_circle(head + Vector2(side * r * 0.13, r * 0.06), r * 0.035, Color(1.0, 0.5, 0.55))

    # The smug, half-closed eyes, and the monocle on its gold chain.
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.07 + r * 0.02, -r * 0.05)
        draw_circle(eye, r * 0.042, white)
        draw_circle(eye + Vector2(r * 0.01, r * 0.008), r * 0.022, Color(0.1, 0.08, 0.1))
        draw_rect(Rect2(eye - Vector2(r * 0.045, r * 0.05), Vector2(r * 0.09, r * 0.045)), pink)
        draw_line(
            eye + Vector2(-r * 0.045, -r * 0.005),
            eye + Vector2(r * 0.045, -r * 0.005),
            dark_pink,
            r * 0.012
        )
    var monocle := head + Vector2(r * 0.09, -r * 0.05)
    draw_arc(monocle, r * 0.06, 0.0, TAU, 16, gold, r * 0.016, true)
    draw_line(monocle + Vector2(r * 0.03, r * 0.05), Vector2(r * 0.16, -r * 0.3), gold, r * 0.008)

    # The round pig snout with its two nostrils.
    var snout := head + Vector2(r * 0.04, r * 0.05)
    draw_circle(snout, r * 0.075, dark_pink)
    draw_circle(snout, r * 0.06, Color(1.0, 0.75, 0.82).lerp(white, flash))
    for side: float in [-1.0, 1.0]:
        draw_circle(snout + Vector2(side * r * 0.025, 0), r * 0.014, Color(0.55, 0.25, 0.35))

    # The curly moustache under the snout, and the smirk.
    var brown := Color(0.35, 0.22, 0.12).lerp(white, flash)
    for side: float in [-1.0, 1.0]:
        var middle := snout + Vector2(side * r * 0.05, r * 0.07)
        draw_line(snout + Vector2(0, r * 0.07), middle, brown, r * 0.03)
        draw_arc(
            middle + Vector2(side * r * 0.02, -r * 0.02),
            r * 0.025,
            0.0,
            TAU * 0.75,
            10,
            brown,
            r * 0.018,
            true
        )
    draw_arc(
        snout + Vector2(r * 0.03, r * 0.11),
        r * 0.04,
        0.2,
        PI * 0.7,
        6,
        Color(0.5, 0.15, 0.2),
        r * 0.018
    )

    # The plain black top hat; it flies off when he gets dizzy.
    var hat_center := head + Vector2(0, -r * 0.3)
    var hat_turn := 0.0
    if is_fleeing():
        hat_center += Vector2(r * 0.8 * _flee_time, -r * 2.5 * _flee_time)
        hat_turn = _flee_time * 6.0
    var black := Color(0.12, 0.12, 0.15).lerp(white, flash)
    draw_colored_polygon(
        _turned_rect(
            hat_center + Vector2(0, r * 0.13), Vector2(r * 0.44, r * 0.05), hat_center, hat_turn
        ),
        black
    )
    draw_colored_polygon(
        _turned_rect(hat_center, Vector2(r * 0.27, r * 0.27), hat_center, hat_turn), black
    )
    draw_colored_polygon(
        _turned_rect(
            hat_center + Vector2(0, r * 0.08), Vector2(r * 0.27, r * 0.05), hat_center, hat_turn
        ),
        Color(0.55, 0.55, 0.6).lerp(white, flash)
    )


## Return a rectangle of the given size around the center, turned around
## the pivot by the angle.
static func _turned_rect(
    center: Vector2, size: Vector2, pivot: Vector2, angle: float
) -> PackedVector2Array:
    var result := PackedVector2Array()
    for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
        var point := center + corner * size / 2.0
        result.append(pivot + (point - pivot).rotated(angle))
    return result
