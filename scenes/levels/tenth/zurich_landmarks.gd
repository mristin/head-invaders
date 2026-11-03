class_name ZurichLandmarks

extends RefCounted

## Draw the landmarks of Zurich on the map, seen slightly from the south, and
## the trams, the boats and the swans which move on it.
##
## NOTE (mristin):
## Like the rest of the map, the landmarks are dim, so that nobody mistakes
## them for the projectiles; their shapes make them recognizable.


static func draw_landmark(c: CanvasItem, landmark: Dictionary) -> void:
    var p := ZurichMap.at(landmark["x"], landmark["d"])
    var size := Vector2(landmark["w"], landmark["h"])
    var tall: float = landmark["tall"]
    match landmark["kind"]:
        "uetliberg":
            _draw_uetliberg(c, p, tall)
        "opera":
            _draw_opera(c, p, size)
        "fraumuenster":
            _draw_fraumuenster(c, p, size, tall)
        "grossmuenster":
            _draw_grossmuenster(c, p, size, tall)
        "st_peter":
            _draw_st_peter(c, p, size, tall)
        "university":
            _draw_university(c, p, size, tall)
        "eth":
            _draw_eth(c, p, size)
        "main_station":
            _draw_main_station(c, p, size)
        "landesmuseum":
            _draw_landesmuseum(c, p, size)
        "prime_tower":
            _draw_prime_tower(c, p, size, tall)


## Draw a box standing on the footprint, seen slightly from the south: its
## front wall and its roof, raised by the height.
static func _draw_box(
    c: CanvasItem, footprint: Rect2, height: float, wall: Color, roof: Color
) -> void:
    var lifted := Rect2(footprint.position - Vector2(0, height), footprint.size)
    (
        c
        . draw_colored_polygon(
            PackedVector2Array(
                [
                    footprint.position + Vector2(footprint.size.x, 0) + Vector2(4, 4),
                    lifted.position + Vector2(lifted.size.x, 0) + Vector2(height * 0.35 + 4, 4),
                    lifted.end + Vector2(height * 0.35 + 4, 4),
                    footprint.end + Vector2(4, 4),
                ]
            ),
            ZurichMap.TOWER_SHADOW
        )
    )
    c.draw_rect(Rect2(lifted.position.x, lifted.end.y, footprint.size.x, height), wall)
    c.draw_rect(lifted, roof)


static func _draw_uetliberg(c: CanvasItem, p: Vector2, tall: float) -> void:
    # NOTE (mristin):
    # The hill top is a clearing in the forest, with the lattice tower.
    c.draw_circle(p + Vector2(0, 10), 70.0, ZurichMap.PARK)
    c.draw_circle(p + Vector2(0, 10), 46.0, Color(0.13, 0.16, 0.11))
    var foot := p + Vector2(0, 20)
    var top := foot - Vector2(0, tall)
    var steel := Color(0.3, 0.3, 0.32)
    c.draw_line(foot + Vector2(10, 4), top + Vector2(tall * 0.3 + 4, 4), ZurichMap.SHADOW, 10.0)
    for side: float in [-1.0, 1.0]:
        c.draw_line(foot + Vector2(side * 22, 0), top + Vector2(side * 6, 0), steel, 4.0)
    for k in range(6):
        var a := foot.lerp(top, k / 6.0)
        var b := foot.lerp(top, (k + 1) / 6.0)
        var wa := lerpf(22, 6, k / 6.0)
        var wb := lerpf(22, 6, (k + 1) / 6.0)
        c.draw_line(a + Vector2(-wa, 0), b + Vector2(wb, 0), steel, 2.0)
        c.draw_line(a + Vector2(wa, 0), b + Vector2(-wb, 0), steel, 2.0)
    c.draw_rect(Rect2(top + Vector2(-12, -10), Vector2(24, 12)), steel)


