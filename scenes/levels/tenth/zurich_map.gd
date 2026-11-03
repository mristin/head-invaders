class_name ZurichMap

extends Node2D

## Draw the city of Zurich seen from above, sliding down below the spaceships as
## they fly north: first Lake Zurich with its boats and swans, then
## the Limmat flowing out of the lake through the old town with its bridges,
## the Grossmünster, the Fraumünster and St. Peter, then the main station with
## its tracks fanning out, where the Sihl joins, the ETH on the hill, and
## the Prime Tower in the west. The Uetliberg with its tower watches from
## the west at the start. North of the map, the city goes on with its quarters
## along the Limmat for as long as the level lasts.
##
## We draw the map in chunks, which we draw once and slide down, and free once
## they have passed, so that only a few chunks live at a time. The landmarks
## lie on a layer above the ground, so that the tall ones may reach over
## the next chunk.
##
## NOTE (mristin):
## We keep the map dim and calm, so that nobody mistakes anything in it for
## a projectile. The trams, the boats and the swans are dim and slow.
##
## The map uses its own coordinates: x goes from the west to the east across
## the screen, and d is the distance to the north from the start of the level.


class Chunk:
    extends Node2D

    var map: ZurichMap
    var index: int = 0
    var top: bool = false

    func _draw() -> void:
        map.draw_chunk(self, index, top)


## A tram, a boat or a swan, which goes back and forth along its route.
class Mover:
    extends Node2D

    var map: ZurichMap
    var kind: String = "tram"
    var route: PackedVector2Array = PackedVector2Array()
    var speed: float = 30.0
    var heading: Vector2 = Vector2.RIGHT

    var _along: float = 0.0
    var _direction: float = 1.0
    var _length: float = 0.0
    var _time: float = 0.0

    func setup(start_fraction: float) -> void:
        _length = 0.0
        for i in range(1, route.size()):
            _length += route[i - 1].distance_to(route[i])
        _along = _length * start_fraction
        _place()

    func _physics_process(delta: float) -> void:
        _time += delta
        _along += _direction * speed * delta
        if _along > _length:
            _along = _length
            _direction = -1.0
        elif _along < 0.0:
            _along = 0.0
            _direction = 1.0
        _place()
        if kind != "tram":
            queue_redraw()

    func _place() -> void:
        var walked := 0.0
        for i in range(1, route.size()):
            var a := route[i - 1]
            var b := route[i]
            var length := a.distance_to(b)
            if walked + length >= _along or i == route.size() - 1:
                var t := clampf((_along - walked) / maxf(length, 0.001), 0.0, 1.0)
                position = a.lerp(b, t)
                var forward := (b - a).normalized() * _direction
                if forward != Vector2.ZERO and forward != heading:
                    heading = forward
                    queue_redraw()
                return
            walked += length

    func _draw() -> void:
        ZurichLandmarks.draw_mover(self, kind, heading, _time)


## The map joins this group, so that the enemies find it, e.g., the swimmers
## who float down the Limmat.
const GROUP: String = "zurich_map"

const SCREEN_WIDTH: float = 1920.0
const SCREEN_HEIGHT: float = 1080.0

## The height of a chunk of the map, in pixels.
const CHUNK_HEIGHT: float = 540.0

## Where the Limmat leaves the lake, as the distance to the north.
const LAKE_END: float = 1625.0

## Where the hand-drawn part of the map ends; the quarters go on beyond.
const MAP_END: float = 5200.0

const ASPHALT: Color = Color(0.105, 0.11, 0.125)
const SHADOW: Color = Color(0.055, 0.058, 0.068)
const TOWER_SHADOW: Color = Color(0.0, 0.0, 0.02, 0.32)
const WATER: Color = Color(0.06, 0.125, 0.205)
const WATER_LIGHT: Color = Color(0.08, 0.15, 0.235)
const QUAY: Color = Color(0.165, 0.165, 0.17)
const PARK: Color = Color(0.08, 0.155, 0.09)
const TREE: Color = Color(0.07, 0.19, 0.09)
const TREE_LIGHT: Color = Color(0.1, 0.23, 0.11)
const FOREST: Color = Color(0.06, 0.125, 0.07)
const BALLAST: Color = Color(0.135, 0.125, 0.115)
const RAIL: Color = Color(0.22, 0.22, 0.235)
const PAVED: Color = Color(0.17, 0.162, 0.15)
const SANDSTONE: Color = Color(0.37, 0.34, 0.29)
const SANDSTONE_DARK: Color = Color(0.27, 0.25, 0.215)
const COPPER: Color = Color(0.2, 0.38, 0.32)
const COPPER_DARK: Color = Color(0.13, 0.27, 0.23)
const SLATE: Color = Color(0.17, 0.17, 0.19)
const GLASS: Color = Color(0.19, 0.26, 0.29)
const GLASS_LIGHT: Color = Color(0.26, 0.34, 0.37)
const TRAM_BLUE: Color = Color(0.17, 0.26, 0.42)
const TRAM_WHITE: Color = Color(0.36, 0.37, 0.4)

