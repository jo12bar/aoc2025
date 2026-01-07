class_name ComboLock
extends Node2D

## Emitted whenever the dial passes zero, exactly once for _each_ time it passes zero.
signal passed_zero
## Emitted when done animating the dial.
signal dial_animation_complete

@export var dial: Node2D

## Time required to animate each step of the simulation, in seconds.
var animation_time := 0.0

var dial_value := 50:
	set(new_value):
		# Figure out how far we're moving
		var old_value := dial_value
		var amount := new_value - old_value

		# If we're not actually moving, skip all the below so we don't double-count zeroes
		if old_value == new_value % 100:
			return

		# Figure out how many times this rotation passes zero
		var times_passed_zero := 0
		if amount > 0.0:
			times_passed_zero = (
				floori(float(old_value + amount) / 100.0) - floori(float(old_value) / 100.0)
			)
		else:
			times_passed_zero = (
				floori(float(old_value - 1) / 100.0) - floori(float(old_value - 1 + amount) / 100.0)
			)

		# Actually update the dial value
		dial_value = (dial_value + amount + 100) % 100

		# Debugging output
		# print(
		# 	(
		# 		"moved dial from %d to %d (raw=%d, amount=%d), passing zero %d times"
		# 		% [old_value, dial_value, new_value, amount, times_passed_zero]
		# 	)
		# )

		# Rotate the visible dial using the new_value, since Godot will
		# just fix this for us anyways.
		var tween = create_tween()
		tween.tween_property(dial, "rotation", TAU / 100.0 * new_value, animation_time).from(
			TAU / 100.0 * dial_value
		)
		await tween.finished
		dial_animation_complete.emit()

		# Emit the "passed zero" signal to let the solver know
		for i in range(times_passed_zero):
			passed_zero.emit()
