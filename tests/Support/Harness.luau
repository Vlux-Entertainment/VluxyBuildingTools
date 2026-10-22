--!strict

--[=[
	Loads plugin modules from `src/` under Lune, so a spec runs the plugin's own code rather than a
	copy of it. Not a spec: the runner only collects `*.spec.luau`.

	Each module gets its own `require`, which resolves the string requires the plugin uses
	(`"./Shapes"`, `"../Geometry"`, `"../../Pure/Settings"`) against the module's own folder, and
	maps `"../Packages/<Name>"` to the Wally package that `Packages/<Name>.lua` links to. The Roblox
	datatypes, `Enum` and `Instance` come from `@lune/roblox`; `game` is a real DataModel, so
	`game:GetService` and `workspace` work, and Parts keep their reflected properties.

	What cannot work outside Studio is left out, not faked: raycasts, `GetPartBoundsInRadius`,
	signals on instances, ChangeHistoryService recordings, CSG and plugin APIs. Lune also cannot
	compute `BasePart.Position` from `CFrame`, so call `SyncPositions` after building parts that
	code under test reads `Position` from, and its `CFrame.lookAt` is wrong, so modules get the
	corrected `Harness.CFrame`.

	Run specs from the repo root (`lune run tests/runner`): file paths here are relative to it.

	@class Harness
]=]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

export type Context = {
	Game: any,
	Workspace: any,
	Require: (self: Context, path: string) -> any,
}

local Harness = {}

local Datatypes: { [string]: any } = {}

--[[
	Roblox's `CFrame.lookAt`, built on `fromMatrix`. Lune 0.10.5's own lookAt mirrors the Z of the
	look direction, so a wall drawn toward -Z would face +Z.

	@param at any -- Vector3
	@param target any -- Vector3
	@param up any? -- Vector3; world up when left out
	@return any -- CFrame
]]
local function lookAt(at: any, target: any, up: any?): any
	local look = target - at

	if look.Magnitude < 1e-9 then
		return roblox.CFrame.new(at)
	end

	look = look.Unit

	local right = look:Cross(up or roblox.Vector3.yAxis)

	if right.Magnitude < 1e-6 then
		right = look:Cross(roblox.Vector3.zAxis)
	end

	right = right.Unit

	return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
end

--[=[
	`@lune/roblox`'s CFrame with `lookAt` and the two-point `new` corrected. Modules loaded by the
	harness get this one; specs that build looking frames should use it too.

	@prop CFrame any
	@within Harness
]=]
Harness.CFrame = setmetatable({
	lookAt = lookAt,
	new = function(...: any): any
		local first, second = ...

		if select("#", ...) == 2 and typeof(first) == "Vector3" and typeof(second) == "Vector3" then
			return lookAt(first, second)
		end

		return roblox.CFrame.new(...)
	end,
}, { __index = roblox.CFrame })

for name, value in roblox :: any do
	if type(value) ~= "function" and string.match(name, "^%u") then
		Datatypes[name] = value
	end
end

Datatypes.CFrame = Harness.CFrame

--[[
	@param path string -- a slash path relative to the repo root
	@return string -- the path with every `.` and `..` part folded away
]]
local function normalize(path: string): string
	local parts = {}

	for part in string.gmatch(path, "[^/]+") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." then
			table.insert(parts, part)
		end
	end

	return table.concat(parts, "/")
end

--[[
	@param modulePath string -- a module path without its extension
	@return string? -- the file that holds it, or nil when there is none
]]
local function findFile(modulePath: string): string?
	for _, candidate in { `{modulePath}.luau`, `{modulePath}.lua`, `{modulePath}/init.luau`, `{modulePath}/init.lua` } do
		if fs.isFile(candidate) then
			return candidate
		end
	end

	return nil
end

--[[
	Follows a Wally link file (`Packages/Trove.lua`) to the package's entry file. Only the
	`_Index["scope_name@version"]["name"]` form Wally writes is understood.

	@param name string -- the package name, as `src` requires it
	@return string? -- the entry file, or nil when the link cannot be followed
]]
local function packageFile(name: string): string?
	local link = findFile(`Packages/{name}`)

	if not link then
		return nil
	end

	local folder, inner = string.match(fs.readFile(link), '_Index%["([^"]+)"%]%["([^"]+)"%]')

	if not folder or not inner then
		return nil
	end

	local root = `Packages/_Index/{folder}/{inner}`

	return findFile(root) or findFile(`{root}/src`) or findFile(`{root}/{name}`)
