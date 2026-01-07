extends Node

## Total run time of the solution in seconds (used for pretty animations).
const TOTAL_RUN_TIME := 5.0

@export var challenge_greeter: Node
@export var combo_lock: ComboLock
@export var running_label: Label
@export var stats_label: Label

var running_part_1 := false
var running_part_2 := false
var part_1_step_queued := false
var part_2_step_queued := false

var input: PackedStringArray = []
var input_line := 0

var times_stopped_on_zero := 0
var times_passed_zero := 0


func _process(_delta: float) -> void:
	if running_part_1 or running_part_2:
		_update_stats_label()
	if running_part_1 and part_1_step_queued:
		part_1_step_queued = false
		_step_part_1()
	if running_part_2 and part_2_step_queued:
		part_2_step_queued = false
		_step_part_2()


func _step_dial_sim() -> void:
	# Parse input to figure out how far to move
	var dir_str := input[input_line].substr(0, 1)
	var amount := int(input[input_line].substr(1, -1))
	if dir_str == "L":
		amount = -amount

	# Animate the dial nicely and wait for it to finish
	combo_lock.dial_value += amount
	await combo_lock.dial_animation_complete

	if combo_lock.dial_value == 0:
		times_stopped_on_zero += 1

	input_line += 1


func _step_part_1() -> void:
	await _step_dial_sim()

	if input_line >= input.size():
		part_1_step_queued = false
		running_part_1 = false
		running_label.text = "Done part 1. Copied %d to clipboard." % times_stopped_on_zero
		DisplayServer.clipboard_set("%d" % times_stopped_on_zero)
	else:
		part_1_step_queued = true


func _step_part_2() -> void:
	await _step_dial_sim()

	if input_line >= input.size():
		part_2_step_queued = false
		running_part_2 = false
		await get_tree().create_timer(0.5).timeout
		running_label.text = "Done part 2. Copied %d to clipboard." % times_passed_zero
		DisplayServer.clipboard_set("%d" % times_passed_zero)
	else:
		part_2_step_queued = true


func _update_stats_label() -> void:
	stats_label.text = (
		"Times stopped on 0:\t%d\nTimes passed 0:\t%d\nCurrent position:\t%d\nCurrent instruction:\t%s"
		% [
			times_stopped_on_zero,
			times_passed_zero,
			(roundi(combo_lock.dial.rotation / TAU * 100.0) + 100) % 100,
			input[mini(input_line, input.size() - 1)] if not input.is_empty() else ""
		]
	)


func _on_challenge_greeter_part_one_button_pressed(input_filepath: String) -> void:
	challenge_greeter.queue_free()

	# Read input into an array.
	input = FileAccess.get_file_as_string(input_filepath).split("\n", false)
	input_line = 0
	combo_lock.animation_time = TOTAL_RUN_TIME / float(input.size())

	print("Running %s" % input_filepath)
	running_label.text = "Running part 1..."
	running_part_1 = true
	part_1_step_queued = true


func _on_challenge_greeter_part_two_button_pressed(input_filepath: String) -> void:
	challenge_greeter.queue_free()

	# Read input into an array.
	input = FileAccess.get_file_as_string(input_filepath).split("\n", false)
	input_line = 0
	combo_lock.animation_time = TOTAL_RUN_TIME / float(input.size())

	print("Running %s" % input_filepath)
	running_label.text = "Running part 2..."
	running_part_2 = true
	part_2_step_queued = true


func _on_combo_lock_passed_zero() -> void:
	times_passed_zero += 1
	_update_stats_label()
