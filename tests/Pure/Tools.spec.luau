--!strict

local Keymap = require("../../src/Pure/Keymap")
local Tools = require("../../src/Pure/Tools")

return {
	["every number-key badge matches the keymap"] = function(expect)
		for _, tile in Tools.Grid do
			if tile.Key then
				local names = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
				local name = if tile.Key == "0" then "Zero" else names[tonumber(tile.Key) :: number]

				expect.equal(Keymap.Resolve(name, false, true, false, false), `Tool:{tile.Id}`, tile.Id)
			end
		end
	end,

	["every mode is in exactly one tile and every tile mode is a tool"] = function(expect)
		for _, tool in Tools.List do
			expect.truthy(Tools.TileOf(tool.Id), tool.Id)
		end

		for _, tile in Tools.Grid do
			expect.truthy(Tools.FindTile(tile.Id), tile.Id)

			for _, mode in tile.Modes do
				expect.truthy(Tools.Find(mode), mode)
				expect.equal((Tools.TileOf(mode) :: Tools.Tile).Id, tile.Id, mode)
			end
		end
	end,

	["tool ids are unique and findable"] = function(expect)
		local seen: { [string]: boolean } = {}

		for _, tool in Tools.List do
			expect.falsy(seen[tool.Id], tool.Id)
			seen[tool.Id] = true
			expect.truthy(Tools.Find(tool.Id))
		end

		expect.falsy(Tools.Find("Nope"))
	end,
}
