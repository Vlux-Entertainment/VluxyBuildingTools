--!strict

--[=[
	The Arrange tab's actions: repeated copies, mirror copies, snapping, dimensions and anchoring.
	Each works on the current selection and is one undo step.

	@class Arrange
]=]

local Selection = game:GetService("Selection")

local Geometry = require("./Geometry")
local Settings = require("../Pure/Settings")
local Snap = require("../Pure/Snap")

type Settings = Settings.Settings

export type Deps = {
	Settings: Settings,
	Save: () -> (),
	Edit: (action: string, callback: () -> ()) -> boolean,
	Say: (text: string) -> (),
	Stop: () -> (),
	Readout: (position: Vector3, text: string) -> (),
	FloorField: () -> (),
}

local MAX_COPIED_PARTS = 10000

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

		assert(copy, "A selected object cannot be cloned. Check Archivable.");
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
	@param deps Deps
	@return { [string]: () -> () } -- RepeatCopies, MirrorCopy, SnapSelection, ShowDimensions, AnchorSelection, UseSelectedFloor
]=]
function Arrange.new(deps: Deps): { [string]: () -> () }
	local settings, say = deps.Settings, deps.Say

	local function selection(): ({ Instance }, { BasePart })
		local roots = Geometry.SelectedRoots()

		return roots, Geometry.PartsOf(roots)
	end

	local function repeatCopies()
		deps.Stop()

		local roots, parts = selection()

		if #parts == 0 then
			return say("Select Parts or Models first.")
		elseif #parts * settings.Copies > MAX_COPIED_PARTS then
			return say("Limit: 10,000 copied Parts per action.")
		elseif not allArchivable(roots) then
			return say("Enable Archivable on selected objects first.")
		end

		local step = Vector3.new(settings.DX, settings.DY, settings.DZ)

		if step.Magnitude < 0.001 then
			return say("Give the copies some X, Y, or Z spacing first.")
		end

		local made = deps.Edit("Repeat objects", function()
			local all: { Instance } = {}

			for i = 1, settings.Copies do
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
			say("Copies created. Ctrl+Z undoes the whole set.")
		end
	end

	local function mirrorCopy()
		deps.Stop()

		local roots, parts = selection()

		if #parts == 0 then
			return say("Select Parts or Models first.")
		elseif not allArchivable(roots) then
			return say("Enable Archivable on selected objects first.")
		end

		local axis = settings.Axis

		local function reflect(v: Vector3): Vector3
			return Vector3.new(
				if axis == "X" then -v.X else v.X,
				if axis == "Y" then -v.Y else v.Y,
				if axis == "Z" then -v.Z else v.Z
			)
		end

		local function reflectCF(cf: CFrame): CFrame
			local up = reflect(cf.UpVector)
			local back = reflect(-cf.LookVector)

			return CFrame.fromMatrix(reflect(cf.Position), up:Cross(back), up, back)
		end

		local made = deps.Edit("Mirror objects", function()
			local copies = Arrange.CloneRoots(roots, function(cf)
				return cf
			end)

			for _, copy in copies do
				local pivot = (copy :: any):GetPivot()

				for _, part in Geometry.PartsOf({ copy }) do
					part.CFrame = reflectCF(part.CFrame)
				end

				if copy:IsA("Model") and not copy.PrimaryPart then
					copy.WorldPivot = reflectCF(pivot)
				end
			end

			Selection:Set(copies)
		end)

		if made then
			say("Mirrored across world " .. axis .. " = 0.")
		end
	end

	local function snapSelection()
		local roots = Geometry.SelectedRoots()

		if #roots == 0 then
			return say("Select objects first.")
		end

		deps.Edit("Snap objects", function()
			for _, root in roots do
				local cf = (root :: any):GetPivot() :: CFrame
				local p = cf.Position;
				(root :: any):PivotTo(
					CFrame.new(
						Snap.Round(p.X, settings.Grid),
						Snap.Round(p.Y, settings.Grid),
						Snap.Round(p.Z, settings.Grid)
					) * cf.Rotation
				)
			end
		end)
	end

	local function showDimensions()
		local _, parts = selection()

		if #parts == 0 then
			return say("Select objects first.")
		end

		local cf, size = Geometry.Bounds(parts)

		deps.Readout(
			cf.Position + Vector3.new(0, size.Y / 2, 0),
			string.format("X %.1f  Y %.1f  Z %.1f", size.X, size.Y, size.Z)
		)
		say(string.format("%.2f × %.2f × %.2f studs. X / Y / Z.", size.X, size.Y, size.Z))
	end

	local function anchorSelection()
		local _, parts = selection()

		if #parts == 0 then
			return say("Select objects first.")
		end

		deps.Edit("Anchor objects", function()
			for _, part in parts do
				part.Anchored = true
			end
		end)
	end

	local function useSelectedFloor()
		local _, parts = selection()

		if #parts == 0 then
			return say("Select a floor first, then click Use selected floor height.")
		end

		local cf, size = Geometry.Bounds(parts)

		settings.Elevation = cf.Y + size.Y / 2
		deps.Save()
		deps.FloorField()
		say("Drawing floor is now Y = " .. settings.Elevation .. ".")
	end

	return {
		RepeatCopies = repeatCopies,
		MirrorCopy = mirrorCopy,
		SnapSelection = snapSelection,
		ShowDimensions = showDimensions,
		AnchorSelection = anchorSelection,
		UseSelectedFloor = useSelectedFloor,
	}
end

return Arrange
