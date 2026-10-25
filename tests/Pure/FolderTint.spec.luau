--!strict

local FolderTint = require("../../src/Pure/FolderTint")

return {
	["realm folders get their own colors"] = function(expect)
		local seen: { [string]: boolean } = {}

		for _, name in { "VluxyServer", "VluxyClient", "VluxyShared", "VluxyFirst" } do
			local hex = FolderTint.Match(name)

			expect.truthy(hex, name)
			expect.falsy(seen[hex :: string], name)
			seen[hex :: string] = true
		end
	end,

	["UPPER_SNAKE names match and plain names do not"] = function(expect)
		expect.truthy(FolderTint.Match("REMOVE_ON_RUN"))
		expect.truthy(FolderTint.Match("CHARACTER_RIGS"))
		expect.equal(FolderTint.Match("Props"), nil)
		expect.equal(FolderTint.Match("SERVER"), nil)
	end,

	["the first matching rule wins"] = function(expect)
		local rules = {
			{ Pattern = "^A", Hex = "111111" },
			{ Pattern = "^Ab", Hex = "222222" },
		}

		expect.equal(FolderTint.Match("Abc", rules), "111111")
		expect.equal(FolderTint.Match("Zed", rules), nil)
	end,
}
