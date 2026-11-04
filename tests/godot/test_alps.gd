extends SceneTree
## Test the Swiss Alps of the ninth level: the level itself, and each of its
## creatures and the cuckoo clock in its own test level, played by the scripted
## players, headless.
##
## Run it directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_alps.gd

const _TESTS: String = "res://scenes/tests/levels"
const _NINTH: String = "res://scenes/levels/ninth/ninth.tscn"

## How many times we play the cuckoo clock, so that the players beat it
## reliably, not by chance.
const _CLOCK_RUNS: int = 3

var _failures: Array[String] = []


class Metrics:
    var messages := []
    var kinds_seen := {}
    var looks_seen := {}
    var rings_mooed := 0
    var tunes_rung := 0
    var marmot_pops := 0
    var marmot_hops := 0
    var marmot_peekaboos := 0
    var marmot_hidden_seen := false
    var marmot_hit_while_hidden := false
    var gondola_trips := 0
    var gondola_throws := 0
    var gondola_on_cable := true
    var yodels := 0
    var echoes := 0
    var echo_notes := 0
    var chimes := {}
    var ticklish_hits := 0
    var cones_dropped := 0
    var lanes_seen := false
    var clock_lost_energy := false
    var min_health := 1000


func _check(condition: bool, message: String) -> void:
    print(("PASS " if condition else "FAIL ") + message)
    if not condition:
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _play_case(title: String, level_path: String, players_path: String, seconds: float) -> Metrics:
    print("--- ", title)
    var players: HeadController = (load(players_path) as GDScript).new()
    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_head_controllers([players])
    game.level_scene_paths = [level_path]
    root.add_child(game)

    var m := Metrics.new()
    var marmot_energy := {}
    var elapsed := 0.0
    while elapsed < seconds:
        await create_timer(0.05).timeout
        elapsed += 0.05

        for child in game.get_children():
            if child is FinalMessage and not child.is_queued_for_deletion():
                var message_title: String = child.title.text
                if m.messages.is_empty() or m.messages[-1] != message_title:
                    m.messages.append(message_title)
        if game.get_tree().paused:
            continue
        if not m.messages.is_empty():
            # NOTE: The level is accomplished; we skip the next round.
            continue

        var level := game.get_node("Screen").get_child(0)
        for key in game._fleet._spaceships:
            m.min_health = mini(m.min_health, game._fleet._spaceships[key].health)

        var echo_spots: Array[Vector2] = []
        for child in level.get_node("Enemies").get_children():
            if not (child is Enemy) or child.is_queued_for_deletion():
                continue
            if child.has_arrived():
                m.kinds_seen[child.get_script().get_global_name()] = true
            if child is BellCow:
                m.rings_mooed = maxi(m.rings_mooed, child.rings_mooed)
                m.tunes_rung = maxi(m.tunes_rung, child.tunes_rung)
            if child is Marmot:
                m.marmot_pops = maxi(m.marmot_pops, child.pops)
                m.marmot_hops = maxi(m.marmot_hops, child.hops)
                m.marmot_peekaboos = maxi(m.marmot_peekaboos, child.peekaboos)
                # NOTE: We compare the energy between two samples in the burrow.
                var hidden: bool = child.has_arrived() and child.is_alive() and child.is_hidden()
                if hidden:
                    m.marmot_hidden_seen = true
                    if marmot_energy.has(child) and marmot_energy[child] != child.energy:
                        m.marmot_hit_while_hidden = true
                    marmot_energy[child] = child.energy
                else:
                    marmot_energy.erase(child)
            if child is Gondola:
                m.gondola_trips = maxi(m.gondola_trips, child.trips)
                m.gondola_throws = maxi(m.gondola_throws, child.throws)
                if child.has_arrived() and child.is_alive():
                    var on_cable: Vector2 = child._on_cable(child.global_position.x)
                    if on_cable.distance_to(child.global_position) > 1.0:
                        m.gondola_on_cable = false
            if child is Yodeler:
                m.yodels = maxi(m.yodels, child.yodels)
                m.echoes = maxi(m.echoes, child.echoes)
                if child.is_echo_coming():
                    echo_spots.append(child.echo_position())
            if child is CuckooClock:
                for chime in child.chimes:
                    m.chimes[chime] = maxi(m.chimes.get(chime, 0), child.chimes[chime])
                m.ticklish_hits = maxi(m.ticklish_hits, child.ticklish_hits)
                m.cones_dropped = maxi(m.cones_dropped, child.cones_dropped)
                if not child.cone_lanes().is_empty():
                    m.lanes_seen = true
                if child.energy < child.max_energy:
                    m.clock_lost_energy = true

        for child in level.get_node("Projectiles").get_children():
            var rocket := child as Rocket
            if rocket == null:
                continue
            m.looks_seen[rocket.look] = true
            for spot in echo_spots:
                if (
                    rocket.look == Rocket.Look.NOTE
                    and rocket.global_position.distance_to(spot) < 60.0
                ):
                    m.echo_notes += 1

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _check_ninth_level() -> void:
    print("--- ninth level")
    var level: Node = (load(_NINTH) as PackedScene).instantiate()
    _check(level.name == "Ninth", "ninth: the level is called Ninth (%s)" % level.name)
    var chests: ChestDrops = level.get_node("ChestDrops")
    _check(chests.enabled, "ninth: the treasure chests are enabled")
    _check(
        not chests.styles.is_empty() and not chests.styles.has(Chest.Style.CAPSULE),
        "ninth: the chests fit the mountains (%s)" % str(chests.styles)
    )

    var material := (level.get_node("Stars") as ColorRect).material as ShaderMaterial
    _check(
        material != null and material.shader.resource_path.ends_with("alps.gdshader"),
        "ninth: the background is the Alps"
    )
    # NOTE: The headless renderer knows no shader defaults, so we read the code.
    var scroll := RegEx.create_from_string("uniform float scroll_speed = ([0-9.]+);")
    var found := scroll.search(material.shader.code)
    var scroll_speed := float(found.get_string(1)) if found != null else -1.0

    var waiting: Array[String] = []
    var waves := {}
    var kinds := {}
    for child in level.get_node("Enemies").get_children():
        var enemy := child as Enemy
        if enemy == null:
            continue
        kinds[enemy.get_script().get_global_name()] = true
        if enemy.waits_for_others:
            waiting.append(enemy.get_script().get_global_name())
            _check(
                is_equal_approx(enemy.entry_delay, 2.0),
                "ninth: the boss enters 2 s after the others (%.1f)" % enemy.entry_delay
            )
        else:
            var wave := enemy.name.substr(0, 5)
            waves[wave] = waves.get(wave, 0) + 1
        if enemy is GroundEnemy:
            _check(
                is_equal_approx(enemy.ground_speed, scroll_speed),
                (
                    "ninth: %s slides with the mountains (%.1f vs. %.1f)"
                    % [enemy.name, enemy.ground_speed, scroll_speed]
                )
            )
    _check(
        waiting == ["CuckooClock"],
        "ninth: the cuckoo clock is the only one to wait for the others (%s)" % str(waiting)
    )
    _check(
        (
            kinds.has("BellCow")
            and kinds.has("Marmot")
            and kinds.has("Gondola")
            and kinds.has("Yodeler")
        ),
        "ninth: all the alpine creatures come (%s)" % str(kinds.keys())
    )
    _check(
        waves.size() >= 4 and waves.size() <= 5,
        "ninth: four or five waves (%s)" % str(waves.keys())
    )
    var crowded := waves.values().filter(func(count): return count > 2)
    _check(crowded.is_empty(), "ninth: at most two enemies per wave (%s)" % str(waves))
    level.free()