## How fast the map slides down, in pixels per second. The ground enemies of
## the level slide at the same speed.
@export var scroll_speed: float = 40.0

## Start the flight this far to the north, e.g., over the old town in a test.
@export var start_distance: float = 0.0

## How far the map has slid so far, i.e., the distance to the north of
## the bottom of the screen.
var distance: float = 0.0

var _ground_layer: Node2D
var _top_layer: Node2D
var _chunks: Dictionary[int, Array] = {}

# NOTE (mristin):
# The geography is given as the points (d, x), sorted by d.
var _lake_west: PackedVector2Array = PackedVector2Array(
    [
        Vector2(-400, 640),
        Vector2(200, 650),
        Vector2(600, 690),
        Vector2(1000, 740),
        Vector2(1300, 790),
        Vector2(1480, 840),
        Vector2(1580, 890),
        Vector2(LAKE_END, 906),
    ]
)
var _lake_east: PackedVector2Array = PackedVector2Array(
    [
        Vector2(-400, 1730),
        Vector2(200, 1700),
        Vector2(330, 1610),
        Vector2(400, 1530),
        Vector2(470, 1590),
        Vector2(620, 1640),
        Vector2(900, 1585),
        Vector2(1150, 1520),
        Vector2(1330, 1420),
        Vector2(1470, 1300),
        Vector2(1540, 1150),
        Vector2(1595, 1040),
        Vector2(LAKE_END, 1014),
    ]
)
var _limmat: PackedVector2Array = PackedVector2Array(
    [
        Vector2(1560, 960),
        Vector2(1800, 968),
        Vector2(2050, 978),
        Vector2(2350, 965),
        Vector2(2650, 945),
        Vector2(2900, 935),
        Vector2(3150, 920),
        Vector2(3350, 860),
        Vector2(3600, 760),
        Vector2(3900, 660),
        Vector2(4300, 600),
        Vector2(4800, 650),
        Vector2(MAP_END, 760),
    ]
)
var _sihl: PackedVector2Array = PackedVector2Array(
    [
        Vector2(-400, 280),
        Vector2(400, 300),
        Vector2(1000, 340),
        Vector2(1600, 430),
        Vector2(2200, 560),
        Vector2(2600, 690),
        Vector2(2850, 740),
        Vector2(3050, 760),
        Vector2(3200, 800),
        Vector2(3345, 870),
    ]
)
var _bahnhofstrasse: PackedVector2Array = PackedVector2Array(
    [Vector2(700, 1600), Vector2(672, 2000), Vector2(652, 2400), Vector2(642, 2860)]
)

## The bridges across the Limmat: the distance and the width.
var _bridges: Array[Vector2] = [
    Vector2(1650, 46),
    Vector2(1790, 26),
    Vector2(2065, 26),
    Vector2(2350, 30),
    Vector2(2800, 44),
    Vector2(3480, 32),
    Vector2(3950, 32),
    Vector2(4450, 32),
    Vector2(4950, 32),
]

var _lake: PackedVector2Array
var _lake_clear: PackedVector2Array
var _tracks: Array[PackedVector2Array] = []
var _track_field: PackedVector2Array
var _parks: Array[PackedVector2Array] = []
var _forests: Array[PackedVector2Array] = []
var _squares: Array[Rect2] = []
var _landmarks: Array[Dictionary] = []
var _keep_free: Array[Rect2] = []
var _tram_routes: Array[PackedVector2Array] = []


