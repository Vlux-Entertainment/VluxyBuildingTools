--!strict

--[=[
	Measures the world-aligned box around every Part inside an instance a little at a time, so the
	outline of a folder with a hundred thousand parts never stalls a frame. Each call to `Step` walks
	the tree for a set time and picks up where the last one stopped; when a walk ends its box is
	published and the next walk starts, so the box follows parts moved by any tool. Parts inside
	other Parts are not searched.

	@class BoundsScan
]=]

local Geometry = require("./Geometry")

export type BoundsScan = {
	--[=[ The instance being measured. ]=]
	Target: Instance?,
	--[=[ The centre of the last finished box, or nil before the first walk ends or when there are no parts. ]=]
	CFrame: CFrame?,
	Size: Vector3?,
	--[=[ Goes up whenever the published box or the target changes, so a caller redraws only then. ]=]
	Version: number,
	_stack: { Instance },
	_low: Vector3,
	_high: Vector3,
	_found: boolean,
}

local CLOCK_CHECK = 64

local BoundsScan = {}

--[[
	@param self BoundsScan

	Starts a new walk from the target.
]]
local function restart(self: BoundsScan)
	self._stack = if self.Target then { self.Target } else {}
	self._low = Vector3.new(math.huge, math.huge, math.huge)
	self._high = -self._low
	self._found = false
end

--[=[
	@return BoundsScan
]=]
function BoundsScan.new(): BoundsScan
	local self: BoundsScan = {
		Target = nil,
		CFrame = nil,
		Size = nil,
		Version = 0,
		_stack = {},
		_low = Vector3.zero,
		_high = Vector3.zero,
		_found = false,
	}

	restart(self)

	return self
end

--[=[
	Walks on for up to `budget` seconds. A new target drops the old box and starts over.

	@param self BoundsScan
	@param target Instance? -- what to measure; nil measures nothing
	@param budget number -- seconds this call may spend
]=]
function BoundsScan.Step(self: BoundsScan, target: Instance?, budget: number)
	if target ~= self.Target then
		self.Target = target
		self.CFrame, self.Size = nil, nil
		self.Version += 1
		restart(self)
	end

	if not target then
		return
	end

	local stack = self._stack
	local deadline = os.clock() + budget
	local count = 0

	while true do
		local top = #stack

		if top == 0 then
			local cframe = if self._found then CFrame.new((self._low + self._high) * 0.5) else nil
			local size = if self._found then self._high - self._low else nil

			if cframe ~= self.CFrame or size ~= self.Size then
				self.CFrame, self.Size = cframe, size
				self.Version += 1
			end

			restart(self)

			return
		end

		local object = stack[top]

		stack[top] = nil

		if object:IsA("BasePart") then
			local low, high = Geometry.PartBox(object)

			self._low, self._high = self._low:Min(low), self._high:Max(high)
			self._found = true
		else
			for _, child in object:GetChildren() do
				table.insert(stack, child)
			end
		end

		count += 1

		if count % CLOCK_CHECK == 0 and os.clock() >= deadline then
			return
		end
	end
end

return BoundsScan