static func _draw_opera(c: CanvasItem, p: Vector2, size: Vector2) -> void:
    var footprint := Rect2(p - size / 2.0, size)
    _draw_box(c, footprint, 26.0, ZurichMap.SANDSTONE_DARK, ZurichMap.SANDSTONE)
    var roof := Rect2(footprint.position - Vector2(0, 26), footprint.size)
    # The higher stage house in the back and the copper roof in the middle.
    c.draw_rect(
        Rect2(roof.position + Vector2(size.x * 0.55, 10), Vector2(size.x * 0.4, size.y - 20)),
        ZurichMap.SLATE
    )
    c.draw_circle(
        roof.get_center() - Vector2(size.x * 0.12, 0), size.y * 0.28, ZurichMap.COPPER_DARK
    )
    c.draw_circle(roof.get_center() - Vector2(size.x * 0.12, 0), size.y * 0.2, ZurichMap.COPPER)
    # The columns of the front, which faces the square to the west.
    for k in range(6):
        var y := roof.position.y + 12 + k * (size.y - 24) / 5.0
        c.draw_circle(Vector2(roof.position.x - 6, y), 4.5, ZurichMap.SANDSTONE)
    c.draw_line(
        roof.position - Vector2(10, 0),
        Vector2(roof.position.x - 10, roof.end.y),
        ZurichMap.SANDSTONE,
        3.0
    )


static func _draw_church_nave(c: CanvasItem, footprint: Rect2, roof: Color) -> void:
    c.draw_rect(Rect2(footprint.position + Vector2(5, 5), footprint.size), ZurichMap.SHADOW)
    c.draw_rect(footprint, ZurichMap.SANDSTONE_DARK)
    c.draw_rect(footprint.grow_individual(-4, -4, -4, -4), roof)
    var mid := footprint.position.x + footprint.size.x / 2.0
    c.draw_line(
        Vector2(mid, footprint.position.y + 4),
        Vector2(mid, footprint.end.y - 4),
        roof.darkened(0.3),
        2.0
    )


static func _draw_fraumuenster(c: CanvasItem, p: Vector2, size: Vector2, tall: float) -> void:
    # NOTE (mristin):
    # The church by the Limmat with its slender, green, pointed spire.
    _draw_church_nave(c, Rect2(p - size / 2.0, size), ZurichMap.SLATE)
    var foot := p + Vector2(0, size.y * 0.35)
    var tower := Rect2(foot - Vector2(14, tall * 0.45), Vector2(28, tall * 0.45))
    c.draw_colored_polygon(
        PackedVector2Array(
            [
                foot + Vector2(14, 4),
                foot + Vector2(14 + tall * 0.35, 4 - tall),
                foot + Vector2(22 + tall * 0.2, 4)
            ]
        ),
        ZurichMap.TOWER_SHADOW
    )
    c.draw_rect(tower, ZurichMap.SANDSTONE)
    c.draw_rect(Rect2(tower.position + Vector2(9, 12), Vector2(10, 16)), ZurichMap.SANDSTONE_DARK)
    c.draw_circle(tower.position + Vector2(14, 44), 6.0, ZurichMap.SANDSTONE_DARK)
    var spire_base := tower.position.y
    (
        c
        . draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(foot.x - 16, spire_base),
                    Vector2(foot.x, foot.y - tall),
                    Vector2(foot.x + 16, spire_base),
                ]
            ),
            ZurichMap.COPPER
        )
    )
    c.draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(foot.x, spire_base),
                Vector2(foot.x, foot.y - tall),
                Vector2(foot.x + 16, spire_base)
            ]
        ),
        ZurichMap.COPPER_DARK
    )


