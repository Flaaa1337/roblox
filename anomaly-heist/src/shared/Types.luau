--!strict
-- Shared type definitions. Identifiers are stable English IDs; display text
-- always comes from localization keys.

export type AreaId = string -- "hub" or a ZoneId
export type ZoneId = string
export type SpeciesId = string
export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"

export type ZoneDefinition = {
	id: ZoneId,
	nameKey: string,
	center: Vector3,
	size: Vector2, -- X/Z footprint in studs
	implemented: boolean, -- false = dormant portal, no travel
	portalSide: "north" | "east" | "west",
	spawnTable: { { speciesId: SpeciesId, weight: number } },
}

export type SpeciesDefinition = {
	id: SpeciesId,
	nameKey: string,
	descriptionKey: string,
	rarity: Rarity,
	implemented: boolean,
}

export type PlotInfo = {
	index: number,
	center: Vector3,
	facing: Vector3, -- unit vector from plot toward the hub center
}

return nil
