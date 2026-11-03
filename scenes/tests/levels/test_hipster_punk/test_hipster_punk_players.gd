extends ScriptedHeads

## Show the e-scooter hipster and the punk. First the player waits in
## the corner, so that the hipster drifts, throws the coffee beans and swoops,
## and the punk cruises, sprays the paint and flies his loop-the-loops. Then
## the player chases them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(12.0)
    await chase(0, func(): return below_nearest_enemy(0, 930.0), 60.0)
