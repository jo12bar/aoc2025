extends Panel

## Emitted when the "Run Part 1" button is pressed, along with the current
## input file's filepath.
signal part_one_button_pressed(input_filepath: String)
## Emitted when the "Run Part 2" button is pressed, along with the current
## input file's filepath.
signal part_two_button_pressed(input_filepath: String)

const BUNDLED_INPUT_DIR := "res://problems"
## Max length string we can show as an input file in the dialog
const MAX_DISPLAYABLE_FILE_LENGTH := 30

@export var challenge_number := 0
@export_file("*.txt") var input_filepath: String

@export_group("Internal nodes")
@export var title_label: Label
@export var input_file_label: Label
@export var select_input_file_button: Button
@export var run_part_one_button: Button
@export var run_part_two_button: Button
@export var file_dialog: FileDialog

var _input_file_label_template := "Current input file:\n%s"


func _ready() -> void:
	# Set dialog title correctly
	var formatted_challenge_number := "%02d" % challenge_number
	title_label.text = "Day " + formatted_challenge_number

	if not input_filepath:
		# No input filepath set, so try to find a challenge input matching the
		# challenge_number in the default resource directory.
		var default_file := "day" + formatted_challenge_number + ".txt"
		var default_filepath := BUNDLED_INPUT_DIR + "/" + default_file
		if FileAccess.file_exists(default_filepath):
			# The default input exists, so set the buttons and labels
			input_filepath = default_filepath
			input_file_label.text = _input_file_label_template % input_filepath
			# Focus the first run button
			run_part_one_button.grab_focus.call_deferred()
		else:
			# Couldn't find default input file, so disable run buttons and
			# show a message.
			input_file_label.text = _input_file_label_template % "[NO FILE SELECTED]"
			run_part_one_button.disabled = true
			run_part_two_button.disabled = true
			# Focus the file select button
			select_input_file_button.grab_focus.call_deferred()


func _on_run_part_one_button_pressed() -> void:
	part_one_button_pressed.emit(input_filepath)


func _on_run_part_two_button_pressed() -> void:
	part_two_button_pressed.emit(input_filepath)


func _on_select_input_file_button_pressed() -> void:
	file_dialog.popup()


func _on_file_dialog_file_selected(path: String) -> void:
	input_filepath = path
	input_file_label.text = _input_file_label_template % path
	# Focus the first run button
	run_part_one_button.grab_focus.call_deferred()
