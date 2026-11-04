extends ScriptedHeads

## Show the fleet without any enemies: the colors, the overlapping spaceships,
## a player leaving and returning with their color, and a crowd.


func _play() -> void:
    appear(0, Vector2(560, 700))
    await wait(1.0)
    appear(1, Vector2(960, 700))
    await wait(1.0)
    appear(2, Vector2(1360, 700))
    await wait(1.5)

    # NOTE (mristin):
    # The spaceships may overlap.
    glide(0, Vector2(930, 560), 1.5)
    glide(2, Vector2(990, 560), 1.5)
    await glide(1, Vector2(960, 600), 1.5)
    await wait(1.5)

    # NOTE (mristin):
    # The second player leaves and comes back with the same color.
    lose(1)
    await wait(1.5)
    appear(1, Vector2(960, 900))
    await wait(1.5)

    # NOTE (mristin):
    # A crowd comes in, each with a distinct color.
    for id in range(3, 15):
        appear(id, Vector2(160 + (id - 3) * 145, 300 + (id % 2) * 160))
        await wait(0.25)
    await wait(2.5)
