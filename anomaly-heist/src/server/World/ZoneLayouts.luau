--!strict
-- Authored expedition-zone layouts (spec 5.2). Layouts are hand-placed in
-- code (deterministic), not procedurally assembled. Random decoration uses a
-- fixed seed so every server is identical.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Kit = require(script.Parent.Kit)
local Factory = require(script.Parent.PrimitiveCreatureFactory)

local ZoneLayouts = {}

local P = Kit.Palette

export type ZoneInfo = {
	id: string,
	folder: Folder,
	center: Vector3,
	arrival: CFrame, -- where travelers are placed (safe)
	returnPortal: Model,
	extractionPoints: { BasePart },
	creatureSpawns: { BasePart },
	guardianWaypoints: { [string]: { BasePart } },
	recoveryPoints: { BasePart },
	wildCreatures: Folder,
}

-- Distance from point p to segment ab on the XZ plane.
local function distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

local function pathStrip(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3)
	local mid = (a + b) / 2
	Kit.part({
		Name = "Path", Size = Vector3.new(width, 0.1, (b - a).Magnitude + width * 0.6),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.06, 0), b + Vector3.new(0, 0.06, 0)),
		Color = color, Material = Enum.Material.Ground, CanCollide = false,
	}, parent)
end

local function glitchAccent(parent: Instance, position: Vector3, rng: Random)
	-- restrained violet glitch: a couple of small floating cubes
	for _ = 1, 2 do
		local p = Kit.part({
			Name = "Glitch", Size = Vector3.one * rng:NextNumber(0.5, 1.1),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(3, 6), rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			Color = P.anomaly, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
		}, parent)
		p:SetAttribute("Bob", true)
	end
end

