--!strict

--[[
	The test runner. It runs under Lune, outside Roblox: specs under tests/Pure require the Pure
	layer directly, and specs under tests/Core load plugin modules through tests/Support/Harness.

	    lune run tests/runner                 every spec under tests/
	    lune run tests/runner Hash            only specs whose path contains "Hash"
	    lune run tests/runner --dir=other     look under another folder
	    lune run tests/runner --json          print the result as one JSON object

	A spec is a file named `*.spec.luau` that returns a table of cases: `["what it checks"] =
	function(expect) ... end`. A case passes unless it throws, and `expect` holds the checks that
	throw. A spec that cannot be loaded, or that holds no cases, counts as a failure: a file that
	tests nothing must not look like a pass.

	Exit code 0 means every case passed, 1 means a case failed, 2 means nothing could be run.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

type Options = { Root: string, Json: boolean, Filter: string? }
type Failure = { case: string, error: string }
type Report = { passed: number, failed: number, failures: { Failure } }

local SPEC_SUFFIX = ".spec.luau"
local DEFAULT_TOLERANCE = 1e-6

--[[
	@param arguments { string } -- the command line

	@return Options
]]
local function readOptions(arguments: { string }): Options
	local options: Options = { Root = "tests", Json = false, Filter = nil }

	for _, argument in arguments do
		if argument == "--json" then
			options.Json = true
		elseif string.sub(argument, 1, 6) == "--dir=" then
			options.Root = string.sub(argument, 7)
		else
			options.Filter = argument
		end
	end

	return options
end

--[[
	@param message string

	Fails the case that is running. Level 0 keeps this file's own line numbers out of the message.
]]
local function reject(message: string)
	error(message, 0)
end

--[[
	The checks handed to every case. Each takes an optional label that leads the failure message,
	so a case with several checks says which one failed.
]]
local expect = {}

--[[
	@param actual any
	@param wanted any
	@param label string?
]]
function expect.equal(actual: any, wanted: any, label: string?)
	if actual ~= wanted then
		reject(`{label or "values differ"}: got {tostring(actual)}, wanted {tostring(wanted)}`)
	end
end

--[[
	@param value any
	@param label string?
]]
function expect.truthy(value: any, label: string?)
	if not value then
		reject(`{label or "wanted a truthy value"}: got {tostring(value)}`)
	end
end

--[[
	@param value any
	@param label string?
]]
function expect.falsy(value: any, label: string?)
	if value then
		reject(`{label or "wanted a falsy value"}: got {tostring(value)}`)
	end
end

--[[
	@param callback () -> () -- must throw
	@param label string?

	@return string -- what it threw, so the case can check the message too
]]
function expect.errors(callback: () -> (), label: string?): string
	local succeeded, thrown = pcall(callback)

	if succeeded then
		reject(`{label or "wanted an error"}: nothing was thrown`)
	end

	return tostring(thrown)
end

--[[
	@param actual number
	@param wanted number
	@param tolerance number? -- how far apart the two may be; 1e-6 when left out
	@param label string?
]]
function expect.near(actual: number, wanted: number, tolerance: number?, label: string?)
	local allowed = tolerance or DEFAULT_TOLERANCE

	if math.abs(actual - wanted) > allowed then
		reject(`{label or "values are not close"}: got {actual}, wanted {wanted} within {allowed}`)
	end
end

--[[
	@param root string -- the folder to search

	@return { string } -- the path of every spec under it, sorted
]]
local function findSpecs(root: string): { string }
	local specs = {}
	local toVisit = { root }

	while #toVisit > 0 do
		local folder = table.remove(toVisit) :: string

		for _, name in fs.readDir(folder) do
			local path = `{folder}/{name}`

			if fs.isDir(path) then
				table.insert(toVisit, path)
			elseif string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX then
				table.insert(specs, path)
			end
		end
	end

	table.sort(specs)

	return specs
end

--[[
	@param path string -- a spec file
	@param title string -- how the spec is named in failure messages
	@param report Report -- added to

	Loads one spec and runs its cases in name order, counting each into the report.
]]
local function runSpec(path: string, title: string, report: Report)
	--[[
		@param caseName string
		@param problem string
	]]
	local function fail(caseName: string, problem: string)
		report.failed += 1
		table.insert(report.failures, { case = `{title} > {caseName}`, error = problem })
	end

	-- Lune adds the extension itself, and resolves the path against this file's folder.
	local loaded, cases = pcall(require, "../" .. string.sub(path, 1, -#".luau" - 1))

	if not loaded then
		return fail("<load>", tostring(cases))
	elseif type(cases) ~= "table" then
		return fail("<load>", `the spec returned a {type(cases)}; it must return a table of cases`)
	end

	local names = {}

	for name, case in cases :: { [any]: any } do
		if type(case) == "function" then
			table.insert(names, tostring(name))
		else
			fail(tostring(name), `this case is a {type(case)}; it must be a function`)
		end
	end

	if #names == 0 then
		return fail("<load>", "the spec has no cases")
	end

	table.sort(names)

	for _, name in names do
		local passed, problem = pcall((cases :: { [string]: (any) -> () })[name], expect)

		if passed then
			report.passed += 1
		else
			fail(name, tostring(problem))
		end
	end
end

--[[
	@param options Options
	@param report Report
	@param problem string? -- set when the runner itself could not run anything

	Prints the outcome, as JSON or as lines for a person.
]]
local function printReport(options: Options, report: Report, problem: string?)
	if options.Json then
		print(serde.encode("json", {
			passed = report.passed,
			failed = report.failed,
			failures = report.failures,
			error = problem,
		}))

		return
	end

	if problem then
		print(`The runner could not run: {problem}`)

		return
	end

	for _, failure in report.failures do
		print(`FAIL  {failure.case}`)
		print(`      {failure.error}`)
	end

	print(`\nTests: {report.passed} passed, {report.failed} failed.`)
end

local options = readOptions(process.args)
local report: Report = { passed = 0, failed = 0, failures = {} }

if not fs.isDir(options.Root) then
	printReport(options, report, `{options.Root} is not a folder`)
	process.exit(2)
end

local ran = 0

for _, path in findSpecs(options.Root) do
	if options.Filter == nil or string.find(path, options.Filter, 1, true) then
		ran += 1
		runSpec(path, string.sub(path, #options.Root + 2, -#SPEC_SUFFIX - 1), report)
	end
end

if ran == 0 then
	local what = if options.Filter
		then `no spec under {options.Root} matches "{options.Filter}"`
		else `no spec under {options.Root}`

	printReport(options, report, what)
	process.exit(2)
end

printReport(options, report, nil)
process.exit(if report.failed == 0 then 0 else 1)