func _ready() -> void:
    add_to_group(GROUP)
    _build_geography()

    _ground_layer = Node2D.new()
    _ground_layer.name = "Ground"
    add_child(_ground_layer)
    _top_layer = Node2D.new()
    _top_layer.name = "Top"
    add_child(_top_layer)

    distance = start_distance
    position.y = distance
    _add_movers()
    _update_chunks()


func _physics_process(delta: float) -> void:
    distance += scroll_speed * delta
    position.y = distance
    _update_chunks()


## Return the position in the map's local coordinates of the point (x, d).
static func at(x: float, d: float) -> Vector2:
    return Vector2(x, SCREEN_HEIGHT - d)


## Return the distance to the north at the given height on the screen.
func distance_at_screen_y(screen_y: float) -> float:
    return distance + SCREEN_HEIGHT - screen_y


## Return true if the point (x, d) lies in the lake or in a river.
func is_water(x: float, d: float) -> bool:
    if d <= LAKE_END and Geometry2D.is_point_in_polygon(Vector2(x, d), _lake):
        return true
    if d >= LAKE_END - 40.0 and absf(x - limmat_x(d)) < limmat_width(d) / 2.0:
        return true
    return d <= _sihl[-1].x and absf(x - _interpolate(_sihl, d)) < 28.0


func limmat_x(d: float) -> float:
    if d >= MAP_END:
        return 760.0 + sin((d - MAP_END) / 800.0) * 160.0
    return _interpolate(_limmat, d)


func limmat_width(d: float) -> float:
    return 104.0 if d < 3300.0 else 128.0


# region Geography


func _build_geography() -> void:
    _lake = PackedVector2Array()
    for p in _lake_west:
        _lake.append(Vector2(p.y, p.x))
    for i in range(_lake_east.size() - 1, -1, -1):
        _lake.append(Vector2(_lake_east[i].y, _lake_east[i].x))
    _lake_clear = Geometry2D.offset_polygon(_lake, 30.0)[0]

    # NOTE (mristin):
    # The tracks leave the main station to the west and fan out to
    # the north-west, towards the next stations.
    var track_count := 11
    for i in range(track_count):
        var t := i / float(track_count - 1)
        var track := PackedVector2Array()
        var start := Vector2(470, lerpf(2885, 2990, t))
        var bend := Vector2(330, lerpf(2900, 3030, t))
        var finish := Vector2(-120, lerpf(2990, 3560, t))
        for j in range(17):
            var s := j / 16.0
            track.append(start.lerp(bend, s).lerp(bend.lerp(finish, s), s))
        _tracks.append(track)
    _track_field = PackedVector2Array()
    for p in _tracks[0]:
        _track_field.append(p)
    var last := _tracks[-1]
    for i in range(last.size() - 1, -1, -1):
        _track_field.append(last[i])
    _track_field = Geometry2D.offset_polygon(_track_field, 16.0)[0]

    _forests.append(ellipse(Vector2(40, 760), Vector2(250, 560), 28))
    var zuerichberg := PackedVector2Array([Vector2(1990, 2700)])
    for i in range(24):
        var d := lerpf(2750, 5000, i / 23.0)
        zuerichberg.append(Vector2(1700 + sin(d / 140.0) * 50.0 + cos(d / 61.0) * 20.0, d))
    zuerichberg.append(Vector2(1990, 5050))
    _forests.append(zuerichberg)

    _parks.append(ellipse(Vector2(1660, 420), Vector2(110, 120), 20))
    _parks.append(
        PackedVector2Array(
            [Vector2(690, 1220), Vector2(745, 1215), Vector2(830, 1520), Vector2(760, 1540)]
        )
    )
    _parks.append(_rect_polygon(Rect2(770, 2155, 120, 95)))
    _parks.append(
        PackedVector2Array(
            [Vector2(800, 3200), Vector2(880, 3210), Vector2(868, 3330), Vector2(840, 3330)]
        )
    )
    _parks.append(_rect_polygon(Rect2(1220, 2600, 80, 200)))

    _squares.append(Rect2(1080, 1572, 220, 120))
    _squares.append(Rect2(745, 1600, 140, 80))
    _squares.append(Rect2(800, 2870, 70, 130))

    _add_landmark("uetliberg", 120, 820, 50, 40, 150)
    _add_landmark("opera", 1395, 1585, 150, 100, 30)
    _add_landmark("fraumuenster", 856, 1835, 64, 120, 170)
    _add_landmark("grossmuenster", 1090, 1855, 120, 120, 140)
    _add_landmark("st_peter", 790, 1995, 76, 96, 130)
    _add_landmark("university", 1600, 2520, 170, 110, 90)
    _add_landmark("eth", 1450, 2700, 290, 170, 40)
    _add_landmark("main_station", 630, 2937, 330, 140, 30)
    _add_landmark("landesmuseum", 832, 3125, 66, 120, 60)
    _add_landmark("prime_tower", 250, 3640, 90, 64, 330)

    for square in _squares:
        _keep_free.append(square.grow(10.0))

    var bahnhofstrasse := _bahnhofstrasse
    _tram_routes.append(_to_local(bahnhofstrasse))
    var limmatquai := PackedVector2Array()
    var limmatstrasse := PackedVector2Array()
    for i in range(30):
        var d := lerpf(1680, 2860, i / 29.0)
        limmatquai.append(Vector2(d, limmat_x(d) + limmat_width(d) / 2.0 + 20.0))
        var north := lerpf(3500, 5000, i / 29.0)
        limmatstrasse.append(Vector2(north, limmat_x(north) - limmat_width(north) / 2.0 - 120.0))
    _tram_routes.append(_to_local(limmatquai, true))
    _tram_routes.append(_to_local(limmatstrasse, true))
    var utoquai := PackedVector2Array()
    var mythenquai := PackedVector2Array()
    for i in range(24):
        var d := lerpf(-300, 1560, i / 23.0)
        utoquai.append(Vector2(d, _interpolate(_lake_east, d) + 22.0))
        mythenquai.append(Vector2(d, _interpolate(_lake_west, d) - 22.0))
    _tram_routes.append(_to_local(utoquai, true))
    _tram_routes.append(_to_local(mythenquai, true))


