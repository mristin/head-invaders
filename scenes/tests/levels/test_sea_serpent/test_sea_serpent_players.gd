extends ScriptedHeads

## Show the sea serpent: it winds through the upper part of the screen, sends
## the bubbles down its body, dives and surfaces elsewhere with a splash. Two
## players chase its head away.


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(3.0)
    chase(0, func(): return _below_serpent(-90.0), 90.0)
    await chase(1, func(): return _below_serpent(90.0), 90.0)


func _below_serpent(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var serpent := node as SeaSerpent
        if serpent != null and serpent.is_alive() and serpent.has_arrived():
            return Vector2(serpent.global_position.x + offset, 950.0)
    return null
