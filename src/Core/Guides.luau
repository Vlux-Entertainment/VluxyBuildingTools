--!strict

--[=[
	The measurements kept in the viewport as guides. Each one's lines are drawn until they are
	cleared, and its points (corners, edge middles, centres) are snap points for every tool. They
	live only in this Studio session; nothing is saved in the place.

	@class Guides
]=]

--[=[
	@interface Guide
	@within Guides
	.Lines { { Vector3 } } -- pairs of points to draw between
	.Points { Vector3 } -- the points other tools snap to
	.Fill Fill? -- the shape's inside, drawn see-through
]=]
export type Guide = { Lines: { { Vector3 } }, Points: { Vector3 }, Fill: Fill? }

--[=[
	The inside of a measured shape: a box (a square is a flat one), a flat disc or a ball.

	@interface Fill
	@within Guides
	.Shape string -- "Box", "Disc" or "Ball"
	.CFrame CFrame -- its middle
	.Size Vector3 -- a box's size; for a disc or ball, the radius is X / 2
]=]
export type Fill = { Shape: string, CFrame: CFrame, Size: Vector3 }

local kept: { Guide } = {}

local Guides = {}

--[=[
	@param guide Guide
]=]
function Guides.Add(guide: Guide)
	table.insert(kept, guide)
end

--[=[
	Removes every guide.
]=]
function Guides.Clear()
	table.clear(kept)
end

--[=[
	@return number -- how many guides are kept
]=]
function Guides.Count(): number
	return #kept
end

--[=[
	@return { Guide }
]=]
function Guides.All(): { Guide }
	return kept
end

--[=[
	@param point Vector3
	@param radius number
	@return Vector3? -- the nearest guide point within the radius
]=]
function Guides.Near(point: Vector3, radius: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = radius

	for _, guide in kept do
		for _, spot in guide.Points do
			local distance = (spot - point).Magnitude

			if distance < bestDistance then
				best, bestDistance = spot, distance
			end
		end
	end

	return best
end

--[=[
	@param mouse Vector2 -- the mouse on the screen
	@param pixels number -- how close on screen counts
	@return Vector3? -- the guide point nearest the mouse on screen, within the pixels
]=]
function Guides.NearOnScreen(mouse: Vector2, pixels: number): Vector3?
	local camera = workspace.CurrentCamera
	local best: Vector3? = nil
	local bestDistance = pixels

	if not camera then
		return nil
	end

	for _, guide in kept do
		for _, spot in guide.Points do
			local screen = camera:WorldToScreenPoint(spot)

			if screen.Z > 0 then
				local distance = (Vector2.new(screen.X, screen.Y) - mouse).Magnitude

				if distance < bestDistance then
					best, bestDistance = spot, distance
				end
			end
		end
	end

	return best
end

--[=[
	@param center Vector3 -- the middle of a level box
	@param size Vector3
	@return { Vector3 } -- the box's corners, edge middles, face centres and centre
]=]
function Guides.BoxAnchors(center: Vector3, size: Vector3): { Vector3 }
	local out: { Vector3 } = {}

	for _, x in { -1, 0, 1 } do
		for _, y in { -1, 0, 1 } do
			for _, z in { -1, 0, 1 } do
				table.insert(out, center + size * Vector3.new(x, y, z) * 0.5)
			end
		end
	end

	return out
end

--[=[
	@param anchors { Vector3 } -- points of the thing being moved
	@param target Vector3 -- a guide point
	@param reach number
	@return Vector3? -- the move that puts the anchor nearest the target onto it, when one is within reach
]=]
function Guides.Pull(anchors: { Vector3 }, target: Vector3, reach: number): Vector3?
	local best: Vector3? = nil
	local bestDistance = reach

	for _, anchor in anchors do
		local distance = (target - anchor).Magnitude

		if distance <= bestDistance then
			best, bestDistance = target - anchor, distance
		end
	end

	return best
end

return Guides