static func _draw_grossmuenster(c: CanvasItem, p: Vector2, size: Vector2, tall: float) -> void:
    # NOTE (mristin):
    # The twin towers with their domed tops, the symbol of the city.
    _draw_church_nave(
        c,
        Rect2(p - Vector2(size.x * 0.3, size.y * 0.5), Vector2(size.x * 0.6, size.y)),
        ZurichMap.SLATE
    )
    var foot_y := p.y + size.y * 0.45
    var tower_height := tall * 0.72
    for side: float in [-1.0, 1.0]:
        var x := p.x + side * size.x * 0.28
        var tower := Rect2(Vector2(x - 17, foot_y - tower_height), Vector2(34, tower_height))
        (
            c
            . draw_colored_polygon(
                PackedVector2Array(
                    [
                        Vector2(tower.end.x, foot_y) + Vector2(3, 3),
                        Vector2(tower.end.x + tall * 0.35, foot_y - tall * 0.9) + Vector2(3, 3),
                        (
                            Vector2(tower.end.x + tall * 0.35 + 14, foot_y - tall * 0.9)
                            + Vector2(3, 3)
                        ),
                        Vector2(tower.end.x + 14, foot_y) + Vector2(3, 3),
                    ]
                ),
                ZurichMap.TOWER_SHADOW
            )
        )
    for side: float in [-1.0, 1.0]:
        var x := p.x + side * size.x * 0.28
        var tower := Rect2(Vector2(x - 17, foot_y - tower_height), Vector2(34, tower_height))
        c.draw_rect(tower, ZurichMap.SANDSTONE)
        c.draw_rect(
            Rect2(tower.position + Vector2(25, 0), Vector2(9, tower_height)),
            ZurichMap.SANDSTONE_DARK
        )
        for k in range(3):
            var y := tower.position.y + 14 + k * tower_height / 3.2
            c.draw_rect(
                Rect2(Vector2(x - 6, y), Vector2(10, 14)), ZurichMap.SANDSTONE_DARK.darkened(0.2)
            )
        c.draw_rect(
            Rect2(Vector2(x - 20, tower.position.y - 6), Vector2(40, 8)), ZurichMap.SANDSTONE_DARK
        )
        # The domed helmet, with its little point.
        var dome_center := Vector2(x, tower.position.y - 6)
        c.draw_colored_polygon(_dome(dome_center, 19.0, 30.0), ZurichMap.SLATE)
        c.draw_colored_polygon(
            _dome(dome_center + Vector2(4, 0), 12.0, 26.0), Color(0.22, 0.22, 0.25)
        )
        c.draw_line(
            dome_center - Vector2(0, 30), dome_center - Vector2(0, 42), ZurichMap.SLATE, 3.0
        )
        c.draw_circle(dome_center - Vector2(0, 42), 3.0, ZurichMap.SANDSTONE)
    c.draw_rect(
        Rect2(
            Vector2(p.x - size.x * 0.13, foot_y - tower_height * 0.45),
            Vector2(size.x * 0.26, tower_height * 0.45)
        ),
        ZurichMap.SANDSTONE_DARK
    )


static func _dome(base_center: Vector2, half_width: float, height: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for k in range(13):
        var angle := PI * k / 12.0
        points.append(base_center + Vector2(-cos(angle) * half_width, -sin(angle) * height))
    return points


static func _draw_st_peter(c: CanvasItem, p: Vector2, size: Vector2, tall: float) -> void:
    # NOTE (mristin):
    # The tower with the biggest church clock faces of Europe.
    _draw_church_nave(
        c,
        Rect2(p - Vector2(size.x * 0.4, size.y * 0.55), Vector2(size.x * 0.8, size.y * 0.8)),
        ZurichMap.SLATE
    )
    var foot := p + Vector2(0, size.y * 0.45)
    var height := tall * 0.7
    var tower := Rect2(foot - Vector2(26, height), Vector2(52, height))
    (
        c
        . draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(tower.end.x + 3, foot.y + 3),
                    Vector2(tower.end.x + tall * 0.35 + 3, foot.y - tall + 3),
                    Vector2(tower.end.x + tall * 0.35 + 20, foot.y - tall + 3),
                    Vector2(tower.end.x + 20, foot.y + 3),
                ]
            ),
            ZurichMap.TOWER_SHADOW
        )
    )
    c.draw_rect(tower, ZurichMap.SANDSTONE)
    c.draw_rect(
        Rect2(tower.position + Vector2(40, 0), Vector2(12, height)), ZurichMap.SANDSTONE_DARK
    )
    var dial := Vector2(foot.x - 2, tower.position.y + 28)
    c.draw_circle(dial, 24.0, Color(0.13, 0.13, 0.15))
    c.draw_arc(dial, 24.0, 0.0, TAU, 32, Color(0.42, 0.37, 0.24), 3.0, true)
    for k in range(12):
        var angle := TAU * k / 12.0
        c.draw_line(
            dial + Vector2.from_angle(angle) * 17.0,
            dial + Vector2.from_angle(angle) * 21.0,
            Color(0.42, 0.37, 0.24),
            2.0
        )
    c.draw_line(dial, dial + Vector2(0, -15), Color(0.42, 0.37, 0.24), 3.0)
    c.draw_line(dial, dial + Vector2(11, 4), Color(0.42, 0.37, 0.24), 3.0)
    var spire := tower.position.y
    c.draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(foot.x - 28, spire),
                Vector2(foot.x, foot.y - tall),
                Vector2(foot.x + 28, spire)
            ]
        ),
        ZurichMap.COPPER_DARK
    )
    c.draw_colored_polygon(
        PackedVector2Array(
            [Vector2(foot.x - 28, spire), Vector2(foot.x, foot.y - tall), Vector2(foot.x, spire)]
        ),
        ZurichMap.COPPER
    )


