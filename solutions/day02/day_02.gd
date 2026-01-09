extends ColorRect

@export var challenge_greeter_scene: PackedScene
@export var result_label: Label
@export var id_item_list: ItemList

var challenge_greeter: ChallengeGreeter
var input_ranges: Array[PackedInt64Array]


func _ready() -> void:
	challenge_greeter = challenge_greeter_scene.instantiate() as ChallengeGreeter
	challenge_greeter.challenge_number = 2
	challenge_greeter.set_anchors_preset(LayoutPreset.PRESET_CENTER, true)
	challenge_greeter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	challenge_greeter.grow_vertical = Control.GROW_DIRECTION_BOTH
	challenge_greeter.connect(
		"part_one_button_pressed", _on_challenge_greeter_part_one_button_pressed
	)
	challenge_greeter.connect(
		"part_two_button_pressed", _on_challenge_greeter_part_two_button_pressed
	)
	add_child(challenge_greeter)


func _read_challenge_input(input_filepath: String) -> void:
	var input := FileAccess.get_file_as_string(input_filepath)
	var input_array: Array[String]
	input_array.assign(Array(input.split(",")))
	input_ranges.assign(
		input_array.map(
			func(r: String) -> PackedInt64Array:
				var split_range: Array[int]
				split_range.assign(Array(r.split("-")).map(func(n: String) -> int: return int(n)))
				return PackedInt64Array(split_range),
		)
	)


func _count_candidate_ids() -> int:
	var sum := 0
	for input_range in input_ranges:
		sum += input_range[1] - input_range[0] + 1
	return sum


## Finds invalid IDs in the [member input_range] array, and returns a
## dictionary that maps from input range to invalid IDs within that input[br]
## range.
##
## [b]Methodology:[/b][br]
##
## This is based on some math I worked out on paper, and seems to fit some
## other approaches people have taken. We try to generate a number
## [code]n[/code] where
##
## [codeblock lang=text]
## n = kkkkkk...kk
## [/codeblock]
##
## [code]k[/code] is a block of [code]d[/code] repeated digits, and is repeated
## [code]r[/code] times. For part 1, we're just looking for at least two
## repetitions, so [code]r = 2[/code].[br]
##
## Consider the ID [code]101101101[/code]. This has a repeated block of
## [code]k = 101[/code] with [code]d = 3[/code] digits. So, we can generate the
## invalid ID like so:
##
## [codeblock lang=text]
## 101101101 = 101 * 1000000 + 101 * 1000 + 101
##           = 101 * (1000000 + 1000 + 1)
##           = 101 * (10^6 + 10^3 + 10^0)
##           = 101 * (10^(3 * 2) + 10^(3 * 1) + 10^(3 * 0))
##           = 101 * (10^(d * (r - 1)) + 10^(d * (r - 2)) + 10^(d * (r - 3))), where d = 3, r = 3
## [/codeblock]
##
## This is just a geometric series. So we can simplify it to:
##
## [codeblock lang=text]
## n = k * (10^(d * r) - 1) / (10^d - 1)
##   = k * f(d, r),
##         where f(d, r) = (10^(d * r) - 1) / (10^d - 1)
## [/codeblock]
##
## We have two constraints on the value of [code]k[/code]. First, since
## [code]k[/code] always has [code]d[/code] digits, it will always fall in the
## range
##
## [codeblock lang=text]
## 10^(d - 1) <= k <= 10^d - 1
## [/codeblock]
##
## The second constraint is that, for the lower range [code]l[/code] and the
## upper range [code]u[/code], [code]l <= n <= u[/code]. But, since
## [code]n = k * f(d, r)[/code] (see above),
##
## [codeblock lang=text]
## l           <= k * f(d, r) <= u
## l / f(d, r) <= k           <= u / f(d, r)
## [/codeblock]
##
## So: For all [code]d * r <= #digits(u)[/code], we compute [code]f(d, r)[/code].
## For each value of [code]f(d, r)[/code], we can then find the range for
## [code]k[/code] using our two constraints above. Each value of [code]k[/code]
## will give us a new candidate invalid ID [code]n = k * f(d, r)[/code] that
## fits within the lower ([code]l[/code]) and upper ([code]u[/code]) bounds
## given in the challenge input.[br]
##
## Note that we'll have to deduplicate the list of candidates ("111111",
## "111"x2, "11"x3, "1"x6, etc.). So we collect all the candidates in a list
## and then filter the unique entries.
func _find_invalid_ids(is_part_one: bool) -> Dictionary[PackedInt64Array, PackedInt64Array]:
	var invalid_id_map: Dictionary[PackedInt64Array, PackedInt64Array]

	for input_range in input_ranges:
		invalid_id_map[input_range] = _invalid_ids_in_range(
			input_range[0], input_range[1], is_part_one
		)

	return invalid_id_map


