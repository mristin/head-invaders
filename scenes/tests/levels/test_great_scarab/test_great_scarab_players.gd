extends ScriptedHeads

## Show the great scarab: it hides behind its sun ball, throws the sand and
## rolls the sun ball down the screen. First one player flies right below it,
## so that the bullets bounce off the sun ball. Then a second player joins,
## and the two come from both sides, so that the sun ball can shield only one
## of them, and chase the scarab away.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await chase(0, func(): return _below_scarab(0.0), 12.0)
    appear(1, Vector2(1400, 950))
    chase(0, func(): return _below_scarab(-110.0), 100.0)
    await chase(1, func(): return _below_scarab(110.0), 100.0)


func _below_scarab(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var scarab := node as GreatScarab
        if scarab != null and scarab.is_alive() and scarab.has_arrived():
            var x := scarab.global_position.x + offset
            # NOTE (mristin):
            # Step aside from the rolling sun ball, like a careful player.
            var ball := scarab.sun_ball()
            if ball != null and ball.is_rolling() and absf(x - ball.global_position.x) < 260.0:
                x = ball.global_position.x + (260.0 if offset >= 0.0 else -260.0)
            return Vector2(x, 940.0)
    return null
