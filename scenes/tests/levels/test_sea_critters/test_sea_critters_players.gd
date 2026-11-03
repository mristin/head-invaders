extends ScriptedHeads

## Show the shark, the jellyfish and the octopus. First the player waits in
## the corner, out of the way, so that they all show what they do, and
## the shark dives at the player as it swims by. Then the player chases them
## away; the octopus darts off when hit.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(12.0)
    await chase(0, func(): return below_nearest_enemy(0, 900.0), 50.0)
