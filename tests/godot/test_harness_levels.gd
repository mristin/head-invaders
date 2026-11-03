extends SceneTree
## Play every test case of the harness with its scripted players, headless, and
## check that each shows the behavior it is meant to show.

var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
    print(("PASS " if condition else "FAIL ") + message)
    if not condition:
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


class Metrics:
    var max_ships := 0
    var min_health := 1000
    var level_changes := 0
    var messages := []
    var boosts_seen := {}
    var min_enemies := 1000
    var dummy_energy_lost := 0
    var darts_wrapped := false
    var colors_by_key := {}
    var color_kept := true
    var health_kept := true
    var left_health := {}
    var hues_distinct := true
    var kinds_seen := {}
    var queen_darts := 0
    var darts_followed_queen := false
    var little_slimes := {}
    var chests_opened := {}
    var mothership_chests := 0
    var mothership_zippers := 0
    var zippers_followed_mothership := false
    var ground_wrapped := false
    var ground_passed_below := false
    var oak_mushrooms := 0
    var mushrooms_followed_oak := false
    var looks_seen := {}
    var shark_dived := false
    var octopus_darted := false
    var clam_bounced := 0
    var serpent_dives := 0
    var serpent_submerged_seen := false
    var falling_seen := false
    var dwarf_zoomed := false
    var dragon_breaths := 0
    var dragon_swoops := 0