func _add_landmark(kind: String, x: float, d: float, w: float, h: float, tall: float) -> void:
    _landmarks.append({"kind": kind, "x": x, "d": d, "w": w, "h": h, "tall": tall})
    _keep_free.append(
        Rect2(x - w / 2.0 - 16.0, d - h / 2.0 - 16.0, w + 32.0, h + 32.0 + tall * 0.7)
    )


func _to_local(points: PackedVector2Array, swapped: bool = false) -> PackedVector2Array:
    var result := PackedVector2Array()
    for p in points:
        result.append(at(p.y, p.x) if swapped else at(p.x, p.y))
    return result


static func ellipse(center: Vector2, radii: Vector2, count: int) -> PackedVector2Array:
    var result := PackedVector2Array()
    for i in range(count):
        var angle := TAU * i / count
        var wobble := 1.0 + 0.06 * sin(angle * 5.0)
        result.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * wobble)
    return result


static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
    return PackedVector2Array(
        [
            rect.position,
            Vector2(rect.end.x, rect.position.y),
            rect.end,
            Vector2(rect.position.x, rect.end.y)
        ]
    )


## Interpolate x at d along the points (d, x), smoothly (Catmull-Rom).
static func _interpolate(points: PackedVector2Array, d: float) -> float:
    if d <= points[0].x:
        return points[0].y
    if d >= points[-1].x:
        return points[-1].y
    var i := 0
    while points[i + 1].x < d:
        i += 1
    var p1 := points[i]
    var p2 := points[i + 1]
    var p0 := points[i - 1] if i > 0 else p1
    var p3 := points[i + 2] if i + 2 < points.size() else p2
    var t := (d - p1.x) / (p2.x - p1.x)
    var t2 := t * t
    var t3 := t2 * t
    return (
        0.5
        * (
            2.0 * p1.y
            + (-p0.y + p2.y) * t
            + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2
            + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
        )
    )


## Return true if a building may stand at (x, d).
func _is_free(x: float, d: float) -> bool:
    return not _is_open_space(x, d) and not _is_reserved(Vector2(x, d))