static func _draw_university(c: CanvasItem, p: Vector2, size: Vector2, tall: float) -> void:
    var footprint := Rect2(p - size / 2.0, size)
    _draw_box(c, footprint, 20.0, ZurichMap.SANDSTONE_DARK, ZurichMap.SANDSTONE.darkened(0.1))
    var tower := Rect2(p + Vector2(-20, size.y * 0.2 - tall), Vector2(40, tall))
    _draw_box(
        c,
        Rect2(tower.position + Vector2(0, tall - 30), Vector2(40, 30)),
        tall - 30,
        ZurichMap.SANDSTONE_DARK,
        ZurichMap.SANDSTONE
    )
    c.draw_colored_polygon(
        _dome(Vector2(tower.get_center().x, tower.position.y), 22.0, 18.0), ZurichMap.COPPER
    )


static func _draw_eth(c: CanvasItem, p: Vector2, size: Vector2) -> void:
    # NOTE (mristin):
    # The main building on the hill, with its two courtyards and the dome
    # looking over the city to the west.
    var footprint := Rect2(p - size / 2.0, size)
    _draw_box(c, footprint, 22.0, ZurichMap.SANDSTONE_DARK, ZurichMap.SANDSTONE)
    var roof := Rect2(footprint.position - Vector2(0, 22), footprint.size)
    for side: float in [-1.0, 1.0]:
        var court := Rect2(
            (
                roof.get_center()
                + Vector2(size.x * 0.08, side * size.y * 0.22)
                - Vector2(size.x * 0.17, size.y * 0.13)
            ),
            Vector2(size.x * 0.34, size.y * 0.26)
        )
        c.draw_rect(court, Color(0.13, 0.15, 0.12))
    c.draw_rect(
        Rect2(roof.position + Vector2(0, size.y * 0.3), Vector2(size.x * 0.22, size.y * 0.4)),
        ZurichMap.SANDSTONE.lightened(0.05)
    )
    var dome := Vector2(roof.position.x + size.x * 0.11, roof.get_center().y)
    c.draw_circle(dome + Vector2(5, 5), 34.0, ZurichMap.SHADOW)
    c.draw_circle(dome, 34.0, ZurichMap.COPPER_DARK)
    c.draw_circle(dome - Vector2(6, 6), 24.0, ZurichMap.COPPER)
    c.draw_circle(dome - Vector2(6, 6), 8.0, ZurichMap.COPPER_DARK)
    # The Polyterrasse with its steps down to the city.
    for k in range(4):
        c.draw_line(
            Vector2(roof.position.x - 18 - k * 9, roof.position.y + 20),
            Vector2(roof.position.x - 18 - k * 9, roof.end.y - 20),
            ZurichMap.PAVED.lightened(0.1),
            3.0
        )


