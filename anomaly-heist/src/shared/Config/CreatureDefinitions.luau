--!strict
-- Species records for the first slice. speciesId never changes; display
-- names are localized. Further species are added when they are implemented.

local Types = require(script.Parent.Parent.Types)

local CreatureDefinitions: { [string]: Types.SpeciesDefinition } = {
	glitch_pigeon = {
		id = "glitch_pigeon",
		nameKey = "species.glitch_pigeon.name",
		descriptionKey = "species.glitch_pigeon.description",
		rarity = "common",
		implemented = true,
	},
	fridge_dog = {
		id = "fridge_dog",
		nameKey = "species.fridge_dog.name",
		descriptionKey = "species.fridge_dog.description",
		rarity = "uncommon",
		implemented = true,
	},
	siren_toad = {
		id = "siren_toad",
		nameKey = "species.siren_toad.name",
		descriptionKey = "species.siren_toad.description",
		rarity = "uncommon",
		implemented = true,
	},
}

return CreatureDefinitions
