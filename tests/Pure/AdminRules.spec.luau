--!strict

local AdminRules = require("../../src/Pure/AdminRules")

local NOW = 1_000_000

--[[
	@param id number
	@param joined number -- seconds before NOW
	@param seen number -- seconds before NOW
	@return AdminRules.Entry
]]
local function entry(id: number, joined: number, seen: number): AdminRules.Entry
	return { UserId = id, Joined = NOW - joined, Seen = NOW - seen }
end

return {
	["a user alone is admin"] = function(expect)
		local entries = { entry(7, 5, 1) }

		expect.equal(AdminRules.Choose(entries, nil, NOW), 7)
		expect.truthy(AdminRules.ShouldClaim(entries, nil, 7, NOW))
	end,

	["the longest present wins, ties by lower id"] = function(expect)
		local entries = { entry(30, 100, 2), entry(20, 300, 2), entry(10, 300, 2) }

		expect.equal(AdminRules.Choose(entries, nil, NOW), 10)
		expect.equal(AdminRules.Present(entries, NOW)[2].UserId, 20)
		expect.falsy(AdminRules.ShouldClaim(entries, nil, 30, NOW))
	end,

	["a stale admin passes it on"] = function(expect)
		local entries = { entry(1, 900, 60), entry(2, 500, 3), entry(3, 100, 3) }

		expect.equal(AdminRules.Choose(entries, 1, NOW), 2)
		expect.truthy(AdminRules.ShouldClaim(entries, 1, 2, NOW))
		expect.falsy(AdminRules.ShouldClaim(entries, 1, 3, NOW))
	end,

	["a named admin is kept while present"] = function(expect)
		local entries = { entry(1, 900, 3), entry(2, 100, 3) }

		expect.equal(AdminRules.Choose(entries, 2, NOW), 2)
		expect.falsy(AdminRules.ShouldClaim(entries, 2, 1, NOW))
	end,

	["nobody present means no admin"] = function(expect)
		expect.equal(AdminRules.Choose({ entry(1, 900, 100) }, 1, NOW), nil)
	end,

	["reads entries from attributes"] = function(expect)
		local entries = AdminRules.Read({
			VluxyBT_Here_12 = NOW - 1,
			VluxyBT_Joined_12 = NOW - 50,
			VluxyBT_Here_9 = NOW - 2,
			VluxyBT_Admin = 12,
			VluxyBT_Here_bad = 5,
		})

		expect.equal(#entries, 2)

		for _, item in entries do
			expect.equal(item.Joined, if item.UserId == 12 then NOW - 50 else NOW - 2)
		end
	end,

	["requests parse and run out"] = function(expect)
		local value = AdminRules.FormatRequest(42, NOW - 10)

		expect.equal(AdminRules.ParseRequest(value, NOW), 42)
		expect.equal(AdminRules.ParseRequest(value, NOW + AdminRules.REQUEST_FOR), nil)
		expect.equal(AdminRules.ParseRequest("nonsense", NOW), nil)
		expect.equal(AdminRules.ParseRequest(nil, NOW), nil)
	end,

	["long-gone users are forgotten"] = function(expect)
		local gone = AdminRules.Forgotten({ entry(1, 5000, AdminRules.FORGET_AFTER), entry(2, 10, 1) }, NOW)

		expect.equal(#gone, 1)
		expect.equal(gone[1], 1)
	end,
}