## Return true if (x, d) lies in the water, on the tracks or on a main street.
func _is_open_space(x: float, d: float) -> bool:
    var p := Vector2(x, d)
    var water := (
        (d < LAKE_END + 40.0 and Geometry2D.is_point_in_polygon(p, _lake_clear))
        or (d >= LAKE_END - 60.0 and absf(x - limmat_x(d)) < limmat_width(d) / 2.0 + 30.0)
        or (d <= _sihl[-1].x + 20.0 and absf(x - _interpolate(_sihl, d)) < 50.0)
    )
    var tracks := d > 2850.0 and d < 3620.0 and Geometry2D.is_point_in_polygon(p, _track_field)
    var street := d > 1580.0 and d < 2880.0 and absf(x - _interpolate_street(d)) < 20.0

    # NOTE (mristin):
    # The Hardbrücke crosses the tracks on its way north.
    var hardbruecke := (
        d > 2780.0 and d < 3560.0 and absf(x - lerpf(345.0, 300.0, (d - 2780.0) / 780.0)) < 22.0
    )
    var bridge := false
    if d >= MAP_END - 200.0:
        for i in range(-1, 2):
            var bridge_d := (floorf(d / 650.0) + i) * 650.0
            bridge = bridge or (absf(d - bridge_d) < 22.0 and absf(x - limmat_x(d)) < 260.0)
    return water or tracks or street or hardbruecke or bridge


## Return true if (x, d) lies in a park, a forest, a square or at a landmark.
func _is_reserved(p: Vector2) -> bool:
    if p.y >= 5000.0 and p.x > 1700.0 + sin(p.y / 170.0) * 70.0:
        return true
    for rect in _keep_free:
        if rect.has_point(p):
            return true
    var areas: Array[PackedVector2Array] = []
    areas.append_array(_parks)
    areas.append_array(_forests)
    for area in areas:
        if Geometry2D.is_point_in_polygon(p, area):
            return true
    return false


func _interpolate_street(d: float) -> float:
    var points := PackedVector2Array()
    for p in _bahnhofstrasse:
        points.append(Vector2(p.y, p.x))
    return _interpolate(points, d)


# endregion

# region Chunks


func _update_chunks() -> void:
    var first := floori((distance - 450.0) / CHUNK_HEIGHT)
    var last := floori((distance + SCREEN_HEIGHT + 250.0) / CHUNK_HEIGHT)
    for index in _chunks.keys():
        if index < first or index > last:
            for chunk: Node in _chunks[index]:
                chunk.queue_free()
            _chunks.erase(index)
    for index in range(first, last + 1):
        if not _chunks.has(index):
            _chunks[index] = [_new_chunk(index, false), _new_chunk(index, true)]


func _new_chunk(index: int, top: bool) -> Chunk:
    var chunk := Chunk.new()
    chunk.map = self
    chunk.index = index
    chunk.top = top
    (_top_layer if top else _ground_layer).add_child(chunk)
    return chunk


func draw_chunk(c: CanvasItem, index: int, top: bool) -> void:
    var d0 := index * CHUNK_HEIGHT
    var d1 := d0 + CHUNK_HEIGHT
    if top:
        for landmark in _landmarks:
            var d: float = landmark["d"]
            if d >= d0 and d < d1:
                ZurichLandmarks.draw_landmark(c, landmark)
        return

    var band := _rect_polygon(Rect2(-200, d0, SCREEN_WIDTH + 400, CHUNK_HEIGHT))

    for forest in _forests:
        _draw_clipped(c, forest, band, FOREST)
    _draw_procedural_forest(c, d0, d1)
    for park in _parks:
        _draw_clipped(c, park, band, PARK)
    for square in _squares:
        _draw_clipped(c, _rect_polygon(square), band, PAVED)

    _draw_water(c, d0, d1, band)
    _draw_tracks(c, d0, d1)
    _draw_blocks(c, d0, d1)
    _draw_trees(c, index, d0, d1)
    _draw_bridges(c, d0, d1)
    _draw_tram_rails(c, d1)


func _draw_clipped(
    c: CanvasItem, polygon: PackedVector2Array, band: PackedVector2Array, color: Color
) -> void:
    for piece in Geometry2D.intersect_polygons(polygon, band):
        if piece.size() < 3:
            continue
        var local := _to_local(piece)
        if Geometry2D.triangulate_polygon(local).size() > 0:
            c.draw_colored_polygon(local, color)