local function extractionPoint(parent: Instance, cf: CFrame, id: string): BasePart
	local m = Kit.model("Extraction_" .. id, parent)
	local pad = Kit.pad(cf, 7, P.safe, m)
	pad.Name = "ExtractionZone"
	pad:SetAttribute("ExtractionId", id)
	Kit.part({ Name = "Beacon", Size = Vector3.new(1.2, 26, 1.2), CFrame = cf * CFrame.new(8, 13, 0), Color = P.safe, Material = Enum.Material.Neon, CanCollide = false }, m)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		Kit.part({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = cf * CFrame.new(math.cos(a) * 7.5, 1.5, math.sin(a) * 7.5), Color = P.metal, Material = Enum.Material.Metal }, m)
	end
	Kit.sign(cf * CFrame.new(0, 7, 8) * CFrame.Angles(0, math.pi, 0), Vector2.new(12, 2.5), "sign.extraction", P.safe, m)
	Kit.part({ Name = "SignPost", Size = Vector3.new(0.5, 6, 0.5), CFrame = cf * CFrame.new(0, 3, 8), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	return pad
end

function ZoneLayouts.buildGlitchGrove(zone: Types.ZoneDefinition, root: Instance): ZoneInfo
	local folder = Instance.new("Folder")
	folder.Name = "Zone_" .. zone.id
	folder.Parent = root
	local c = zone.center
	local hx, hz = zone.size.X / 2, zone.size.Y / 2
	local rng = Random.new(20261002)
	local function at(x: number, z: number): Vector3
		return c + Vector3.new(x, 0, z)
	end

	-- Ground and a soft border of hills
	Kit.floor(CFrame.new(c), Vector2.new(zone.size.X + 40, zone.size.Y + 40), P.grass, Enum.Material.Grass, folder)
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-hx, hx), rng:NextNumber(-hz, hz)
		Kit.part({
			Name = "GrassPatch", Size = Vector3.new(rng:NextNumber(12, 30), 0.1, rng:NextNumber(12, 30)),
			CFrame = CFrame.new(at(x, z) + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = P.grassDark, Material = Enum.Material.Grass, CanCollide = false,
		}, folder)
	end

	-- Routes. Main: arrival -> clearing -> both exits. East: through the
	-- ruined lab and over the plateau. West: forest trail.
	local arrivalPos = at(0, -104)
	local clearing = at(0, 10)
	local exitA = at(-80, 100) -- north-west
	local exitB = at(84, 92) -- north-east
	local labCenter = at(62, -30)
	local labDoor = at(62, -50) -- just outside the lab's south doorway
	local plateauTop = at(70, 30)
	local westTrail = at(-70, -30)
	local routes = {
		{ arrivalPos, clearing }, { clearing, exitA }, { clearing, exitB },
		{ at(0, -70), labDoor }, { labDoor, at(70, 0) }, { at(70, 66), exitB },
		{ at(0, -80), westTrail }, { westTrail, at(-80, 40) }, { at(-80, 40), exitA },
	}
	for _, seg in routes do
		pathStrip(folder, seg[1], seg[2], 14, Color3.fromRGB(176, 156, 120))
	end

	-- Arrival point (safe) + return portal behind it
	local arrivalPad = Kit.pad(CFrame.new(arrivalPos), 8, P.safe, folder)
	arrivalPad.Name = "ArrivalPad"
	Kit.sign(CFrame.new(arrivalPos + Vector3.new(-12, 6, 0)) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(10, 2.5), "sign.arrival", P.safe, folder)
	Kit.part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(arrivalPos + Vector3.new(-12, 2.5, 0)), Color = P.metalDark, Material = Enum.Material.Metal }, folder)
	local portalPos = at(0, -122)
	local returnPortal = Kit.portal(CFrame.lookAt(portalPos, arrivalPos), true, folder)
	returnPortal.Name = "ReturnPortal"
	Kit.sign(CFrame.lookAt(portalPos, arrivalPos) * CFrame.new(0, 23, 0), Vector2.new(16, 3), "area.hub", P.safe, returnPortal)

	-- Ruined research lab on the east route (walk-through doorways)
	local labCf = CFrame.lookAt(labCenter, labCenter + Vector3.new(0, 0, 1))
	local lab = Kit.model("RuinedLab", folder)
	Kit.part({ Name = "LabFloor", Size = Vector3.new(30, 0.6, 26), CFrame = labCf * CFrame.new(0, 0.3, 0), Color = P.concrete, Material = Enum.Material.Concrete }, lab)
	Kit.doorway(labCf * CFrame.new(0, 0, 13), 30, 10, 14, lab)
	Kit.doorway(labCf * CFrame.new(0, 0, -13), 30, 10, 14, lab)
	Kit.wall(labCf * CFrame.new(-15, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 26, 7, nil, lab)
	Kit.wall(labCf * CFrame.new(15, 0, 4) * CFrame.Angles(0, math.rad(90), 0), 14, 9, nil, lab)
	Kit.machine(labCf * CFrame.new(-11, 0.6, 4), P.anomaly, true, lab)
	Kit.machine(labCf * CFrame.new(11.5, 0.6, -5) * CFrame.Angles(0, math.rad(160), 0), P.hazard, true, lab)
	Kit.crate(labCf * CFrame.new(-10, 0.6, -8), 3, lab)
	glitchAccent(lab, (labCf * CFrame.new(-11, 0, 4)).Position, rng)

	-- Plateau with a ramp up and stairs down (alternative route height)
	local plateau = Kit.model("Plateau", folder)
	local plateauHeight = 6
	Kit.part({ Name = "PlateauTop", Size = Vector3.new(30, plateauHeight, 30), CFrame = CFrame.new(plateauTop + Vector3.new(0, plateauHeight / 2, 0)), Color = P.rock, Material = Enum.Material.Slate }, plateau)
	Kit.part({ Name = "PlateauGrass", Size = Vector3.new(28, 0.2, 28), CFrame = CFrame.new(plateauTop + Vector3.new(0, plateauHeight + 0.1, 0)), Color = P.grass, Material = Enum.Material.Grass, CanCollide = false }, plateau)
	-- ramp from z=-15 up to the plateau's south edge (z=15)
	Kit.ramp(CFrame.lookAt(at(70, -15), at(70, 15)), 14, 30, plateauHeight, plateau)
	-- stairs from z=63 up to the plateau's north edge (z=45): 6 steps x 3 studs
	Kit.stairs(CFrame.lookAt(at(70, 63), at(70, 45)), 14, 6, plateauHeight / 6, 3, plateau)
	Kit.railing(CFrame.new(plateauTop + Vector3.new(-15, plateauHeight, 0)) * CFrame.Angles(0, math.rad(90), 0), 30, plateau)
	Kit.machine(CFrame.new(plateauTop + Vector3.new(6, plateauHeight, -6)) * CFrame.Angles(0, 2.4, 0), P.anomaly, true, plateau)
	glitchAccent(plateau, plateauTop + Vector3.new(6, plateauHeight, -6), rng)

	-- Clearing: damaged research devices and cables
	Kit.machine(CFrame.new(clearing + Vector3.new(-14, 0, 6)) * CFrame.Angles(0, 0.5, 0), P.anomaly, true, folder)
	Kit.machine(CFrame.new(clearing + Vector3.new(16, 0, -4)) * CFrame.Angles(0, -0.9, 0), P.safe, false, folder)
	Kit.cable(clearing + Vector3.new(-12, 0.2, 6), clearing + Vector3.new(14, 0.2, -4), folder)
	glitchAccent(folder, clearing + Vector3.new(-14, 0, 6), rng)

	-- Extraction points
	local extractions = {
		extractionPoint(folder, CFrame.new(exitA), "A"),
		extractionPoint(folder, CFrame.new(exitB), "B"),
	}

	-- Forest: trees avoid all routes, the arrival area, structures and exits
	local avoid = { arrivalPos, clearing, exitA, exitB, plateauTop, labCenter }
	local trees = 0
	local attempts = 0
	while trees < 70 and attempts < 1500 do
		attempts += 1
		local p = at(rng:NextNumber(-hx + 6, hx - 6), rng:NextNumber(-hz + 6, hz - 6))
		local ok = true
		for _, seg in routes do
			if distToSegment(p, seg[1], seg[2]) < 12 then
				ok = false
				break
			end
		end
		for _, a in avoid do
			if ok and (Vector3.new(p.X, 0, p.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude < 22 then
				ok = false
			end
		end
		if ok then
			trees += 1
			if rng:NextNumber() < 0.8 then
				Kit.tree(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.9, 1.5), folder)
			else
				Kit.rock(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(2, 4), rng:NextNumber(3, 6)), folder)
			end
		end
	end

	-- Clear boundaries: rock border + invisible walls
	for i = 0, 3 do
		local a = i * math.pi / 2
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local span = (if i % 2 == 0 then zone.size.X else zone.size.Y) + 40
		local dist = (if i % 2 == 0 then hz else hx) + 6
		local cf = CFrame.lookAt(c + dir * dist, c + dir * (dist + 1))
		for k = -span / 2, span / 2, 12 do
			Kit.rock(cf * CFrame.new(k, 0, rng:NextNumber(-2, 2)), Vector3.new(rng:NextNumber(10, 14), rng:NextNumber(6, 12), rng:NextNumber(6, 9)), folder)
		end
		Kit.part({ Name = "Boundary", Size = Vector3.new(span, 80, 2), CFrame = cf * CFrame.new(0, 40, 4), Transparency = 1 }, folder)
	end

	-- Gameplay markers (invisible)
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = folder
	local spawnPoints = {
		at(-20, -20), at(24, 30), at(-40, 60), at(30, 70), at(-60, 0), at(60, -60), at(-30, -60), at(0, 60),
	}
	local creatureSpawns: { BasePart } = {}
	for i, p in spawnPoints do
		table.insert(creatureSpawns, Kit.marker("CreatureSpawn" .. i, CFrame.new(p), markers, { Kind = "CreatureSpawn" }))
	end
	local guardianWaypoints: { [string]: { BasePart } } = { west = {}, east = {} }
	for i, p in { at(-50, -10), at(-50, 50), at(-15, 70), at(-15, 0) } do
		table.insert(guardianWaypoints.west, Kit.marker("GuardianWest" .. i, CFrame.new(p), markers, { Kind = "GuardianWaypoint", Path = "west", Order = i }))
	end
	for i, p in { at(30, -30), at(45, 10), at(30, 60), at(15, 20) } do
		table.insert(guardianWaypoints.east, Kit.marker("GuardianEast" .. i, CFrame.new(p), markers, { Kind = "GuardianWaypoint", Path = "east", Order = i }))
	end
	local recoveryPoints: { BasePart } = {}
	for i, p in { arrivalPos + Vector3.new(0, 0, 8), clearing + Vector3.new(0, 0, -16), at(70, -20) } do
		table.insert(recoveryPoints, Kit.marker("Recovery" .. i, CFrame.new(p + Vector3.new(0, 3, 0)), markers, { Kind = "Recovery" }))
	end

	-- First three species shown in the zone (idle display in M1; capture
	-- arrives with M2 behind FeatureFlags.capture).
	local wild = Instance.new("Folder")
	wild.Name = "WildCreatures"
	wild.Parent = folder
	local showcase = { "glitch_pigeon", "fridge_dog", "siren_toad" }
	for i, speciesId in showcase do
		local spot = spawnPoints[i]
		Factory.create(speciesId, CFrame.lookAt(spot, arrivalPos * Vector3.new(1, 0, 1) + Vector3.new(0, spot.Y, 0)), wild)
	end

	return {
		id = zone.id,
		folder = folder,
		center = c,
		arrival = CFrame.lookAt(arrivalPos + Vector3.new(0, 3, 0), clearing + Vector3.new(0, 3, 0)),
		returnPortal = returnPortal,
		extractionPoints = extractions,
		creatureSpawns = creatureSpawns,
		guardianWaypoints = guardianWaypoints,
		recoveryPoints = recoveryPoints,
		wildCreatures = wild,
	}
end

local LAYOUTS: { [string]: (Types.ZoneDefinition, Instance) -> ZoneInfo } = {
	glitch_grove = ZoneLayouts.buildGlitchGrove,
}

function ZoneLayouts.build(zone: Types.ZoneDefinition, root: Instance): ZoneInfo
	local builder = LAYOUTS[zone.id]
	assert(builder, "no authored layout for implemented zone " .. zone.id)
	return builder(zone, root)
end

function ZoneLayouts.has(zoneId: string): boolean
	return LAYOUTS[zoneId] ~= nil
end

return ZoneLayouts
