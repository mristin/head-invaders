extends ScriptedHeads

## Show the great dragon: it breathes the sweeping streams of fire, rains
## the fireballs and swoops across. Two players chase it away, and step aside
## when they see it take a deep breath, like the children would, until
## the last fireballs of the breath have passed.

## How long the players stay aside after the breath, in seconds.
const _STAY_ASIDE: float = 1.6

var _aside_left: float = 0.0


func _process(delta: float) -> void:
    _aside_left = maxf(0.0, _aside_left - delta)


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(3.0)
    chase(0, func(): return _below_dragon(-40.0), 90.0)
    await chase(1, func(): return _below_dragon(40.0), 90.0)


func _below_dragon(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var dragon := node as GreatDragon
        if dragon != null and dragon.is_alive() and dragon.has_arrived():
            if dragon._action in [GreatDragon.Action.INHALE, GreatDragon.Action.BREATHE]:
                _aside_left = _STAY_ASIDE

            var x := dragon.global_position.x + offset
            if _aside_left > 0.0:
                # NOTE: Step aside, away from the middle of the screen if
                # the dragon is near the edge.
                var away := signf(offset)
                if dragon.global_position.x + away * 600.0 > 1820.0:
                    away = -1.0
                elif dragon.global_position.x + away * 600.0 < 100.0:
                    away = 1.0
                x = dragon.global_position.x + away * 600.0 + offset
            return Vector2(clampf(x, 100.0, 1820.0), 950.0)
    return null