static func _draw_main_station(c: CanvasItem, p: Vector2, size: Vector2) -> void:
    # NOTE (mristin):
    # The big hall with its arched roof, the front building facing the river,
    # and the platforms reaching out to the tracks.
    var hall := Rect2(p - size / 2.0, size)
    var platforms := Rect2(hall.position - Vector2(150, -6), Vector2(150, size.y - 12))
    c.draw_rect(Rect2(platforms.position + Vector2(5, 5), platforms.size), ZurichMap.SHADOW)
    c.draw_rect(platforms, Color(0.15, 0.15, 0.16))
    for k in range(6):
        var y := platforms.position.y + 10 + k * (platforms.size.y - 20) / 5.0
        c.draw_line(
            Vector2(platforms.position.x, y),
            Vector2(platforms.end.x, y),
            Color(0.22, 0.22, 0.23),
            7.0
        )

    _draw_box(c, hall, 30.0, ZurichMap.SANDSTONE_DARK, Color(0.2, 0.22, 0.24))
    var roof := Rect2(hall.position - Vector2(0, 30), hall.size)
    for k in range(12):
        var x := roof.position.x + 12 + k * (roof.size.x - 60) / 11.0
        c.draw_line(
            Vector2(x, roof.position.y + 4),
            Vector2(x, roof.end.y - 4),
            Color(0.27, 0.29, 0.31),
            3.0
        )
    c.draw_line(
        Vector2(roof.position.x, roof.get_center().y),
        Vector2(roof.end.x - 50, roof.get_center().y),
        Color(0.15, 0.17, 0.19),
        4.0
    )
    var front := Rect2(
        Vector2(roof.end.x - 48, roof.position.y - 10), Vector2(56, roof.size.y + 20)
    )
    c.draw_rect(Rect2(front.position + Vector2(5, 5), front.size), ZurichMap.SHADOW)
    c.draw_rect(front, ZurichMap.SANDSTONE)
    c.draw_rect(
        Rect2(front.position + Vector2(0, front.size.y * 0.3), Vector2(56, front.size.y * 0.4)),
        ZurichMap.SANDSTONE.lightened(0.06)
    )
    c.draw_colored_polygon(
        _dome(Vector2(front.end.x + 1, front.get_center().y + 22), 22.0, 0.0), ZurichMap.SANDSTONE
    )
    c.draw_arc(
        Vector2(front.end.x - 6, front.get_center().y),
        18.0,
        -PI / 2.0,
        PI / 2.0,
        12,
        ZurichMap.SANDSTONE_DARK,
        4.0
    )


static func _draw_landesmuseum(c: CanvasItem, p: Vector2, size: Vector2) -> void:
    # NOTE (mristin):
    # The museum looks like a castle, with its turrets.
    var footprint := Rect2(p - size / 2.0, size)
    _draw_box(c, footprint, 24.0, ZurichMap.SANDSTONE_DARK, ZurichMap.SLATE)
    var roof := Rect2(footprint.position - Vector2(0, 24), footprint.size)
    c.draw_rect(roof.grow(-14), Color(0.13, 0.15, 0.12))
    for corner: Vector2 in [
        roof.position,
        Vector2(roof.end.x, roof.position.y),
        Vector2(roof.position.x, roof.end.y),
        roof.end
    ]:
        c.draw_rect(Rect2(corner - Vector2(9, 22), Vector2(18, 26)), ZurichMap.SANDSTONE)
        c.draw_colored_polygon(
            PackedVector2Array(
                [corner + Vector2(-11, -22), corner + Vector2(0, -44), corner + Vector2(11, -22)]
            ),
            ZurichMap.SLATE.lightened(0.1)
        )


static func _draw_prime_tower(c: CanvasItem, p: Vector2, size: Vector2, tall: float) -> void:
    # NOTE (mristin):
    # The tall glass tower of the west, seen slightly from the south, with its
    # long shadow; its glass gets a little wider towards the top.
    var foot := Rect2(p - size / 2.0, size)
    (
        c
        . draw_colored_polygon(
            PackedVector2Array(
                [
                    foot.position + Vector2(size.x, size.y) + Vector2(4, 4),
                    foot.position + Vector2(size.x, 0) + Vector2(4, 4),
                    foot.position + Vector2(size.x + tall * 0.55, -tall * 0.3),
                    foot.position + Vector2(size.x + tall * 0.55, size.y - tall * 0.3),
                ]
            ),
            ZurichMap.TOWER_SHADOW
        )
    )
    var top_y := foot.end.y - tall
    var wall := PackedVector2Array(
        [
            Vector2(foot.position.x, foot.end.y),
            Vector2(foot.end.x, foot.end.y),
            Vector2(foot.end.x + 6, top_y),
            Vector2(foot.position.x - 6, top_y),
        ]
    )
    c.draw_colored_polygon(wall, ZurichMap.GLASS)
    c.draw_colored_polygon(
        PackedVector2Array(
            [
                wall[0],
                wall[0] + Vector2(size.x * 0.35, 0),
                wall[3] + Vector2(size.x * 0.35 + 2, 0),
                wall[3]
            ]
        ),
        ZurichMap.GLASS_LIGHT
    )
    for k in range(1, 18):
        var y := lerpf(foot.end.y, top_y, k / 18.0)
        var spread := lerpf(0.0, 6.0, k / 18.0)
        c.draw_line(
            Vector2(foot.position.x - spread, y),
            Vector2(foot.end.x + spread, y),
            Color(0.15, 0.2, 0.22),
            1.5
        )
    (
        c
        . draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(foot.position.x - 6, top_y),
                    Vector2(foot.end.x + 6, top_y),
                    Vector2(foot.end.x + 2, top_y - size.y * 0.7),
                    Vector2(foot.position.x - 2, top_y - size.y * 0.7),
                ]
            ),
            Color(0.24, 0.27, 0.28)
        )
    )


