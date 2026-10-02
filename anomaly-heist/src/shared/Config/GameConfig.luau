--!strict
-- Versioned tunable values. Change values here, never inline in services.

local GameConfig = {
	version = "0.1.0-m1",

	maxPlayers = 8,
	plotCount = 8, -- exactly one base per player slot

	hub = {
		size = 256,
		plotRingRadius = 100,
		plotSize = 32,
		pathWidth = 14,
		spawnOffset = Vector3.new(0, 0, -40), -- spawn faces the beginner portal (+Z)
	},

	portal = {
		promptDistance = 10,
		maxUseDistance = 16, -- server-side proximity check (prompt range + latency slack)
		cooldownSeconds = 3,
		streamTimeoutSeconds = 6,
		clientTimeoutSeconds = 10,
		fallCheckDelaySeconds = 3,
		fallDistance = 40, -- below the arrival point counts as "fell into the void"
	},

	camera = {
		minZoom = 6,
		maxZoom = 40,
	},
}

return GameConfig
