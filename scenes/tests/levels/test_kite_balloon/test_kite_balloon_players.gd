extends ScriptedHeads

## Show the kite and the hot-air balloon. First the player keeps away from
## the balloon, so that the kite swings and shakes out its fans of stars, and
## the balloon drifts over, drops its sandbags and hops up. Then the player
## chases them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await chase(0, _away_from_balloon, 16.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 60.0)


func _away_from_balloon() -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var balloon := node as HotAirBalloon
        if balloon != null and balloon.is_alive() and balloon.has_arrived():
            var x := position_of(0).x
            if absf(balloon.global_position.x - x) < 350.0:
                x = 150.0 if balloon.global_position.x > 960.0 else 1770.0
            return Vector2(x, 950.0)
    return null
