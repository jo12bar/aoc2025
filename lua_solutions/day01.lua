---Checks if a file exists.
---
---@param filename string The file to check.
---@return boolean exists True if the file exists, false if it doesn't.
local function file_exists(filename)
  local f = io.open(filename, "rb")
  if f then
    f:close()
  end
  return f ~= nil
end

CHALLENGE_INPUT = "day01.txt"
CHALLENGE_EXAMPLE_INPUT = "day01_example.txt"
CHALLENGE_EXAMPLE_SOLUTION_A = "3"
CHALLENGE_EXAMPLE_SOLUTION_B = "6"

assert(
  file_exists("problems/" .. CHALLENGE_EXAMPLE_INPUT),
  "Could not open day 1 example input (make sure you're in a folder with a "
    .. "`problems/` subfolder, and that the file `problems/"
    .. CHALLENGE_EXAMPLE_INPUT
    .. "` exists)"
)

assert(
  file_exists("problems/" .. CHALLENGE_INPUT),
  "Could not open day 1 input (make sure you're in a folder with a "
    .. "`problems/` subfolder, and that the file `problems/"
    .. CHALLENGE_INPUT
    .. "` exists)"
)

DIAL_START = 50
DIAL_MIN = 0
DIAL_MAX = 99

NUM_DIAL_POSITIONS = DIAL_MAX - DIAL_MIN + 1

local function part_a(input_filename)
  local dial = DIAL_START

  local zero_count = 0

  for line in io.lines(input_filename) do
    local dial_old = dial

    local direction = line:sub(1, 1)
    local amount = tonumber(line:sub(2, -1))

    if direction == "L" then
      dial = dial - amount
    elseif direction == "R" then
      dial = dial + amount
    else
      error("Unknown direction " .. direction .. "in challenge input")
    end

    while dial < DIAL_MIN do
      dial = dial + NUM_DIAL_POSITIONS
    end
    while dial > DIAL_MAX do
      dial = dial - NUM_DIAL_POSITIONS
    end

    io.write(string.format("%s:\t%d → %d", line, dial_old, dial))

    if dial == 0 then
      zero_count = zero_count + 1
      io.write("\t*")
    end

    io.write("\n")

    assert(
      dial >= DIAL_MIN,
      "dial is " .. dial .. ", but should never be less than " .. DIAL_MIN
    )
    assert(
      dial <= DIAL_MAX,
      "dial is " .. dial .. ", but should never be greater than " .. DIAL_MAX
    )
  end

  io.write(string.format("part a zero count: %d\n", zero_count))

  return zero_count
end

local function part_b_dumb(input_filename)
  local dial = DIAL_START

  local zero_count = 0

  for line in io.lines(input_filename) do
    local dial_old = dial

    local direction = line:sub(1, 1)
    local amount = tonumber(line:sub(2, -1))

    -- If we're moving left, flip the direction
    if direction == "L" then
      amount = -amount
    end

    -- Move the dial in the dumbest way possible
    local times_passed_zero = 0
    -- First handle going left:
    while amount < 0 do
      dial = dial - 1
      if dial % NUM_DIAL_POSITIONS == 0 then
        times_passed_zero = times_passed_zero + 1
      end
      if dial < DIAL_MIN then
        dial = DIAL_MAX
      end
      amount = amount + 1
    end
    -- Then handle going right:
    while amount > 0 do
      dial = dial + 1
      if dial % NUM_DIAL_POSITIONS == 0 then
        times_passed_zero = times_passed_zero + 1
      end
      if dial > DIAL_MAX then
        dial = DIAL_MIN
      end
      amount = amount - 1
    end

    -- Debugging output
    io.write(string.format("%s:\t%d → %d", line, dial_old, dial))

    -- Add to the zero count, but in a funky way that lets us add more
    -- debugging output.
    if times_passed_zero > 0 then
      io.write("\t")
      for _ = 1, times_passed_zero, 1 do
        zero_count = zero_count + 1
        io.write("*")
      end
    end

    io.write("\n")

    assert(
      dial >= DIAL_MIN,
      "dial is " .. dial .. ", but should never be less than " .. DIAL_MIN
    )
    assert(
      dial <= DIAL_MAX,
      "dial is " .. dial .. ", but should never be greater than " .. DIAL_MAX
    )
  end

  io.write(string.format("part b zero count: %d\n", zero_count))

  return zero_count
end

local function part_b(input_filename)
  local dial = DIAL_START

  local zero_count = 0

  for line in io.lines(input_filename) do
    local dial_old = dial

    local direction = line:sub(1, 1)
    local amount = tonumber(line:sub(2, -1))

    -- If we're moving left, flip the direction
    if direction == "L" then
      amount = -amount
    end

    -- Figure out how many times this rotation passes zero
    local times_passed_zero = 0
    if amount > 0 then
      times_passed_zero = math.floor((dial + amount) / NUM_DIAL_POSITIONS)
        - math.floor(dial / NUM_DIAL_POSITIONS)
    else
      times_passed_zero = math.floor((dial - 1) / NUM_DIAL_POSITIONS)
        - math.floor((dial - 1 + amount) / NUM_DIAL_POSITIONS)
    end

    -- Actually move the dial
    dial = (dial + amount + NUM_DIAL_POSITIONS) % NUM_DIAL_POSITIONS

    -- Debugging output
    io.write(string.format("%s:\t%d → %d", line, dial_old, dial))

    -- Add to the zero count, but in a funky way that lets us add more
    -- debugging output.
    if times_passed_zero > 0 then
      io.write("\t")
      for _ = 1, times_passed_zero, 1 do
        zero_count = zero_count + 1
        io.write("*")
      end
    end

    io.write("\n")

    assert(
      dial >= DIAL_MIN,
      "dial is " .. dial .. ", but should never be less than " .. DIAL_MIN
    )
    assert(
      dial <= DIAL_MAX,
      "dial is " .. dial .. ", but should never be greater than " .. DIAL_MAX
    )
  end

  io.write(string.format("part b zero count: %d\n", zero_count))

  return zero_count
end

local example_zero_count_a = part_a("problems/" .. CHALLENGE_EXAMPLE_INPUT)
assert(tostring(example_zero_count_a) == CHALLENGE_EXAMPLE_SOLUTION_A)

local zero_count_a = part_a("problems/" .. CHALLENGE_INPUT)

local example_zero_count_b_dumb =
  part_b_dumb("problems/" .. CHALLENGE_EXAMPLE_INPUT)
assert(tostring(example_zero_count_b_dumb) == CHALLENGE_EXAMPLE_SOLUTION_B)

local zero_count_b_dumb = part_b_dumb("problems/" .. CHALLENGE_INPUT)

local example_zero_count_b = part_b("problems/" .. CHALLENGE_EXAMPLE_INPUT)
assert(tostring(example_zero_count_b) == CHALLENGE_EXAMPLE_SOLUTION_B)

local zero_count_b = part_b("problems/" .. CHALLENGE_INPUT)

io.write(
  string.format(
    "\nPart A:\t\t%d zeroes landed on\nPart B (dumb):\t%d zeroes passed\nPart B:\t\t%d zeroes passed\n",
    zero_count_a,
    zero_count_b_dumb,
    zero_count_b
  )
)
