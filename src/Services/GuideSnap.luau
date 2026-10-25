--!strict

--[=[
	Snaps a selection dragged with Studio's own tools onto a measuring guide. Studio's dragger
	cannot take extra snap points, so when a drag ends with the mouse close to a guide point on the
	screen, the selection moves so its nearest corner, edge middle or centre lands exactly on that
	point, as its own undo step.

	@class GuideSnap
]=]

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Edit = require("./Edit")
local Geometry = require("../Core/Geometry")
local Guides = require("../Core/Guides")

local PIXELS = 24
local REACH = 3

local GuideSnap = {}

--[=[
	Call when one of Studio's drags has finished.

	@param enabled boolean -- whether snapping to guides is on
	@param edit Edit.Edit
]=]
function GuideSnap.AfterDrag(enabled: boolean, edit: Edit.Edit)
	if not enabled or Guides.Count() == 0 then
		return
	end

	local target = Guides.NearOnScreen(UserInputService:GetMouseLocation(), PIXELS)

	if not target then
		return
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
		return
	end

	local box, size = Geometry.Bounds(parts)
	local pull = Guides.Pull(Guides.BoxAnchors(box.Position, size), target, REACH)

	if not pull or pull.Magnitude < 1e-3 then
		return
	end

	local move = pull

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