func _draw_water(c: CanvasItem, d0: float, d1: float, band: PackedVector2Array) -> void:
    if d0 < LAKE_END:
        for quay in Geometry2D.offset_polygon(_lake, 7.0):
            _draw_clipped(c, quay, band, QUAY)
        _draw_clipped(c, _lake, band, WATER)

    if d1 > LAKE_END - 60.0:
        _draw_river(c, maxf(d0 - 12.0, LAKE_END - 60.0), d1 + 12.0, true)
    if d0 < _sihl[-1].x:
        _draw_river(c, d0 - 12.0, minf(d1 + 12.0, _sihl[-1].x), false)

    # NOTE (mristin):
    # A few faint, long ripples on the lake; never small and bright.
    if d0 < LAKE_END:
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(int(d0) + 17)
        for i in range(10):
            var x := rng.randf_range(700, 1650)
            var d := rng.randf_range(d0, d1)
            if Geometry2D.is_point_in_polygon(
                Vector2(x, d), Geometry2D.offset_polygon(_lake, -60.0)[0]
            ):
                var p := at(x, d)
                c.draw_arc(p, 90.0, PI * 1.2, PI * 1.8, 12, WATER_LIGHT, 3.0, true)


func _draw_river(c: CanvasItem, d0: float, d1: float, limmat: bool) -> void:
    if d1 <= d0:
        return
    var left := PackedVector2Array()
    var right := PackedVector2Array()
    var steps := maxi(2, ceili((d1 - d0) / 24.0))
    for i in range(steps + 1):
        var d := lerpf(d0, d1, i / float(steps))
        var x := limmat_x(d) if limmat else _interpolate(_sihl, d)
        var half := (limmat_width(d) if limmat else 56.0) / 2.0
        left.append(Vector2(x - half, d))
        right.append(Vector2(x + half, d))
    for border: float in [7.0, 0.0]:
        var strip := PackedVector2Array()
        for p in left:
            strip.append(at(p.x - border, p.y))
        for i in range(right.size() - 1, -1, -1):
            strip.append(at(right[i].x + border, right[i].y))
        c.draw_colored_polygon(strip, QUAY if border > 0.0 else WATER)


func _draw_tracks(c: CanvasItem, d0: float, d1: float) -> void:
    if d1 < 2850.0 or d0 > 3650.0:
        return
    var band := _rect_polygon(Rect2(-200, d0, SCREEN_WIDTH + 400, d1 - d0))
    _draw_clipped(c, _track_field, band, BALLAST)
    for track in _tracks:
        var local := PackedVector2Array()
        for p in track:
            local.append(at(p.x, p.y))
        for side: float in [-5.0, 5.0]:
            var rail := PackedVector2Array()
            for p in local:
                rail.append(p + Vector2(0, side))
            c.draw_polyline(rail, RAIL, 2.0, true)

    # NOTE (mristin):
    # The Hardbrücke crosses the tracks.
    var from := at(345, 2800)
    var to := at(300, 3560)
    c.draw_line(from, to, QUAY, 40.0)
    c.draw_line(from, to, ASPHALT, 30.0)


func _draw_bridges(c: CanvasItem, d0: float, d1: float) -> void:
    var bridges: Array[Vector2] = _bridges.duplicate()
    if d1 > MAP_END:
        for i in range(floori(d0 / 650.0), ceili(d1 / 650.0) + 1):
            if i * 650.0 > MAP_END:
                bridges.append(Vector2(i * 650.0, 30.0))
    for bridge in bridges:
        if bridge.x < d0 or bridge.x >= d1:
            continue
        var x := limmat_x(bridge.x)
        var half := limmat_width(bridge.x) / 2.0 + 18.0
        var rect := Rect2(at(x - half, bridge.x + bridge.y / 2.0), Vector2(half * 2.0, bridge.y))
        c.draw_rect(rect.grow(3.0), QUAY)
        c.draw_rect(rect, ASPHALT)


func _draw_tram_rails(c: CanvasItem, d1: float) -> void:
    var band := Rect2(-200, SCREEN_HEIGHT - d1 - 20, SCREEN_WIDTH + 400, CHUNK_HEIGHT + 40)
    for route in _tram_routes:
        for i in range(1, route.size()):
            var a := route[i - 1]
            var b := route[i]
            if not band.has_point(a) and not band.has_point(b):
                continue
            for side: float in [-3.5, 3.5]:
                var normal := (b - a).normalized().orthogonal() * side
                c.draw_line(a + normal, b + normal, Color(0.15, 0.15, 0.17), 1.5)


