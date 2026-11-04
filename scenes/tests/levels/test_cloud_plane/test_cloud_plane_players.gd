extends ScriptedHeads

## Show the rain cloud and the paper plane. First the player keeps away from
## the rain cloud, which follows it, so that the cloud rains a few showers, and
## the paper plane loops and throws its darts, which come back to it. Then
## the player chases them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await chase(0, _keep_away_from_cloud, 16.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 60.0)


func _keep_away_from_cloud() -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var cloud := node as RainCloud
        if cloud != null and cloud.is_alive() and cloud.has_arrived():
            var x := position_of(0).x
            # NOTE: We keep away from the cloud, which follows us, so that it
            # rains next to us.
            if absf(cloud.global_position.x - x) < 240.0:
                var side := 1.0 if cloud.global_position.x < 960.0 else -1.0
                x = cloud.global_position.x + side * 550.0
            return Vector2(x, 950.0)
    return null
