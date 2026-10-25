--!strict

--[=[
	Where a railing post stands on stairs or a ramp. Built stairs are joined into one union, so the
	steps are found from the layout recorded on it rather than from separate step parts.

	Positions are in the stairs' own frame: X across (0 is the middle), Y up from the bottom, and Z
	negative going up the run, with 0 at the front of the first step.

	@class StairSnap
]=]

--[=[
	@interface Layout
	@within StairSnap
	.Run number -- the depth of each step
	.Rise number -- the height of each step
	.Count number -- how many steps
	.Width number
	.Landing number -- the depth of the top landing, 0 for none
	.Ramp boolean -- one smooth slope instead of steps
]=]
export type Layout = { Run: number, Rise: number, Count: number, Width: number, Landing: number, Ramp: boolean }

local StairSnap = {}

--[=[
	The post spot for a point on the stairs: on the side edge nearest the point, moved in by
	`inset`, and on a step at its lip, the front edge facing down the stairs, moved in by `inset` so
	the post stays on the step. On a ramp the spot stays where the point is along the slope; on the
	landing it is at the landing's front edge.

	@param layout Layout
	@param x number -- the point across the stairs
	@param z number -- the point along them
	@param inset number -- half a post
	@return number? -- the spot's X; nil when the point is not over the stairs
	@return number -- its Y
	@return number -- its Z
]=]
function StairSnap.Spot(layout: Layout, x: number, z: number, inset: number): (number?, number, number)
	local length = layout.Run * layout.Count
	local height = layout.Rise * layout.Count
	local along = -z
	local side = (if x >= 0 then 1 else -1) * math.max(0, layout.Width / 2 - inset)

	if along < -0.25 or along > length + layout.Landing + 0.25 or length <= 0 then
		return nil, 0, 0
	end

	if layout.Ramp and along < length then
		local at = math.max(0, along)

		return side, height * at / length, -at
	end

	if along >= length and layout.Landing > 0 then
		return side, height, -(length + math.min(inset, layout.Landing / 2))
	end

	local step = math.clamp(math.ceil(along / layout.Run), 1, layout.Count)
	local lip = layout.Run * (step - 1) + math.min(inset, layout.Run / 2)

	return side, layout.Rise * step, -lip
end

return StairSnap
