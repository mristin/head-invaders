extends ScriptedHeads

## Show the sand worm and the mirage fox. First the player keeps away from
## the worm, so that the worm burrows, creeps over and pops up with its ring of
## sand balls a few times, and the fox casts its mirage. Then the player
## chases them away: the bullets can not reach the burrowed worm, and fly
## through the mirages.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await chase(0, _away_from_worm, 16.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 70.0)


func _away_from_worm() -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var worm := node as SandWorm
        if worm != null and worm.is_alive() and worm.has_arrived():
            return Vector2(150.0 if worm.global_position.x > 960.0 else 1770.0, 950.0)
    return null
