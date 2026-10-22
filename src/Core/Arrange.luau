--!strict

--[=[
	The Arrange tab's actions: the array (Blender's Array modifier: a live preview of the copies,
	then Apply), flipping and turning. Each works on the current selection and is one undo step.

	@class Arrange
]=]

local Selection = game:GetService("Selection")

local ArrayStep = require("../Pure/ArrayStep")
local Geometry = require("./Geometry")
local Settings = require("../Pure/Settings")

type Settings = Settings.Settings

export type Deps = {
	--[=[ The live settings, read only. ]=]
	Settings: Settings,
	Edit: (action: string, callback: () -> ()) -> boolean,
	Say: (text: string) -> (),
	Stop: () -> (),
	--[=[ Shows the array's preview boxes, or hides them for an empty list. ]=]
	Ghosts: (specs: { Geometry.Spec }) -> (),
}

local MAX_COPIED_PARTS = 10000

export type Actions = {
	ApplyArray: () -> (),
	PreviewArray: (active: boolean) -> (),
	Flip: (axis: string) -> (),
	RotateBy: (axis: string, degrees: number) -> (),
}

--[[
	@param axis string -- "X", "Y" or "Z"
	@param v Vector3

	@return Vector3 -- v reflected across the plane perpendicular to the axis
]]
local function reflectVector(axis: string, v: Vector3): Vector3
	return Vector3.new(
		if axis == "X" then -v.X else v.X,
		if axis == "Y" then -v.Y else v.Y,
		if axis == "Z" then -v.Z else v.Z
	)
end

--[[
	@param axis string
	@param cf CFrame

	@return CFrame -- the mirrored frame, kept as a proper rotation
]]
local function reflectFrame(axis: string, cf: CFrame): CFrame
	local up = reflectVector(axis, cf.UpVector)
	local back = reflectVector(axis, -cf.LookVector)

	return CFrame.fromMatrix(reflectVector(axis, cf.Position), up:Cross(back), up, back)
end

local Arrange = {}

--[=[
	Clones each root, moves the clone's pivot through a function, and parents it.

	@param roots { Instance }
	@param transform (CFrame) -> CFrame -- maps a root's pivot to its copy's pivot
	@param parent Instance? -- the original's parent when left out
	@return { Instance } -- the copies
]=]
function Arrange.CloneRoots(roots: { Instance }, transform: (CFrame) -> CFrame, parent: Instance?): { Instance }
	local copies: { Instance } = {}

	for _, root in roots do
		local copy = root:Clone()

		assert(copy, "A selected object cannot be copied; check Archivable.");
		(copy :: any):PivotTo(transform((root :: any):GetPivot()))
		copy.Parent = parent or root.Parent
		table.insert(copies, copy)
	end

	return copies
end

--[[
	@param roots { Instance }

	@return boolean -- true when every root can be cloned
]]
local function allArchivable(roots: { Instance }): boolean
	for _, root in roots do
		if not root.Archivable then
			return false
		end
	end

	return true
end

--[=[
	@param settings Settings
	@param parts { BasePart } -- the selection's parts
	@return Vector3 -- how far each copy of the array moves from the one before it
]=]
function Arrange.ArrayOffset(settings: Settings, parts: { BasePart }): Vector3
	local _, size = Geometry.Bounds(parts)
	local step = ArrayStep.Offset(
		{ size.X, size.Y, size.Z },
		settings.ArrayRelative,
		{ settings.ArrayRelX, settings.ArrayRelY, settings.ArrayRelZ },
		settings.ArrayConstant,
		{ settings.ArrayConstX, settings.ArrayConstY, settings.ArrayConstZ }
	)

	return Vector3.new(step[1], step[2], step[3])
end

--[=[
	The preview boxes for the array: one spec per part per copy, each moved by the array's offset.

	@param settings Settings
	@param parts { BasePart } -- the selection's parts
	@return { Geometry.Spec } -- empty when there is nothing to copy
]=]
function Arrange.ArraySpecs(settings: Settings, parts: { BasePart }): { Geometry.Spec }
	local copies = ArrayStep.Copies(settings.ArrayCount)
	local specs: { Geometry.Spec } = {}

	if #parts == 0 or copies == 0 then
		return specs
	end

	local step = Arrange.ArrayOffset(settings, parts)

	for i = 1, copies do
		for _, part in parts do
			table.insert(specs, {
				size = part.Size,
				cf = part.CFrame + step * i,
				name = part.Name,
				class = part.ClassName,
			})
		end
	end

	return specs
end

--[=[
	@param deps Deps
	@return Actions
]=]
function Arrange.new(deps: Deps): Actions
	local settings, say = deps.Settings, deps.Say
	local previewing = false

	local function selection(): ({ Instance }, { BasePart })
		local roots = Geometry.SelectedRoots()

		return roots, Geometry.PartsOf(roots)
	end

	--[[ Makes the array's copies of the selection, as one undo step, and selects the whole array. ]]
	local function applyArray()
		deps.Stop()

		local roots, parts = selection()
		local copies = ArrayStep.Copies(settings.ArrayCount)

		if #parts == 0 then
			return say("Select Parts or Models inside the working folder first.")
		elseif copies == 0 then
			return say("Set Count to 2 or more to make copies.")
		elseif #parts * copies > MAX_COPIED_PARTS then
			return say("Limit: 10,000 copied Parts per array.")
		elseif not allArchivable(roots) then
			return say("Enable Archivable on selected objects first.")
		end

		local step = Arrange.ArrayOffset(settings, parts)

		if step.Magnitude < 0.001 then
			return say("Give the array an offset first: Relative or Constant, on X, Y or Z.")
		end

		local made = deps.Edit("Apply array", function()
			local all: { Instance } = table.clone(roots)

			for i = 1, copies do
				for _, copy in
					Arrange.CloneRoots(roots, function(cf)
						return cf + step * i
					end)
				do
					table.insert(all, copy)
				end
			end

			Selection:Set(all)
		end)

		if made then
			say(string.format("Array applied: %d objects; Ctrl+Z undoes it.", copies + 1))
		end
	end

	--[[
		@param active boolean -- true while the Arrange tab is open and no tool runs

		Draws where the array's copies would go, or hides the preview once it is not wanted.
	]]
	local function previewArray(active: boolean)
		local parts: { BasePart } = {}

		if active then
			local _, selected = selection()

			parts = selected
		end

		local specs = Arrange.ArraySpecs(settings, parts)

		if #specs == 0 then
			if previewing then
				previewing = false
				deps.Ghosts({})
			end

			return
		end

		previewing = true
		deps.Ghosts(specs)
	end

	local function flip(axis: string)
		deps.Stop()

		local _, parts = selection()

		if #parts == 0 then
			return say("Select Parts or Models inside the working folder first.")
		end

		local center = Geometry.Bounds(parts).Position

		--[[ Mirrors a frame across the plane through the centre, keeping it a proper rotation. ]]
		local function flipped(cf: CFrame): CFrame
			return CFrame.new(center + reflectVector(axis, cf.Position - center)) * reflectFrame(axis, cf.Rotation)
		end

		local made = deps.Edit("Flip objects", function()
			local pivots = Geometry.WholeModels(parts)

			for _, part in parts do
				part.CFrame = flipped(part.CFrame)
			end

			Geometry.MovePivots(pivots, flipped)
		end)

		if made then
			say("Flipped across " .. axis .. " around the selection's centre.")
		end
	end

	local function rotateBy(axis: string, degrees: number)
		deps.Stop()

		local _, parts = selection()

		if #parts == 0 then
			return say("Select Parts or Models inside the working folder first.")
		end

		local center = Geometry.Bounds(parts).Position
		local unit = if axis == "X" then Vector3.xAxis elseif axis == "Y" then Vector3.yAxis else Vector3.zAxis
		local turn = CFrame.fromAxisAngle(unit, math.rad(degrees))

		--[[ Turns a frame about the selection's centre. ]]
		local function turned(cf: CFrame): CFrame
			return CFrame.new(center + turn:VectorToWorldSpace(cf.Position - center)) * turn * cf.Rotation
		end

		local made = deps.Edit("Rotate objects", function()
			local pivots = Geometry.WholeModels(parts)

			for _, part in parts do
				part.CFrame = turned(part.CFrame)
			end

			Geometry.MovePivots(pivots, turned)
		end)

		if made then
			say(string.format("Rotated %d° about %s.", degrees, axis))
		end
	end

	return {
		Flip = flip,
		RotateBy = rotateBy,
		ApplyArray = applyArray,
		PreviewArray = previewArray,
	}
end

return Arrange