end

--[=[
	Makes a fresh world: a new DataModel and an empty module cache. Modules required through one
	context share state (one `Geometry` scope); two contexts share nothing.

	@return Context
]=]
function Harness.new(): Context
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local cache: { [string]: any } = {}
	local loadFile: (file: string) -> any

	--[[
		@param from string -- the file doing the require
		@param target string -- the string it passed
		@return any -- what the required module returns
	]]
	local function requireFrom(from: string, target: string): any
		local folder = string.match(from, "^(.*)/[^/]+$") or "."
		local modulePath = normalize(`{folder}/{target}`)
		local packageName = string.match(modulePath, "^src/Packages/([^/]+)$")
		local file = if packageName then packageFile(packageName) else findFile(modulePath)

		if not file then
			error(`Harness: {from} requires "{target}", which resolves to nothing at {modulePath}`, 2)
		end

		if cache[file] == nil then
			cache[file] = loadFile(file)
		end

		return cache[file]
	end

	loadFile = function(file: string): any
		local environment: { [string]: any } = {
			game = game,
			workspace = workspace,
			task = task,
			warn = function(...)
				local _ = ...
			end,
			require = function(target: any)
				assert(type(target) == "string", `Harness: {file} required a non-string module`)

				return requireFrom(file, target)
			end,
		}

		for name, value in Datatypes do
			environment[name] = value
		end

		local chunk = luau.load(fs.readFile(file), {
			debugName = file,
			environment = environment,
			injectGlobals = true,
		})

		return chunk()
	end

	local context = { Game = game, Workspace = workspace } :: any

	--[[
		@param path string -- a module under the repo root, with or without `.luau`
		@return any -- what the module returns, loaded once per context
	]]
	function context.Require(_self: Context, path: string): any
		local file = findFile((string.gsub(path, "%.luau?$", "")))

		assert(file, `Harness: no module at {path}`)

		if cache[file] == nil then
			cache[file] = loadFile(file)
		end

		return cache[file]
	end

	return context :: Context
end

--[=[
	Loads one module in a fresh context, for specs that need only that module.

	@param path string -- a module under the repo root, such as `src/Core/Builders/Areas`
	@return any
]=]
function Harness.Load(path: string): any
	return Harness.new():Require(path)
end

--[=[
	Copies each part's `CFrame.Position` into `Position`, which Lune does not derive by itself.

	@param root any -- a part, or an instance whose descendant parts are synced
]=]
function Harness.SyncPositions(root: any)
	local parts = root:GetDescendants()

	table.insert(parts, root)

	for _, part in parts do
		if part:IsA("BasePart") then
			part.Position = part.CFrame.Position
		end
	end
end

--[=[
	A stand-in for the RaycastResult a tool gets from the cursor.

	@param part any -- the instance that was hit
	@param position any -- the Vector3 where it was hit
	@param normal any? -- the face normal; straight up when left out
	@return { Instance: any, Position: any, Normal: any }
]=]
function Harness.Hit(part: any, position: any, normal: any?): { Instance: any, Position: any, Normal: any }
	return { Instance = part, Position = position, Normal = normal or roblox.Vector3.yAxis }
end

--[=[
	A plain anchored Part, parented when a parent is given.

	@param size any -- Vector3
	@param cf any -- CFrame
	@param parent any?
	@return any -- the Part, with `Position` already synced
]=]
function Harness.Part(size: any, cf: any, parent: any?): any
	local part = roblox.Instance.new("Part")

	part.Size = size
	part.CFrame = cf
	part.Position = cf.Position
	part.Anchored = true
	part.Parent = parent

	return part
end

--[=[
	@param specs { any } -- the specs a builder returned
	@param name string
	@return { any } -- the specs with that name, in order
]=]
function Harness.Named(specs: { any }, name: string): { any }
	local found = {}

	for _, spec in specs do
		if spec.name == name then
			table.insert(found, spec)
		end
	end

	return found
end

--[=[
	@param v any -- a Vector3
	@return string -- the vector rounded to 1/1000, so specs compare plain strings
]=]
function Harness.Vec(v: any): string
	--[[
		@param n number
		@return string -- n to three decimals, with -0 written as 0
	]]
	local function round(n: number): string
		local value = math.round(n * 1000) / 1000

		return tostring(if value == 0 then 0 else value)
	end

	return `{round(v.X)},{round(v.Y)},{round(v.Z)}`
end

return Harness
