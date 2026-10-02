--!strict
-- Startup validation (spec section 23). Returns a list of problems; the
-- server refuses to start gameplay when any are found.

local GameConfig = require(script.Parent.GameConfig)
local ZoneDefinitions = require(script.Parent.ZoneDefinitions)
local CreatureDefinitions = require(script.Parent.CreatureDefinitions)
local FeatureFlags = require(script.Parent.FeatureFlags)
local Strings = require(script.Parent.Parent.Generated.Strings)

local ConfigValidator = {}

function ConfigValidator.validate(): { string }
	local problems: { string } = {}
	local function check(ok: boolean, message: string)
		if not ok then
			table.insert(problems, message)
		end
	end

	check(GameConfig.plotCount == GameConfig.maxPlayers, "plotCount must equal maxPlayers (one base per player)")
	check(GameConfig.hub.pathWidth >= 14, "hub paths must be at least 14 studs wide")

	for id, zone in ZoneDefinitions do
		check(zone.id == id, "zone id mismatch: " .. id)
		check(Strings.source[zone.nameKey] ~= nil, "zone " .. id .. " has unknown name key " .. zone.nameKey)
		local total = 0
		for _, entry in zone.spawnTable do
			local species = CreatureDefinitions[entry.speciesId]
			check(species ~= nil, "zone " .. id .. " spawns unknown species " .. entry.speciesId)
			check(species == nil or species.implemented, "zone " .. id .. " spawns unimplemented species " .. entry.speciesId)
			check(entry.weight > 0, "zone " .. id .. " has a non-positive spawn weight")
			total += entry.weight
		end
		check(not zone.implemented or total == 100, "zone " .. id .. " spawn weights must total 100 (got " .. total .. ")")
	end

	for id, species in CreatureDefinitions do
		check(species.id == id, "species id mismatch: " .. id)
		check(Strings.source[species.nameKey] ~= nil, "species " .. id .. " has unknown name key")
		check(Strings.source[species.descriptionKey] ~= nil, "species " .. id .. " has unknown description key")
	end

	check(FeatureFlags.commerce == false, "commerce must stay disabled until its release gate")
	check(FeatureFlags.trading == false, "trading must stay disabled")
	check(Strings.source["objective.first_capture"] ~= nil, "generated strings are missing")

	return problems
end

return ConfigValidator