func _draw_procedural_forest(c: CanvasItem, d0: float, d1: float) -> void:
    if d1 < 5000.0:
        return
    var outline := PackedVector2Array()
    var steps := 12
    for i in range(steps + 1):
        var d := lerpf(d0 - 2.0, d1 + 2.0, i / float(steps))
        outline.append(at(1720.0 + sin(d / 170.0) * 70.0 + cos(d / 53.0) * 18.0, d))
    outline.append(at(SCREEN_WIDTH + 100, d1 + 2.0))
    outline.append(at(SCREEN_WIDTH + 100, d0 - 2.0))
    c.draw_colored_polygon(outline, FOREST)


## Return the kind of the city quarter at (x, d), for the look of its blocks.
func _quarter(x: float, d: float) -> int:
    if d < LAKE_END + 20.0:
        return 1 if x > 1100.0 else 2
    if d < 2880.0 and x > 640.0 and x < 1330.0:
        return 0
    return 4 if x > limmat_x(d) else 3


func _draw_blocks(c: CanvasItem, d0: float, d1: float) -> void:
    # NOTE (mristin):
    # Each quarter has its own grid of blocks: the small houses with the red
    # roofs of the old town, the blocks with the courtyards around the lake,
    # the quarters by the tracks, and the villas on the hill.
    var cells: Array[float] = [60.0, 112.0, 120.0, 118.0, 100.0]
    var angles: Array[float] = [0.1, -0.38, 0.3, 0.44, -0.16]
    for quarter in range(5):
        var cell := cells[quarter]
        var u := Vector2.RIGHT.rotated(angles[quarter])
        var v := u.orthogonal()
        var i_range := Vector2(INF, -INF)
        var j_range := Vector2(INF, -INF)
        for corner: Vector2 in [
            Vector2(-100, d0),
            Vector2(SCREEN_WIDTH + 100, d0),
            Vector2(-100, d1),
            Vector2(SCREEN_WIDTH + 100, d1)
        ]:
            var a := corner.dot(u) / cell
            var b := corner.dot(v) / cell
            i_range = Vector2(minf(i_range.x, a), maxf(i_range.y, a))
            j_range = Vector2(minf(j_range.x, b), maxf(j_range.y, b))
        for i in range(floori(i_range.x) - 1, ceili(i_range.y) + 1):
            for j in range(floori(j_range.x) - 1, ceili(j_range.y) + 1):
                var center := (u * (i + 0.5) + v * (j + 0.5)) * cell
                if center.y < d0 or center.y >= d1:
                    continue
                if center.x < -80.0 or center.x > SCREEN_WIDTH + 80.0:
                    continue
                if _quarter(center.x, center.y) != quarter:
                    continue
                var rng := RandomNumberGenerator.new()
                rng.seed = hash(Vector3i(i, j, quarter))
                _draw_block(c, rng, quarter, center, u, v, cell)


func _draw_block(
    c: CanvasItem,
    rng: RandomNumberGenerator,
    quarter: int,
    center: Vector2,
    u: Vector2,
    v: Vector2,
    cell: float
) -> void:
    var fill := 0.8 if quarter == 0 else (0.56 if quarter == 4 else 0.78)
    var half := Vector2(cell * fill / 2.0 * rng.randf_range(0.85, 1.0), cell * fill / 2.0)
    if quarter == 4:
        half *= rng.randf_range(0.7, 1.0)
    for attempt in range(2):
        var corners: Array[Vector2] = [
            center - u * half.x - v * half.y,
            center + u * half.x - v * half.y,
            center + u * half.x + v * half.y,
            center - u * half.x + v * half.y,
        ]
        var free := _is_free(center.x, center.y)
        for corner in corners:
            free = free and _is_free(corner.x, corner.y)
        if free:
            var local := PackedVector2Array()
            for corner in corners:
                local.append(at(corner.x, corner.y))
            _draw_building(c, rng, quarter, local, cell)
            return
        half *= 0.55


