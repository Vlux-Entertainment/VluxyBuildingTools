--!strict

--[[
	The performance runner. It times every benchmark under tests/Perf and fails when one is over
	its budget, so a slow change shows up before a builder feels sluggish in Studio.

	    lune run tests/perf             every benchmark
	    lune run tests/perf Builders    only files whose path contains "Builders"

	A bench is a file named `*.bench.luau` that returns `{ ["name"] = { Budget = ms, Run = fn } }`.
	Each Run is called once to warm up, then again until about a quarter second has passed (at
	least five times), and the median time is compared with the budget. Timings depend on the
	machine, so `npm run verify` does not run this; budgets are about three times a measured run.

	Exit code 0 means every bench was within budget, 1 means one was over, 2 means none could run.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

type Bench = { Budget: number, Run: () -> () }
type Row = { Name: string, Ms: number, Budget: number }

local ROOT = "tests/Perf"
local SUFFIX = ".bench.luau"
local MIN_RUNS = 5
local MIN_SECONDS = 0.25

--[[
	@param bench Bench
	@return number -- the median milliseconds one Run takes
]]
local function time(bench: Bench): number
	bench.Run()

	local samples = {}
	local started = os.clock()

	while #samples < MIN_RUNS or os.clock() - started < MIN_SECONDS do
		local before = os.clock()

		bench.Run()
		table.insert(samples, (os.clock() - before) * 1000)
	end

	table.sort(samples)

	return samples[math.ceil(#samples / 2)]
end

--[[
	@param text string
	@param width number
	@return string -- the text padded with spaces on the right to the width
]]
local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(0, width - #text))
end

local filter = process.args[1]
local rows: { Row } = {}
local files = {}

for _, name in if fs.isDir(ROOT) then fs.readDir(ROOT) else {} do
	if string.sub(name, -#SUFFIX) == SUFFIX and (filter == nil or string.find(name, filter, 1, true)) then
		table.insert(files, name)
	end
end

table.sort(files)

for _, file in files do
	local benches = require("./Perf/" .. string.sub(file, 1, -#".luau" - 1)) :: { [string]: Bench }
	local names = {}

	for name in benches do
		table.insert(names, name)
	end

	table.sort(names)

	for _, name in names do
		table.insert(rows, { Name = name, Ms = time(benches[name]), Budget = benches[name].Budget })
	end
end

if #rows == 0 then
	print(`No benchmark under {ROOT}{if filter then ` matches "{filter}"` else ""}.`)
	process.exit(2)
end

local width = 0

for _, row in rows do
	width = math.max(width, #row.Name)
end

local over = 0

print(`{pad("Benchmark", width)}  {pad("ms/run", 9)}  {pad("budget", 8)}  result`)

for _, row in rows do
	local ok = row.Ms <= row.Budget

	if not ok then
		over += 1
	end

	print(
		`{pad(row.Name, width)}  {pad(string.format("%.3f", row.Ms), 9)}  {pad(tostring(row.Budget), 8)}  {if ok
			then "OK"
			else "OVER"}`
	)
end

print(if over == 0 then `\nAll {#rows} within budget.` else `\n{over} of {#rows} over budget.`)
process.exit(if over == 0 then 0 else 1)
