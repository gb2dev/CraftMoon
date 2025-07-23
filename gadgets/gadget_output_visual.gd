class_name GadgetOutputVisual
extends Node2D


@onready var line := $Line2D as Line2D
@onready var path := $Path2D as Path2D
@onready var curve := path.curve

var point_a: Vector2:
	set(value):
		point_a = value
		update_line()
var point_b: Vector2:
	set(value):
		point_b = value
		update_line()


func clear_points() -> void:
	curve.clear_points()
	line.clear_points()

func update_line() -> void:
	curve.clear_points()
	curve.add_point(point_a)
	var in_out := Vector2(absf(point_b.x - point_a.x) / 2, 0)
	curve.add_point(point_a + Vector2(10, 0), Vector2.ZERO, in_out)
	curve.add_point(point_b - Vector2(10, 0), -in_out, Vector2.ZERO)
	curve.add_point(point_b)
	line.clear_points()
	for point: Vector2 in curve.get_baked_points():
		line.add_point(point)