func _draw_building(
    c: CanvasItem, rng: RandomNumberGenerator, quarter: int, local: PackedVector2Array, cell: float
) -> void:
    var shadow := PackedVector2Array()
    for p in local:
        shadow.append(p + Vector2(5, 5))
    c.draw_colored_polygon(shadow, SHADOW)

    var shade := rng.randf_range(-0.025, 0.025)
    var color: Color
    match quarter:
        0:
            color = [Color(0.26, 0.15, 0.12), Color(0.235, 0.14, 0.115), Color(0.28, 0.175, 0.135)][
                rng.randi() % 3
            ]
        4:
            color = Color(0.24, 0.17, 0.14) if rng.randf() < 0.6 else Color(0.2, 0.2, 0.205)
        _:
            color = Color(0.19, 0.185, 0.18)
    color = Color(color.r + shade, color.g + shade, color.b + shade)
    c.draw_colored_polygon(local, color)

    var mid_a := local[0].lerp(local[3], 0.5)
    var mid_b := local[1].lerp(local[2], 0.5)
    if quarter == 0 or quarter == 4:
        # NOTE (mristin):
        # The pitched roofs have their ridges, and the old town's rows of
        # houses their walls between the houses.
        c.draw_line(mid_a, mid_b, color.darkened(0.25), 2.0)
        if quarter == 0:
            for k in range(1, 3):
                var t := k / 3.0
                c.draw_line(
                    local[0].lerp(local[1], t), local[3].lerp(local[2], t), color.darkened(0.3), 1.5
                )
    elif cell > 100.0:
        var inner := PackedVector2Array()
        var middle := (local[0] + local[2]) / 2.0
        for p in local:
            inner.append(middle + (p - middle) * 0.45)
        c.draw_colored_polygon(inner, Color(0.11, 0.14, 0.115))


func _draw_trees(c: CanvasItem, index: int, d0: float, d1: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(index * 31 + 7)
    var areas: Array[PackedVector2Array] = []
    areas.append_array(_parks)
    areas.append_array(_forests)
    for i in range(160):
        var x := rng.randf_range(-40, SCREEN_WIDTH + 40)
        var d := rng.randf_range(d0, d1)
        var inside := d >= 5000.0 and x > 1740.0 + sin(d / 170.0) * 70.0
        for area in areas:
            inside = inside or Geometry2D.is_point_in_polygon(Vector2(x, d), area)
        if not inside:
            continue
        var r := rng.randf_range(11, 18)
        var p := at(x, d)
        c.draw_circle(p + Vector2(3, 3), r, SHADOW.lerp(FOREST, 0.5))
        c.draw_circle(p, r, TREE)
        c.draw_circle(p - Vector2(r, r) * 0.25, r * 0.55, TREE_LIGHT)


# endregion

# region Movers


func _add_movers() -> void:
    var starts: Array[float] = [0.1, 0.6, 0.3, 0.5, 0.8, 0.2, 0.4]
    var routes := _tram_routes.duplicate()
    routes.append(_tram_routes[0])
    routes.append(_tram_routes[3])
    for i in range(routes.size()):
        _add_mover("tram", routes[i], 34.0 + 6.0 * (i % 3), starts[i % starts.size()])

    _add_mover(
        "steamer",
        _to_local(
            PackedVector2Array([Vector2(1250, 300), Vector2(1100, 900), Vector2(1000, 1350)])
        ),
        14.0,
        0.2
    )
    _add_mover(
        "sailboat", _to_local(PackedVector2Array([Vector2(820, 500), Vector2(950, 700)])), 8.0, 0.4
    )
    _add_mover(
        "sailboat",
        _to_local(PackedVector2Array([Vector2(1400, 1050), Vector2(1250, 1200)])),
        7.0,
        0.6
    )
    _add_mover(
        "sailboat",
        _to_local(PackedVector2Array([Vector2(1500, 600), Vector2(1450, 250)])),
        9.0,
        0.3
    )
    _add_mover(
        "swan", _to_local(PackedVector2Array([Vector2(960, 1500), Vector2(1020, 1540)])), 5.0, 0.2
    )
    _add_mover(
        "swan", _to_local(PackedVector2Array([Vector2(1000, 1480), Vector2(1060, 1520)])), 5.0, 0.7
    )
    _add_mover(
        "swan", _to_local(PackedVector2Array([Vector2(820, 1100), Vector2(900, 1180)])), 4.0, 0.5
    )
    _add_mover(
        "swan", _to_local(PackedVector2Array([Vector2(990, 2200), Vector2(975, 2300)])), 4.0, 0.5
    )


func _add_mover(kind: String, route: PackedVector2Array, speed: float, start: float) -> void:
    var mover := Mover.new()
    mover.map = self
    mover.kind = kind
    mover.route = route
    mover.speed = speed
    _top_layer.add_child(mover)
    mover.setup(start)

# endregion