func _play_case(title: String, level_path: String, players_path: String, seconds: float) -> Metrics:
    print("--- ", title)
    var players: HeadController = (load(players_path) as GDScript).new()
    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_head_controllers([players])
    game.level_scene_paths = [level_path]
    root.add_child(game)

    var m := Metrics.new()
    var level_id := 0
    var last_y := {}
    var present := {}
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

        # NOTE: We compare the instance IDs, since a freed level equals null.
        var current := game.get_node("Screen").get_child(0)
        if level_id != 0 and current.get_instance_id() != level_id:
            m.level_changes += 1
        level_id = current.get_instance_id()

        var fleet: Fleet = game._fleet
        m.max_ships = maxi(m.max_ships, fleet._spaceships.size())

        var hues: Array[float] = []
        for key in fleet._spaceships:
            var ship: Spaceship = fleet._spaceships[key]
            hues.append(ship.color.h)
            m.min_health = mini(m.min_health, ship.health)
            for kind in ship._boosts:
                m.boosts_seen[kind] = true
            if m.colors_by_key.has(key) and m.colors_by_key[key] != ship.color:
                m.color_kept = false
            m.colors_by_key[key] = ship.color
            if not present.has(key) and m.left_health.has(key):
                if m.left_health[key] != ship.health:
                    print(
                        (
                            "  returned with health %d, left with %d"
                            % [ship.health, m.left_health[key]]
                        )
                    )
                    m.health_kept = false
            present[key] = ship.health

        for key in present.keys():
            if not fleet._spaceships.has(key):
                m.left_health[key] = present[key]
                present.erase(key)

        hues.sort()
        for i in range(hues.size() - 1):
            if hues[i + 1] - hues[i] < 0.02:
                m.hues_distinct = false

        var enemies := 0
        for child in current.get_node("Enemies").get_children():
            if child is Enemy and not child.is_queued_for_deletion():
                enemies += 1
                m.dummy_energy_lost = (
                    maxi(m.dummy_energy_lost, child.max_energy - child.energy)
                    if child.max_energy >= 1000
                    else m.dummy_energy_lost
                )
                if child.has_arrived():
                    m.kinds_seen[child.get_script().get_global_name()] = true
                if child is Slime and not child.splits:
                    m.little_slimes[child.get_instance_id()] = true
                if child is GroundEnemy and child.has_arrived() and child.is_alive():
                    var gy: float = child.global_position.y
                    if last_y.has(child) and gy < last_y[child] - 500.0:
                        m.ground_wrapped = true
                    if gy > 950.0:
                        m.ground_passed_below = true
                    last_y[child] = gy
                if child is Shark and child.is_diving():
                    m.shark_dived = true
                if child is Octopus and child._dart_left > 0.0:
                    m.octopus_darted = true
                if child is Clam:
                    m.clam_bounced = maxi(m.clam_bounced, child.bounced_hits)
                if child is JetDwarf and child._zooming:
                    m.dwarf_zoomed = true
                if child is GreatDragon:
                    m.dragon_breaths = maxi(m.dragon_breaths, child.breaths())
                    m.dragon_swoops = maxi(m.dragon_swoops, child.swoops())
                if child is SeaSerpent:
                    m.serpent_dives = maxi(m.serpent_dives, child.dives())
                    if child.is_submerged():
                        m.serpent_submerged_seen = true
                if child is OldOak:
                    m.oak_mushrooms = maxi(m.oak_mushrooms, child.minions().size())
                    if child.is_fleeing() and child.minions().is_empty():
                        m.mushrooms_followed_oak = true
                if child is Mothership:
                    m.mothership_chests = maxi(m.mothership_chests, child.chests_dropped())
                    m.mothership_zippers = maxi(m.mothership_zippers, child.minions().size())
                    if child.is_fleeing() and child.minions().is_empty():
                        m.zippers_followed_mothership = true
                if child is Queen:
                    m.queen_darts = maxi(m.queen_darts, child.minions().size())
                    if child.is_fleeing() and child.minions().is_empty():
                        m.darts_followed_queen = true
                if child is Dart and child.has_arrived():
                    var y: float = child.global_position.y
                    if last_y.has(child) and y < last_y[child] - 500.0:
                        m.darts_wrapped = true
                    last_y[child] = y
        m.min_enemies = mini(m.min_enemies, enemies)

        for child in current.get_node("Projectiles").get_children():
            if child is Rocket:
                m.looks_seen[child.look] = true
                if child.fall_acceleration > 0.0:
                    m.falling_seen = true
            if child is Chest and child.is_open():
                m.chests_opened[child.get_instance_id()] = true

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _run() -> void:
    var tests := "res://scenes/tests/levels"
    var m: Metrics

    m = await _play_case(
        "players",
        tests + "/test_players/test_players.tscn",
        tests + "/test_players/test_players_players.gd",
        16.0
    )
    _check(m.max_ships == 15, "players: a crowd of 15 (got %d)" % m.max_ships)
    _check(m.hues_distinct, "players: the colors are distinct")
    _check(m.color_kept, "players: the returning player keeps the color")
    _check(
        m.level_changes == 0 and m.messages.is_empty(),
        "players: the level without enemies never ends"
    )

    m = await _play_case(
        "saucer",
        tests + "/test_saucer/test_saucer.tscn",
        tests + "/test_saucer/test_saucer_players.gd",
        30.0
    )
    _check(
        m.messages.has("You did it!") and m.level_changes >= 1,
        "saucer: it flees, the game is finished, and starts over (%s)" % str(m.messages)
    )

    m = await _play_case(
        "dart", tests + "/test_dart/test_dart.tscn", tests + "/test_dart/test_dart_players.gd", 14.0
    )
    _check(m.darts_wrapped, "dart: a dart comes around from the top")

    m = await _play_case(
        "new aliens",
        tests + "/test_new_aliens/test_new_aliens.tscn",
        tests + "/test_new_aliens/test_new_aliens_players.gd",
        45.0
    )
    _check(
        m.kinds_seen.has("Jelly") and m.kinds_seen.has("Orbiter") and m.kinds_seen.has("Zipper"),
        "new aliens: the jelly, the orbiter and the zipper arrive (%s)" % str(m.kinds_seen.keys())
    )
    _check(
        m.min_enemies < 3,
        "new aliens: the player chases some away (%d left at least)" % m.min_enemies
    )

    m = await _play_case(
        "queen",
        tests + "/test_queen/test_queen.tscn",
        tests + "/test_queen/test_queen_players.gd",
        60.0
    )
    _check(m.queen_darts > 0, "queen: she calls in her darts (%d at most)" % m.queen_darts)
    _check(m.darts_followed_queen, "queen: her darts follow her home")
    _check(
        m.messages.has("You did it!"), "queen: the players chase her away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "slime and puffer",
        tests + "/test_slime_puffer/test_slime_puffer.tscn",
        tests + "/test_slime_puffer/test_slime_puffer_players.gd",
        45.0
    )
    _check(m.kinds_seen.has("Puffer"), "slime and puffer: the puffer arrives")
    _check(
        m.little_slimes.size() >= 2,
        "slime and puffer: the slime splits in two (%d)" % m.little_slimes.size()
    )
    _check(
        m.messages.has("You did it!"),
        "slime and puffer: the player chases them all away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "chests",
        tests + "/test_chests/test_chests.tscn",
        tests + "/test_chests/test_chests_players.gd",
        25.0
    )
    _check(
        m.chests_opened.size() >= 2,
        "chests: the player shoots the chests open (%d)" % m.chests_opened.size()
    )
    _check(
        m.boosts_seen.has(Pickup.Kind.BUBBLE),
        "chests: the player catches the bubble (%s)" % str(m.boosts_seen.keys())
    )
    _check(m.min_health == 10, "chests: the chests never hurt (min health %d)" % m.min_health)

    m = await _play_case(
        "mothership",
        tests + "/test_mothership/test_mothership.tscn",
        tests + "/test_mothership/test_mothership_players.gd",
        80.0
    )
    _check(
        m.mothership_zippers > 0,
        "mothership: it calls in the zippers (%d at most)" % m.mothership_zippers
    )
    _check(
        m.mothership_chests == 2, "mothership: it drops its two chests (%d)" % m.mothership_chests
    )
    _check(m.zippers_followed_mothership, "mothership: its zippers follow it home")
    _check(
        m.messages.has("You did it!"),
        "mothership: the players chase it away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "forest critters",
        tests + "/test_forest_critters/test_forest_critters.tscn",
        tests + "/test_forest_critters/test_forest_critters_players.gd",
        70.0
    )
    _check(m.ground_wrapped, "forest critters: they come around from the top")
    _check(m.ground_passed_below, "forest critters: they slide down to the bottom")
    _check(
        m.looks_seen.has(Rocket.Look.SPORE) and m.looks_seen.has(Rocket.Look.ACORN),
        "forest critters: the spores and the acorns fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "forest critters: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "old oak",
        tests + "/test_old_oak/test_old_oak.tscn",
        tests + "/test_old_oak/test_old_oak_players.gd",
        80.0
    )
    _check(m.oak_mushrooms > 0, "old oak: it sprouts the mushrooms (%d at most)" % m.oak_mushrooms)
    _check(m.mushrooms_followed_oak, "old oak: its mushrooms follow it home")
    _check(
        m.messages.has("You did it!"), "old oak: the players chase it away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "sea critters",
        tests + "/test_sea_critters/test_sea_critters.tscn",
        tests + "/test_sea_critters/test_sea_critters_players.gd",
        70.0
    )
    _check(m.shark_dived, "sea critters: the shark dives at the player")
    _check(m.octopus_darted, "sea critters: the octopus darts away when hit")
    _check(
        m.looks_seen.has(Rocket.Look.ZAP) and m.looks_seen.has(Rocket.Look.INK),
        "sea critters: the sparks and the ink fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "sea critters: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "alligator and clam",
        tests + "/test_gator_clam/test_gator_clam.tscn",
        tests + "/test_gator_clam/test_gator_clam_players.gd",
        55.0
    )
    _check(m.clam_bounced > 0, "alligator and clam: the bullets bounce off (%d)" % m.clam_bounced)
    _check(
        m.looks_seen.has(Rocket.Look.BUBBLE) and m.looks_seen.has(Rocket.Look.PEARL),
        "alligator and clam: the bubbles and the pearls fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "alligator and clam: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "sea serpent",
        tests + "/test_sea_serpent/test_sea_serpent.tscn",
        tests + "/test_sea_serpent/test_sea_serpent_players.gd",
        90.0
    )
    _check(m.serpent_submerged_seen, "sea serpent: it dives under water")
    _check(m.serpent_dives >= 2, "sea serpent: it dives again and again (%d)" % m.serpent_dives)
    _check(
        m.messages.has("You did it!"),
        "sea serpent: the players chase it away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "lava flyers",
        tests + "/test_lava_flyers/test_lava_flyers.tscn",
        tests + "/test_lava_flyers/test_lava_flyers_players.gd",
        60.0
    )
    _check(m.dwarf_zoomed, "lava flyers: the jet dwarf zooms across")
    _check(
        m.looks_seen.has(Rocket.Look.FIREBALL) and m.looks_seen.has(Rocket.Look.COAL),
        "lava flyers: the fireballs and the coal fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "lava flyers: the player chases them away (%s)" % str(m.messages)
    )

    var bursts_before := Rocket.bursts
    m = await _play_case(
        "lava ground",
        tests + "/test_lava_ground/test_lava_ground.tscn",
        tests + "/test_lava_ground/test_lava_ground_players.gd",
        75.0
    )
    _check(
        Rocket.bursts > bursts_before,
        "lava ground: the golem's boulder bursts (%d)" % (Rocket.bursts - bursts_before)
    )
    _check(m.falling_seen, "lava ground: the volcano's lava blobs fall in arcs")
    _check(
        m.messages.has("You did it!"),
        "lava ground: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "great dragon",
        tests + "/test_great_dragon/test_great_dragon.tscn",
        tests + "/test_great_dragon/test_great_dragon_players.gd",
        90.0
    )
    _check(m.dragon_breaths >= 2, "great dragon: it breathes fire (%d)" % m.dragon_breaths)
    _check(m.dragon_swoops >= 1, "great dragon: it swoops (%d)" % m.dragon_swoops)
    _check(m.falling_seen, "great dragon: its fireballs rain down")
    _check(
        m.messages.has("You did it!"),
        "great dragon: the players chase it away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "collision",
        tests + "/test_collision/test_collision.tscn",
        tests + "/test_collision/test_collision_players.gd",
        25.0
    )
    _check(m.min_health == 0, "collision: the spaceship gets dizzy (min health %d)" % m.min_health)
    _check(
        m.dummy_energy_lost > 0,
        "collision: the dummy loses energy in the clash (%d)" % m.dummy_energy_lost
    )
    _check(
        m.messages.has("Let's try again!") and m.level_changes >= 1,
        (
            "collision: try again, and the level restarts (%s, %d changes)"
            % [str(m.messages), m.level_changes]
        )
    )

    m = await _play_case(
        "enemy rockets",
        tests + "/test_enemy_rockets/test_enemy_rockets.tscn",
        tests + "/test_enemy_rockets/test_enemy_rockets_players.gd",
        10.0
    )
    _check(m.min_health < 10, "enemy rockets: the player is hit (min health %d)" % m.min_health)

    m = await _play_case(
        "pickups",
        tests + "/test_pickups/test_pickups.tscn",
        tests + "/test_pickups/test_pickups_players.gd",
        25.0
    )
    _check(
        m.boosts_seen.size() >= 2,
        "pickups: the players collect the weapons (%s)" % str(m.boosts_seen.keys())
    )

    m = await _play_case(
        "leave and return",
        tests + "/test_leave_and_return/test_leave_and_return.tscn",
        tests + "/test_leave_and_return/test_leave_and_return_players.gd",
        14.0
    )
    _check(
        m.min_health < 10,
        "leave and return: the player takes damage (min health %d)" % m.min_health
    )
    _check(m.left_health.has("0:0"), "leave and return: the player leaves")
    _check(m.health_kept, "leave and return: the returning player keeps the damage")
    _check(m.color_kept, "leave and return: the returning player keeps the color")

    m = await _play_case(
        "crowd",
        "res://scenes/levels/first/first.tscn",
        tests + "/test_crowd/test_crowd_players.gd",
        30.0
    )
    _check(m.max_ships == 10, "crowd: ten players (got %d)" % m.max_ships)
    _check(
        m.min_enemies < 10,
        "crowd: the crowd chases the aliens away (%d left at least)" % m.min_enemies
    )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
