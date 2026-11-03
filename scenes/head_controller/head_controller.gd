class_name HeadController

extends Node2D

## Define an abstract source of heads such that we can have several webcams.
##
## All positions are given in viewport coordinates.

@warning_ignore("unused_signal")
signal head_appeared(id: int, position: Vector2)

@warning_ignore("unused_signal")
signal head_moved(id: int, position: Vector2)

@warning_ignore("unused_signal")
signal head_lost(id: int)
