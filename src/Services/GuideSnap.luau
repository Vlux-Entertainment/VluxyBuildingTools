--!strict

--[=[
	Snaps a selection dragged with Studio's own tools onto a measuring guide. Studio's dragger
	cannot take extra snap points, so when a drag ends with the mouse close to a guide point on the
	screen, the selection moves so its nearest corner, edge middle or centre lands exactly on that
	point, as its own undo step. While dragging, a hint shows the point and where it would land.

	@class GuideSnap
]=]

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Edit = require("./Edit")
local Geometry = require("../Core/Geometry")
local Guides = require("../Core/Guides")
local Overlay = require("../Core/Overlay")

local MIN_REACH = 6

local GuideSnap = {}

--[=[
	Where letting go now would snap the selection.

	@interface Plan
	@within GuideSnap
	.Roots { PVInstance } -- the selected things that move
	.Target Vector3 -- the guide point
	.Pull Vector3 -- how far they move
	.Box CFrame -- the selection's box now
	.Size Vector3
]=]
type Plan = { Roots: { PVInstance }, Target: Vector3, Pull: Vector3, Box: CFrame, Size: Vector3 }

--[[
	@param pixels number -- how close on screen the mouse must be to a guide point
	@return Plan? -- the snap for the selection and the mouse now, or nil when the mouse is not near a guide point a selection point can reach
]]
local function plan(pixels: number): Plan?
	if Guides.Count() == 0 then
		return nil
	end

	local target = Guides.NearOnScreen(UserInputService:GetMouseLocation(), pixels)

	if not target then
		return nil
	end

	local roots: { PVInstance } = {}
	local parts: { BasePart } = {}

	for _, object in Selection:Get() do
		if object:IsA("PVInstance") and object:IsDescendantOf(workspace) then
			table.insert(roots, object)

			if object:IsA("BasePart") then
				table.insert(parts, object)
			end

			for _, child in object:GetDescendants() do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
		end
	end

	if #parts == 0 then
		return nil
	end

	local box, size = Geometry.Bounds(parts)
	local reach = math.max(MIN_REACH, math.max(size.X, size.Y, size.Z) * 0.6)
	local pull = Guides.Pull(Guides.BoxAnchors(box.Position, size), target, reach)

	if not pull or pull.Magnitude < 1e-3 then
		return nil
	end

	return { Roots = roots, Target = target, Pull = pull, Box = box, Size = size }
end

local hintQueued = false

--[=[
	Hides the snap hint.

	@param overlay Overlay.Overlay
]=]
function GuideSnap.ClearHint(overlay: Overlay.Overlay)
	Overlay.DrawSnapHint(overlay, nil, nil)
	Overlay.HideReadout(overlay)
end

--[=[
	Call while one of Studio's drags moves the selection. At most once per frame it shows where
	letting go would snap: the guide point, the selection's landing outline and "Let go to snap".

	@param enabled boolean -- whether snapping to guides is on
	@param overlay Overlay.Overlay
	@param pixels number -- how close on screen the mouse must be to a guide point
]=]
function GuideSnap.Hint(enabled: boolean, overlay: Overlay.Overlay, pixels: number)
	if hintQueued then
		return
	end

	hintQueued = true

	task.defer(function()
		hintQueued = false

		local found = if enabled then plan(pixels) else nil

		if found then
			Overlay.DrawSnapHint(overlay, found.Target, { cf = found.Box + found.Pull, size = found.Size })
			Overlay.Readout(overlay, found.Target, "Let go to snap")
		else
			GuideSnap.ClearHint(overlay)
		end
	end)
end

--[=[
	Call when one of Studio's drags has finished.

	@param enabled boolean -- whether snapping to guides is on
	@param edit Edit.Edit
	@param pixels number -- how close on screen the mouse must be to a guide point
]=]
function GuideSnap.AfterDrag(enabled: boolean, edit: Edit.Edit, pixels: number)
	local found = if enabled then plan(pixels) else nil

	if not found then
		return
	end

	local roots, move = found.Roots, found.Pull

	task.defer(function()
		edit("Snap to guide", function()
			for _, root in roots do
				if root.Parent then
					root:PivotTo(root:GetPivot() + move)
				end
			end
		end)
	end)
end

return GuideSnap
