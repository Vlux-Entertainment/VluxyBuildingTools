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
]=]
export type Guide = { Lines: { { Vector3 } }, Points: { Vector3 } }

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

return Guides