func _invalid_ids_in_range(lower: int, upper: int, is_part_one: bool) -> PackedInt64Array:
	var digits_in_upper := _num_digits(upper)
	var candidates: Dictionary[int, int] = {}  ## hashmap from invalid ID to count of times seen

	# Loop over all combos of `d * r` where `d` is the number of digits in a repeated block and
	# `r` is the number of repetitions to look for.
	# Note that, for part one, we only look for 2 repetitions. For part two, we look for as many
	# as can fit in the ID.
	for d in range(1, digits_in_upper + 1, 1):
		@warning_ignore("integer_division")
		var max_number_repetitions := 2 if is_part_one else digits_in_upper / d
		for r in range(2, max_number_repetitions + 1, 1):
			# A repeated ID `n` will look like `n = kkkk...kk` where `k` is a block of `d` digits
			# that's repeated `r` times.
			# Our search needs the values 10^d and 10^(d*r) a few times, so precalc those values:
			var ten_pow_d := int(pow(10.0, float(d)))
			var ten_pow_dr := int(pow(10.0, float(d * r)))

			# Find f(d, r) = (10^(d * r) - 1) / (10^d - 1)
			@warning_ignore("integer_division")
			var f := (ten_pow_dr - 1) / (ten_pow_d - 1)

			# If f(d, r) is somehow larger than our upper bound, just skip this look, since we'd
			# then require `k` to be fractional (which doesn't work).
			if f > upper:
				continue

			# Since `k` has `d` digits, we know that `10^(d - 1) <= k <= 10^d - 1`.
			var k_lower_bound_1 := int(pow(10.0, float(d - 1)))
			var k_upper_bound_1 := ten_pow_d - 1

			# Our second constraint is that lower / f(d, r) <= k <= upper / f(d, r).
			@warning_ignore("integer_division")
			var k_lower_bound_2 := lower / f
			@warning_ignore("integer_division")
			var k_upper_bound_2 := upper / f

			# Find the actual smallest range for k
			var k_min := maxi(k_lower_bound_1, k_lower_bound_2)
			var k_max := mini(k_upper_bound_1, k_upper_bound_2)

			# If the min and max bounds are out of order or are equal, no valid values for `k`
			# exist, so skip adding candidate IDs
			if k_min > k_max:
				continue

			# Loop over all the candidate k's
			for k in range(k_min, k_max + 1, 1):
				# The final invalid ID is n = k * f(d, r).
				var n := k * f
				if n >= lower && n <= upper:
					if n in candidates:
						candidates[n] += 1
					else:
						candidates[n] = 1

	return PackedInt64Array(candidates.keys())


## Get the number of digits in an integer.
func _num_digits(n: int) -> int:
	return floori(log(float(n)) / log(10.0)) + 1


func _run_challenge(input_filepath: String, is_part_one: bool) -> void:
	result_label.text = "Finding invalid IDs..."
	_read_challenge_input(input_filepath)
	result_label.text = (
		"Finding invalid IDs from %d ranges (%d candidate IDs)..."
		% [input_ranges.size(), _count_candidate_ids()]
	)

	var invalid_id_count := 0
	var invalid_id_sum := 0

	var invalid_id_map := _find_invalid_ids(is_part_one)

	for id_range in invalid_id_map:
		var invalid_ids_in_range := Array(invalid_id_map[id_range])

		invalid_id_count += invalid_ids_in_range.size()
		invalid_id_sum += invalid_ids_in_range.reduce(func(a: int, n: int) -> int: return a + n, 0)

		var lower := id_range[0]
		var upper := id_range[1]
		id_item_list.add_item("%d-%d" % [lower, upper])

		id_item_list.add_item(",".join(PackedStringArray(invalid_ids_in_range)))

	result_label.text = (
		"%d invalid IDs found, which sum up to %d (copied to clipboard)"
		% [invalid_id_count, invalid_id_sum]
	)

	DisplayServer.clipboard_set("%d" % invalid_id_sum)


func _on_challenge_greeter_part_one_button_pressed(input_filepath: String) -> void:
	challenge_greeter.queue_free()
	_run_challenge(input_filepath, true)


func _on_challenge_greeter_part_two_button_pressed(input_filepath: String) -> void:
	challenge_greeter.queue_free()
	_run_challenge(input_filepath, false)