func _run() -> void:
    _check_ninth_level()

    var m: Metrics

    m = await _play_case(
        "bell cow and marmot",
        _TESTS + "/test_cow_marmot/test_cow_marmot.tscn",
        _TESTS + "/test_cow_marmot/test_cow_marmot_players.gd",
        80.0
    )
    _check(m.rings_mooed >= 1, "bell cow: it moos a ring of notes (%d)" % m.rings_mooed)
    _check(m.tunes_rung >= 1, "bell cow: it rings a tune at the player (%d)" % m.tunes_rung)
    _check(m.marmot_hidden_seen, "marmot: it hides in its burrows")
    _check(not m.marmot_hit_while_hidden, "marmot: the bullets can not reach it in its burrow")
    _check(m.marmot_pops >= 2, "marmot: it stands up again and again (%d)" % m.marmot_pops)
    _check(m.marmot_hops >= 1, "marmot: it peeks out of another burrow (%d)" % m.marmot_hops)
    _check(
        m.marmot_peekaboos >= 1, "marmot: it ducks when hit, peek-a-boo (%d)" % m.marmot_peekaboos
    )
    _check(
        m.looks_seen.has(Rocket.Look.NOTE) and m.looks_seen.has(Rocket.Look.SNOWBALL),
        "bell cow and marmot: the notes and the snowballs fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "bell cow and marmot: the players chase them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "gondola and yodeler",
        _TESTS + "/test_gondola_yodeler/test_gondola_yodeler.tscn",
        _TESTS + "/test_gondola_yodeler/test_gondola_yodeler_players.gd",
        80.0
    )
    _check(m.gondola_on_cable, "gondola: it hangs on its cable all the time")
    _check(
        m.gondola_trips >= 1,
        "gondola: it slides from one station to the other (%d)" % m.gondola_trips
    )
    _check(m.gondola_throws >= 2, "gondola: the passengers throw snowballs (%d)" % m.gondola_throws)
    _check(m.yodels >= 1, "yodeler: he yodels (%d)" % m.yodels)
    _check(m.echoes >= 1, "yodeler: the mountains echo his tune (%d)" % m.echoes)
    _check(m.echo_notes >= 1, "yodeler: the echo's notes come from the far side")
    _check(
        m.looks_seen.has(Rocket.Look.NOTE) and m.looks_seen.has(Rocket.Look.SNOWBALL),
        "gondola and yodeler: the notes and the snowballs fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "gondola and yodeler: the players chase them away (%s)" % str(m.messages)
    )

    for run in range(_CLOCK_RUNS):
        m = await _play_case(
            "cuckoo clock, run %d" % (run + 1),
            _TESTS + "/test_cuckoo_clock/test_cuckoo_clock.tscn",
            _TESTS + "/test_cuckoo_clock/test_cuckoo_clock_players.gd",
            110.0
        )
        var title := "cuckoo clock (run %d)" % (run + 1)
        _check(
            m.chimes.get(CuckooClock.Chime.CUCKOO, 0) >= 1,
            "%s: the cuckoo comes out and calls (%s)" % [title, str(m.chimes)]
        )
        _check(
            m.chimes.get(CuckooClock.Chime.PINE_CONES, 0) >= 1 and m.cones_dropped >= 2,
            "%s: the pine cones drop (%d)" % [title, m.cones_dropped]
        )
        _check(m.lanes_seen, "%s: the lanes of the pine cones show first" % title)
        _check(
            m.chimes.get(CuckooClock.Chime.DANCERS, 0) >= 1,
            "%s: the dancers come out (%s)" % [title, str(m.chimes)]
        )
        _check(
            m.chimes.get(CuckooClock.Chime.CUCKOO, 0) >= 2,
            "%s: the hour hand goes once around the clock (%s)" % [title, str(m.chimes)]
        )
        _check(m.ticklish_hits >= 1, "%s: the hits count double while the cuckoo is out" % title)
        _check(
            m.looks_seen.has(Rocket.Look.NOTE) and m.looks_seen.has(Rocket.Look.PINE_CONE),
            "%s: the notes and the pine cones fly (%s)" % [title, str(m.looks_seen.keys())]
        )
        _check(m.clock_lost_energy, "%s: the players hit the clock" % title)
        _check(
            m.messages.has("You did it!"),
            (
                "%s: the players chase it away (%s, min. health %d)"
                % [title, str(m.messages), m.min_health]
            )
        )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
