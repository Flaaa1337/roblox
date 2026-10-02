--!strict
-- Expedition zones. Only implemented zones get a working portal; the others
-- show a dormant portal frame with a "not available yet" sign.

local Types = require(script.Parent.Parent.Types)

local ZoneDefinitions: { [string]: Types.ZoneDefinition } = {
	glitch_grove = {
		id = "glitch_grove",
		nameKey = "area.glitch_grove",
		center = Vector3.new(0, 0, 768),
		size = Vector2.new(256, 256),
		implemented = true,
		portalSide = "north",
		-- M2 slice spawn table: only implemented species (spec section 8).
		spawnTable = {
			{ speciesId = "glitch_pigeon", weight = 50 },
			{ speciesId = "fridge_dog", weight = 30 },
			{ speciesId = "siren_toad", weight = 20 },
		},
	},
	scrap_district = {
		id = "scrap_district",
		nameKey = "area.scrap_district",
		center = Vector3.new(768, 0, 0),
		size = Vector2.new(256, 256),
		implemented = false,
		portalSide = "east",
		spawnTable = {},
	},
	void_station = {
		id = "void_station",
		nameKey = "area.void_station",
		center = Vector3.new(-768, 0, 0),
		size = Vector2.new(256, 256),
		implemented = false,
		portalSide = "west",
		spawnTable = {},
	},
}

return ZoneDefinitions
