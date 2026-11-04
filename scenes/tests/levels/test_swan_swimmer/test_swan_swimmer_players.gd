extends ScriptedHeads

## Show the swan and the Limmat swimmer. First the player waits in the corner,
## so that the swan swims on the lake and splashes, and the swimmer floats on
## the Limmat and squirts. Then the player chases them away; the swan takes
## off when it has lost half of its energy.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(12.0)
    await chase(0, func(): return below_nearest_enemy(0, 930.0), 60.0)
