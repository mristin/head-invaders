extends ScriptedHeads

## Show the cuckoo clock. Two players first wait at the sides and watch the
## clock count down and chime. Then they chase it away from below, like
## careful children: they step aside when the lanes of the pine cones show,
## and keep moving to and fro while the cuckoo calls.

var _time: float = 0.0


func _process(delta: float) -> void:
    _time += delta


func _play() -> void:
    appear(0, Vector2(250, 950))
    appear(1, Vector2(1670, 950))
    await wait(8.0)
    chase(0, func(): return _below_clock(-1.0), 120.0)
    await chase(1, func(): return _below_clock(1.0), 120.0)


func _below_clock(side: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var clock := node as CuckooClock
        if clock == null or not clock.is_alive() or not clock.has_arrived():
            continue

        var x := clock.global_position.x + side * 60.0
        var lanes := clock.cone_lanes()
        if not lanes.is_empty():
            # NOTE: Step well aside from the lanes of the pine cones.
            x = clock.global_position.x + side * 340.0
        elif clock.is_cuckoo_out():
            # NOTE: Weave to and fro, so that the aimed notes miss.
            x += sin(_time * 4.0) * 160.0
        return Vector2(clampf(x, 100.0, 1820.0), 950.0)
    return null
