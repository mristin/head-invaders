extends ScriptedHeads

## Show the flyers of the lava world. First the player waits in the corner, so
## that the dragonling takes a deep breath and breathes its fireballs, and
## the jet dwarf zooms across dropping the coal. Then the player chases them.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(10.0)
    await chase(0, func(): return below_nearest_enemy(0, 900.0), 50.0)
