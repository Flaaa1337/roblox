-- Robot types. Familiar extraction-shooter archetypes (small crawler,
-- attack drone, scout that calls backup, heavy walker, boss), but with
-- our own names and designs - no names or assets from other games.

local Robots = {}

Robots.Defs = {
	Crawler = {
		name = "Crawler", kind = "ground", health = 60, speed = 20, hipHeight = 1.2,
		sight = 70, attack = "melee", damage = 14, attackRange = 5, attackCooldown = 1.1,
		size = Vector3.new(3, 1.6, 3), color = Color3.fromRGB(70, 70, 75), eye = Color3.fromRGB(255, 60, 40),
		drops = { { "ScrapMetal", 70, 1, 3 }, { "Wires", 40, 1, 2 }, { "Battery", 8, 1, 1 } },
		packSize = { 2, 3 },
	},
	Buzzer = {
		name = "Buzzer Drone", kind = "air", health = 90, speed = 26, hoverHeight = 14,
		sight = 110, attack = "laser", damage = 7, burst = 3, attackRange = 85, attackCooldown = 2.4, telegraph = 0.8,
		size = Vector3.new(4, 1.4, 4), color = Color3.fromRGB(90, 95, 110), eye = Color3.fromRGB(255, 200, 40),
		drops = { { "CircuitBoard", 60, 1, 2 }, { "Battery", 35, 1, 1 }, { "RobotCore", 8, 1, 1 } },
		packSize = { 1, 2 },
	},
	Watcher = {
		name = "Watcher", kind = "air", health = 70, speed = 22, hoverHeight = 22,
		sight = 140, attack = "scout", damage = 0, attackRange = 140, attackCooldown = 12, telegraph = 2,
		callRadius = 160, callSpawn = 2,
		size = Vector3.new(3, 3, 3), color = Color3.fromRGB(200, 200, 210), eye = Color3.fromRGB(255, 40, 40),
		drops = { { "OpticLens", 50, 1, 1 }, { "CircuitBoard", 50, 1, 2 } },
		packSize = { 1, 1 },
	},
	Sentinel = {
		name = "Sentinel", kind = "ground", health = 320, speed = 9, hipHeight = 3,
		sight = 130, attack = "bolt", damage = 20, attackRange = 120, attackCooldown = 1.6, telegraph = 0.5,
		boltSpeed = 140, size = Vector3.new(6, 5, 6), color = Color3.fromRGB(110, 100, 80), eye = Color3.fromRGB(80, 200, 255),
		weakPoint = 2.5,
		drops = { { "Servo", 70, 1, 2 }, { "OpticLens", 45, 1, 1 }, { "RobotCore", 30, 1, 1 } },
		packSize = { 1, 1 },
	},
	Colossus = {
		name = "COLOSSUS", kind = "ground", health = 2200, speed = 7, hipHeight = 8,
		sight = 180, attack = "rockets", damage = 30, rockets = 4, blastRadius = 10, attackRange = 160,
		attackCooldown = 4, telegraph = 1.2, boltSpeed = 80,
		size = Vector3.new(14, 10, 14), color = Color3.fromRGB(60, 55, 50), eye = Color3.fromRGB(255, 40, 40),
		weakPoint = 3, boss = true,
		drops = { { "ColossusHeart", 100, 1, 1 }, { "RobotCore", 100, 2, 3 }, { "PrototypeChip", 40, 1, 1 } },
		packSize = { 1, 1 },
	},
}

-- Spawn weights for regular robots (the Colossus is managed separately).
Robots.SpawnWeights = { Crawler = 46, Buzzer = 28, Watcher = 10, Sentinel = 16 }

return Robots
