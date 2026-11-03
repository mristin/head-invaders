class_name Slime

extends Enemy

## A blob of space slime: it comes down to its place, then hops from side to
## side and fires the rockets at the nearest spaceship. When defeated, a big
## slime splits into two little ones, which hop on until defeated as well.

const _SCENE_PATH: String = "res://scenes/enemies/slime/slime.tscn"

## Whether the slime splits into two little ones when defeated.
@export var splits: bool = true

## How big the little slimes are compared to the big one.
@export var little_scale: float = 0.6

@export var descent_speed: float = 200.0

@export var hop_distance: float = 220.0
@export var hop_height: float = 90.0
@export var hop_duration: float = 0.8
@export var rest_duration: float = 0.6

@export var margin: float = 110.0

## Which way the slime hops first: -1 for left, 1 for right, 0 for random.
var first_direction: float = 0.0

var _time: float = 0.0
var _descending: bool = true
var _direction: float = 1.0
var _hop_from_x: float = 0.0
var _hop_elapsed: float = 0.0
var _rest_left: float = 0.0


func _ready() -> void:
    super()
    _direction = first_direction
    if _direction == 0.0:
        _direction = -1.0 if randf() < 0.5 else 1.0


func _enter() -> void:
    super()
    _descending = not spawned_in_place
    _start_hop()


func _start_hop() -> void:
    var bounds := get_viewport_rect()
    if position.x + _direction * hop_distance > bounds.end.x - margin:
        _direction = -1.0
    elif position.x + _direction * hop_distance < bounds.position.x + margin:
        _direction = 1.0
    _hop_from_x = position.x
    _hop_elapsed = 0.0


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _rest_left = rest_duration
        return

    if _rest_left > 0.0:
        _rest_left -= delta
        if _rest_left <= 0.0:
            _start_hop()
        return

    _hop_elapsed += delta
    var t := clampf(_hop_elapsed / hop_duration, 0.0, 1.0)
    position.x = _hop_from_x + _direction * hop_distance * smoothstep(0.0, 1.0, t)
    position.y = home.y - sin(PI * t) * hop_height
    if t >= 1.0:
        _rest_left = rest_duration


func _start_fleeing(may_drop: bool = true) -> void:
    super(may_drop)

    if not splits or not may_drop:
        return

    # NOTE (mristin):
    # The two little slimes do not follow the big one home; they fight on.
    var scene: PackedScene = load(_SCENE_PATH)
    for side: float in [-1.0, 1.0]:
        var little := _summon(scene, global_position, false) as Slime
        little.splits = false
        little.scale = Vector2.ONE * little_scale
        little.max_energy = maxi(1, max_energy / 3)
        little.drop_chance = drop_chance * 0.5
        little.first_direction = side
        little.hop_distance = hop_distance * 0.7
        little.hop_height = hop_height * 0.7


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The slime squashes when it lands and stretches when it jumps.
    var stretch := 1.0
    if not _descending:
        if _rest_left > 0.0:
            stretch = 1.0 - 0.15 * (_rest_left / rest_duration)
        else:
            stretch = 1.0 + 0.12 * sin(PI * clampf(_hop_elapsed / hop_duration, 0.0, 1.0))
    var squash := 1.0 / stretch

    var blob := PackedVector2Array()
    for i in range(32):
        var angle := TAU * i / 32.0
        var wobble := 1.0 + 0.04 * sin(_time * 6.0 + angle * 3.0)
        var y := sin(angle) * r * 0.7 * stretch * wobble
        # NOTE (mristin):
        # The bottom of the blob is flatter.
        if y > 0.0:
            y *= 0.6
        blob.append(Vector2(cos(angle) * r * 0.85 * squash * wobble, y))
    draw_colored_polygon(blob, Color(0.35, 0.75, 1.0, 0.95).lerp(white, flash))
    draw_circle(Vector2(-r * 0.35, -r * 0.35 * stretch), r * 0.12, Color(1, 1, 1, 0.5))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.28, -r * 0.1 * stretch)
        draw_circle(eye, r * 0.16, white)
        draw_circle(eye + Vector2(_direction * r * 0.04, 0), r * 0.08, Color(0.05, 0.15, 0.3))
    draw_arc(Vector2(0, r * 0.12), r * 0.12, 0.2, PI - 0.2, 10, Color(0.05, 0.15, 0.3), r * 0.05)