static func draw_mover(c: CanvasItem, kind: String, heading: Vector2, time: float) -> void:
    c.draw_set_transform(Vector2.ZERO, heading.angle())
    match kind:
        "tram":
            c.draw_rect(Rect2(-36, -7, 76, 18), ZurichMap.SHADOW)
            c.draw_rect(Rect2(-38, -9, 76, 18), ZurichMap.TRAM_BLUE)
            c.draw_rect(Rect2(-34, -4, 68, 8), ZurichMap.TRAM_WHITE)
            for k in range(3):
                c.draw_line(
                    Vector2(-13 + k * 13, -9),
                    Vector2(-13 + k * 13, 9),
                    ZurichMap.TRAM_BLUE.darkened(0.3),
                    2.0
                )
            c.draw_rect(Rect2(32, -8, 6, 16), ZurichMap.TRAM_BLUE.lightened(0.1))
        "steamer":
            var hull := PackedVector2Array(
                [
                    Vector2(-70, -16),
                    Vector2(50, -16),
                    Vector2(78, 0),
                    Vector2(50, 16),
                    Vector2(-70, 16)
                ]
            )
            c.draw_colored_polygon(hull, Color(0.3, 0.31, 0.32))
            c.draw_rect(Rect2(-50, -10, 80, 20), Color(0.24, 0.24, 0.25))
            c.draw_rect(Rect2(-14, -26, 26, 10), Color(0.2, 0.2, 0.22))
            c.draw_rect(Rect2(-14, 16, 26, 10), Color(0.2, 0.2, 0.22))
            c.draw_circle(Vector2(10, 0), 8.0, Color(0.22, 0.2, 0.2))
            for k in range(2):
                var wake := fmod(time * 0.6 + k * 0.5, 1.0)
                c.draw_arc(
                    Vector2(-78 - wake * 50, 0),
                    14 + wake * 30,
                    PI * 0.6,
                    PI * 1.4,
                    10,
                    Color(ZurichMap.WATER_LIGHT, 1.0 - wake),
                    3.0
                )
        "sailboat":
            var bob := sin(time * 0.8) * 0.06
            c.draw_set_transform(Vector2.ZERO, heading.angle() + bob)
            c.draw_colored_polygon(
                PackedVector2Array(
                    [
                        Vector2(-22, -8),
                        Vector2(14, -8),
                        Vector2(26, 0),
                        Vector2(14, 8),
                        Vector2(-22, 8)
                    ]
                ),
                Color(0.27, 0.26, 0.24)
            )
            c.draw_colored_polygon(
                PackedVector2Array([Vector2(-14, 0), Vector2(16, 0), Vector2(-6, -30)]),
                Color(0.3, 0.31, 0.33)
            )
        "swan":
            c.draw_set_transform(Vector2.ZERO, heading.angle() + sin(time * 0.5) * 0.3)
            c.draw_arc(Vector2(-18, 0), 18.0, PI * 0.7, PI * 1.3, 8, ZurichMap.WATER_LIGHT, 2.0)
            c.draw_colored_polygon(
                ZurichMap.ellipse(Vector2.ZERO, Vector2(15, 9), 12), Color(0.31, 0.32, 0.34)
            )
            c.draw_line(Vector2(6, 0), Vector2(16, 0), Color(0.31, 0.32, 0.34), 4.0)
            c.draw_circle(Vector2(17, 0), 3.5, Color(0.31, 0.32, 0.34))
            c.draw_line(Vector2(19, 0), Vector2(24, 0), Color(0.36, 0.24, 0.14), 2.5)
    c.draw_set_transform(Vector2.ZERO, 0.0)
