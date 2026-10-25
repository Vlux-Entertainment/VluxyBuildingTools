--!strict

--[=[
	The rules that decide a folder's icon tint from its name. A rule is a Luau pattern and a hex
	color; the first rule whose pattern matches the name wins, and a name no rule matches is left
	alone. No Roblox API is used here, so the rules are tested under Lune.

	@class FolderTint
]=]

--[=[
	@interface Rule
	@within FolderTint
	.Pattern string -- a Luau pattern matched against the whole name
	.Hex string -- the tint, as RRGGBB
]=]
export type Rule = { Pattern: string, Hex: string }

local FolderTint = {}

--[=[
	The classes whose icon the plugin tints.

	@prop Classes { string }
	@within FolderTint
]=]
FolderTint.Classes = { "Folder", "Configuration" }

--[=[
	The built-in rules: one color per realm, grey for packages, a loud color for the
	UPPER_SNAKE configurations that live only in the place file, and a warning tint for hazards.

	@prop Rules { Rule }
	@within FolderTint
]=]
FolderTint.Rules = {
	{ Pattern = "^VluxyServer$", Hex = "E5534B" },
	{ Pattern = "^VluxyClient$", Hex = "4B9BE5" },
	{ Pattern = "^VluxyShared$", Hex = "9B6BE5" },
	{ Pattern = "^VluxyFirst$", Hex = "4BC98B" },
	{ Pattern = "^Packages$", Hex = "8A8F98" },
	{ Pattern = "^CustomPackages$", Hex = "8A8F98" },
	{ Pattern = "^Utility$", Hex = "5FB3B3" },
	{ Pattern = "^BaseClasses$", Hex = "5FB3B3" },
	{ Pattern = "^Gateways$", Hex = "E5A04B" },
	{ Pattern = "^Services$", Hex = "6FCF5F" },
	{ Pattern = "^EntityClasses$", Hex = "6FCF5F" },
	{ Pattern = "Managers$", Hex = "E56BB0" },
	{ Pattern = "Controllers$", Hex = "E56BB0" },
	{ Pattern = "^MapModules$", Hex = "F2D14B" },
	{ Pattern = "^MapShared$", Hex = "F2D14B" },
	{ Pattern = "^Brushtool2_Plugin_Storage$", Hex = "F2D14B" },
	{ Pattern = "^[A-Z][A-Z0-9]*_[A-Z0-9_]+$", Hex = "FF3B7A" },
}

--[=[
	@param name string
	@param rules { Rule }? -- defaults to the built-in rules
	@return string? -- the hex color of the first rule matching the name, or nil when none does
]=]
function FolderTint.Match(name: string, rules: { Rule }?): string?
	local list: { Rule } = rules or FolderTint.Rules

	for _, rule in list do
		if string.find(name, rule.Pattern) then
			return rule.Hex
		end
	end

	return nil
end

return FolderTint
