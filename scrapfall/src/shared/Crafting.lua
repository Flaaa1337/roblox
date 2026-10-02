-- Workbench recipes and quarters decorations.
-- Recipes take salvage from your stash and put the result in your stash.

local Crafting = {}

-- tier: 1 = the free Outpost bench, 2-3 = your personal bench in your quarters
Crafting.Recipes = {
	{ id = "LightAmmo", count = 40, tier = 1, credits = 0, inputs = { { id = "ScrapMetal", count = 3 } } },
	{ id = "Shells", count = 12, tier = 1, credits = 0, inputs = { { id = "ScrapMetal", count = 3 }, { id = "Wires", count = 1 } } },
	{ id = "Bandage", count = 2, tier = 1, credits = 0, inputs = { { id = "Wires", count = 1 }, { id = "ScrapMetal", count = 1 } } },
	{ id = "ScrapPistol", count = 1, tier = 1, credits = 0, inputs = { { id = "ScrapMetal", count = 6 }, { id = "Wires", count = 2 } } },

	{ id = "HeavyAmmo", count = 30, tier = 2, credits = 0, inputs = { { id = "ScrapMetal", count = 4 }, { id = "Battery", count = 1 } } },
	{ id = "MedKit", count = 1, tier = 2, credits = 0, inputs = { { id = "Bandage", count = 2 }, { id = "CircuitBoard", count = 1 } } },
	{ id = "ShieldCell", count = 1, tier = 2, credits = 0, inputs = { { id = "Battery", count = 2 }, { id = "Wires", count = 2 } } },
	{ id = "Rattler", count = 1, tier = 2, credits = 100, inputs = { { id = "ScrapMetal", count = 10 }, { id = "Servo", count = 1 } } },

	{ id = "Breacher", count = 1, tier = 3, credits = 150, inputs = { { id = "ScrapMetal", count = 12 }, { id = "Servo", count = 2 } } },
	{ id = "Hammer", count = 1, tier = 3, credits = 200, inputs = { { id = "Servo", count = 2 }, { id = "RobotCore", count = 1 } } },
	{ id = "Longshot", count = 1, tier = 3, credits = 300, inputs = { { id = "OpticLens", count = 2 }, { id = "RobotCore", count = 1 }, { id = "PrototypeChip", count = 1 } } },
}

---------------------------------------------------------------------------
-- Decorations for your Private Quarters.
-- price = credits. inputs = salvage you have to bring (trophies!).
-- parts: simple shapes relative to the slot (so no assets are needed).
---------------------------------------------------------------------------
Crafting.Decor = {
	Crate = {
		name = "Storage Crates", price = 150,
		parts = { { size = Vector3.new(4, 3, 4), offset = Vector3.new(0, 1.5, 0), color = Color3.fromRGB(150, 115, 70), material = "WoodPlanks" },
			{ size = Vector3.new(3, 2.5, 3), offset = Vector3.new(0.4, 4.2, 0.2), color = Color3.fromRGB(130, 100, 60), material = "WoodPlanks" } },
	},
	Plant = {
		name = "Survivor Plant", price = 300,
		parts = { { size = Vector3.new(2, 2, 2), offset = Vector3.new(0, 1, 0), color = Color3.fromRGB(150, 90, 60), material = "Concrete", shape = "Cylinder" },
			{ size = Vector3.new(4, 4, 4), offset = Vector3.new(0, 4, 0), color = Color3.fromRGB(70, 160, 70), material = "Grass", shape = "Ball" } },
	},
	Couch = {
		name = "Old Couch", price = 600,
		parts = { { size = Vector3.new(8, 2, 3.5), offset = Vector3.new(0, 1, 0), color = Color3.fromRGB(120, 60, 50), material = "Fabric" },
			{ size = Vector3.new(8, 3, 1), offset = Vector3.new(0, 2.5, 1.3), color = Color3.fromRGB(110, 55, 45), material = "Fabric" } },
	},
	NeonSign = {
		name = "Neon Sign", price = 1200,
		parts = { { size = Vector3.new(6, 2, 0.4), offset = Vector3.new(0, 6, 0), color = Color3.fromRGB(255, 80, 180), material = "Neon" } },
	},
	Lamp = {
		name = "Floor Lamp", price = 400, light = true,
		parts = { { size = Vector3.new(0.5, 6, 0.5), offset = Vector3.new(0, 3, 0), color = Color3.fromRGB(60, 60, 60), material = "Metal" },
			{ size = Vector3.new(2, 1.5, 2), offset = Vector3.new(0, 6.5, 0), color = Color3.fromRGB(255, 220, 150), material = "Neon" } },
	},
	-- Trophies: made from rare stuff you extracted. Show-off items.
	CoreDisplay = {
		name = "Robot Core Display", price = 200, inputs = { { id = "RobotCore", count = 1 } }, light = true,
		parts = { { size = Vector3.new(3, 3, 3), offset = Vector3.new(0, 1.5, 0), color = Color3.fromRGB(40, 40, 45), material = "Metal" },
			{ size = Vector3.new(2, 2, 2), offset = Vector3.new(0, 4, 0), color = Color3.fromRGB(80, 200, 255), material = "Neon", shape = "Ball" } },
	},
	ColossusTrophy = {
		name = "Colossus Heart Trophy", price = 500, inputs = { { id = "ColossusHeart", count = 1 } }, light = true,
		parts = { { size = Vector3.new(4, 4, 4), offset = Vector3.new(0, 2, 0), color = Color3.fromRGB(50, 45, 40), material = "CorrodedMetal" },
			{ size = Vector3.new(3.5, 3.5, 3.5), offset = Vector3.new(0, 5.8, 0), color = Color3.fromRGB(255, 50, 40), material = "Neon", shape = "Ball" } },
	},
	SentinelHead = {
		name = "Sentinel Head", price = 300, inputs = { { id = "Servo", count = 2 }, { id = "OpticLens", count = 1 } },
		parts = { { size = Vector3.new(5, 4, 5), offset = Vector3.new(0, 2, 0), color = Color3.fromRGB(110, 100, 80), material = "Metal" },
			{ size = Vector3.new(1.5, 1.5, 1.5), offset = Vector3.new(0, 2.5, -2.6), color = Color3.fromRGB(80, 200, 255), material = "Neon", shape = "Ball" } },
	},
}

Crafting.DecorOrder = { "Crate", "Plant", "Lamp", "Couch", "NeonSign", "CoreDisplay", "SentinelHead", "ColossusTrophy" }

-- Number of decoration slots in a room.
Crafting.DecorSlots = 8

return Crafting
